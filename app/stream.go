package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode"

	"github.com/godbus/dbus/v5"
)

// songCacheLimit: the song cache's default size (2 GB; the settings change it). The songs
// played longest ago go first. Covers have no limit: a whole library's take a few MB.
const songCacheLimit = 2 << 30

// store: files fetched whole, in dir (cacheKey names them); past limit, the ones used
// longest ago go. Off (the songs' switch), nothing is saved in it nor served from it.
type store struct {
	dir   string
	off   atomic.Bool
	limit atomic.Int64
}

func newStore(dir string, limit int64) *store {
	_ = os.MkdirAll(dir, 0o755)
	parts, _ := filepath.Glob(filepath.Join(dir, ".part-*")) // the last run's, cut short
	for _, p := range parts {
		_ = os.Remove(p)
	}
	s := &store{dir: dir}
	s.limit.Store(limit)
	return s
}

// relay: the cache behind Go's relay, songs and covers apart, the covers fetched ahead,
// and the songs being downloaded.
type relay struct {
	songs, covers        *store
	client               *http.Client // Navidrome, for the covers fetched ahead
	fetching             atomic.Bool
	loader               *http.Client // Navidrome, for the songs (no time limit: a song takes long)
	mu                   sync.Mutex
	loads                map[string]*download // by song id
	next                 *url.URL             // the song to download once the others are there
	stall, retry, giveUp time.Duration        // stallAfter, retryAfter, giveUpAfter
	metered              func() bool          // the network costs (mobile data)
}

// storeFor is where u's file goes: covers or songs.
func (c *relay) storeFor(u *url.URL) *store {
	if isCover(u) {
		return c.covers
	}
	return c.songs
}

func isCover(u *url.URL) bool { return strings.HasSuffix(u.Path, "/rest/getCoverArt") }

// streamProxy serves Navidrome's streams and covers over plain http on 127.0.0.1, on every
// platform: Sailfish OS needs it (Chum's FFmpeg has no https), and it keeps the cache in
// dir/songs and dir/covers. QML asks for prefix + the escaped stream or cover URL; Range
// works, so seeking works. Only Subsonic stream and getCoverArt URLs go through. A song
// is downloaded whole (download), a cover fetched whole is saved; the next time they come
// from there, with no server. prefix without "?u=", + "cache": the settings (control);
// + "prefetch": the covers to fetch ahead; + "ahead?u=" and a stream URL: the next song,
// downloaded once the others are there; + "network": {"metered": true} on mobile data.
// rt is the transport (nil: the default).
func streamProxy(rt http.RoundTripper, dir string) (prefix string, err error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	cache := &relay{
		songs:  newStore(filepath.Join(dir, "songs"), songCacheLimit),
		covers: newStore(filepath.Join(dir, "covers"), math.MaxInt64),
		client: &http.Client{Transport: rt, Timeout: time.Minute},
		loader: &http.Client{Transport: rt},
		loads:  map[string]*download{},
		stall:  stallAfter, retry: retryAfter, giveUp: giveUpAfter,
		metered: onMeter,
	}
	target := func(r *http.Request) *url.URL { return relayable(r.URL.Query().Get("u")) }
	proxy := &httputil.ReverseProxy{Transport: rt, Rewrite: func(r *httputil.ProxyRequest) {
		r.Out.URL = target(r.In)
		r.Out.Host = ""
	}, ModifyResponse: func(res *http.Response) error {
		cache.storeFor(res.Request.URL).save(res)
		return nil
	}}
	serve := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if cache.answer(w, r) {
			return
		}
		u := target(r)
		switch {
		case u == nil:
			http.Error(w, "not a stream", http.StatusBadRequest)
		case r.URL.Path == "/ahead":
			cache.ahead(u)
			w.WriteHeader(http.StatusAccepted)
		case cache.storeFor(u).serve(w, r, cacheKey(u)):
		case isCover(u) || cacheKey(u) == "" || !cache.send(w, r, cache.start(u, cacheKey(u), true)):
			proxy.ServeHTTP(w, r)
		}
	})
	go func() { _ = http.Serve(ln, serve) }() // stops only with the program
	return "http://" + ln.Addr().String() + "/?u=", nil
}

// answer answers the settings page (cache), the covers to fetch ahead (prefetch) and
// the network asked (network). false: r is none of them.
func (c *relay) answer(w http.ResponseWriter, r *http.Request) bool {
	switch r.URL.Path {
	case "/cache":
		c.control(w, r)
	case "/prefetch":
		c.prefetch(w, r)
	case "/network":
		_, _ = fmt.Fprintf(w, `{"metered":%t}`, c.metered())
	default:
		return false
	}
	return true
}

// relayable is s parsed, when it is a Subsonic stream or cover URL, else nil.
func relayable(s string) *url.URL {
	u, err := url.Parse(s)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") {
		return nil
	}
	if strings.HasSuffix(u.Path, "/rest/stream") || strings.HasSuffix(u.Path, "/rest/getCoverArt") {
		return u
	}
	return nil
}

// prefetch fetches the covers the cache lacks, in the background and one at a time: one
// getCoverArt URL a line in the request's body (QML: Api.prefetchCovers). A list sent while
// one is being fetched is dropped.
func (c *relay) prefetch(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	if c.fetching.CompareAndSwap(false, true) {
		go func() {
			defer c.fetching.Store(false)
			list, n := strings.Fields(string(body)), 0
			log.Printf("covers ahead: %d albums", len(list))
			for _, s := range list {
				n += c.fetch(s)
			}
			log.Printf("covers ahead: %d fetched, the others were there", n)
		}()
	}
	w.WriteHeader(http.StatusAccepted)
}

// fetch saves the cover at s, unless s is not a cover or the cache has it. It returns 1
// when it asked Navidrome, else 0.
func (c *relay) fetch(s string) int {
	u := relayable(s)
	if u == nil || !isCover(u) {
		return 0
	}
	if _, err := os.Stat(filepath.Join(c.covers.dir, cacheKey(u))); err == nil {
		return 0 // there (or no plain key: dir itself)
	}
	res, err := c.client.Get(s)
	if err != nil {
		log.Println("covers ahead:", err)
		return 0
	}
	c.covers.save(res)
	_, _ = io.Copy(io.Discard, res.Body)
	_ = res.Body.Close()
	return 1
}

// control applies the settings page's choices, all optional: on (1 or 0: the songs),
// limit (GB, the songs), clear (songs or covers). It answers the bytes each holds:
// {"songs": n, "covers": n}.
func (c *relay) control(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if on := q.Get("on"); on != "" {
		c.songs.off.Store(on == "0")
	}
	if gb, err := strconv.ParseFloat(q.Get("limit"), 64); err == nil && gb > 0 {
		c.songs.limit.Store(int64(gb * (1 << 30)))
	}
	switch q.Get("clear") {
	case "songs":
		trim(c.songs.dir, 0, 0)
	case "covers":
		trim(c.covers.dir, 0, 0)
	}
	_, _ = fmt.Fprintf(w, `{"songs":%d,"covers":%d}`, c.songs.fit(), c.covers.fit())
}

// fit trims the store to its limit, and returns the bytes it holds. Off (the songs): only
// the 2 newest, the song playing and the next.
func (c *store) fit() int64 {
	if c.off.Load() {
		return trim(c.dir, 0, 2)
	}
	return trim(c.dir, c.limit.Load(), 0)
}

// save copies res to the store as the player reads it, when it brings the whole file. Not
// Navidrome's placeholder (a WebP vinyl, sent when it fails to get an album's art, at
// times only for one size): kept, it hid the art for good. Its covers are JPEG or PNG.
// Nor Navidrome's error (JSON or XML, with a 200: a file it cannot open): kept, the song
// never played again.
func (c *store) save(res *http.Response) {
	if isCover(res.Request.URL) && placeholder(res) {
		return
	}
	if ct := res.Header.Get("Content-Type"); strings.Contains(ct, "json") || strings.Contains(ct, "xml") {
		return
	}
	if id, total := cacheKey(res.Request.URL), whole(res); !c.off.Load() && id != "" && total != 0 {
		_ = os.MkdirAll(c.dir, 0o755) // cleared meanwhile (Settings › Apps › Ryūgin)
		if f, err := os.CreateTemp(c.dir, ".part-*"); err == nil {
			res.Body = &caching{ReadCloser: res.Body, f: f, total: total, path: filepath.Join(c.dir, id), cache: c}
		}
	}
}

// placeholder tells a WebP picture by its first bytes ("RIFF", size, "WEBP"), which stay
// in res's body.
func placeholder(res *http.Response) bool {
	b := bufio.NewReader(res.Body)
	res.Body = struct {
		io.Reader
		io.Closer
	}{b, res.Body}
	head, _ := b.Peek(12)
	return len(head) == 12 && string(head[:4]) == "RIFF" && string(head[8:]) == "WEBP"
}

// serve answers with the file of this id from the store, if it is there.
func (c *store) serve(w http.ResponseWriter, r *http.Request, id string) bool {
	if id == "" {
		return false
	}
	p := filepath.Join(c.dir, id)
	f, err := os.Open(p)
	if err != nil {
		return false
	}
	defer func() { _ = f.Close() }()
	now := time.Now()
	_ = os.Chtimes(p, now, now) // just played: kept longest
	http.ServeContent(w, r, "", time.Time{}, f)
	return true
}

// cacheKey names u's file in the cache: a song's id, or "cover.<size>.<id>" for a cover;
// "" when the id or size is not a plain file name.
func cacheKey(u *url.URL) string {
	q := u.Query()
	id, size := q.Get("id"), q.Get("size")
	if id == "" || !plain(id) || !plain(size) {
		return ""
	}
	if strings.HasSuffix(u.Path, "/rest/getCoverArt") {
		return "cover." + size + "." + id // a dot: no song id has one
	}
	return id
}

// plain: only letters, digits, - and _.
func plain(s string) bool {
	for _, c := range s {
		if c != '-' && c != '_' && !unicode.IsLetter(c) && !unicode.IsDigit(c) {
			return false
		}
	}
	return true
}

// whole is the file's size when res brings all of it (a 200), -1 for a 200 of unknown
// size (a cover, chunked), else 0.
func whole(res *http.Response) int64 {
	if res.StatusCode == http.StatusOK {
		return res.ContentLength
	}
	return 0
}

// caching copies a stream to f as the player reads it. Closed with every byte there (read
// to the end, total of them when known), f becomes the cached file; else (the player
// seeked or stopped) it is dropped.
type caching struct {
	io.ReadCloser
	f        *os.File
	n, total int64
	end, bad bool // read to the end; a write failed
	path     string
	cache    *store
}

func (c *caching) Read(p []byte) (int, error) {
	n, err := c.ReadCloser.Read(p)
	w, _ := c.f.Write(p[:n])
	c.n += int64(w)
	c.bad = c.bad || w < n
	c.end = c.end || err == io.EOF
	return n, err
}

func (c *caching) Close() error {
	err := c.ReadCloser.Close()
	_ = c.f.Close()
	if !c.end || c.bad || (c.total > 0 && c.n != c.total) || os.Rename(c.f.Name(), c.path) != nil {
		_ = os.Remove(c.f.Name())
		return err
	}
	c.cache.fit()
	return err
}

// trim deletes the files used longest ago until dir holds at most limit bytes, or only
// the keep newest, and returns what it holds then. Songs being downloaded stay.
func trim(dir string, limit int64, keep int) int64 {
	entries, _ := os.ReadDir(dir)
	var files []os.FileInfo
	var size int64
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".part-") {
			continue
		}
		if i, err := e.Info(); err == nil {
			files = append(files, i)
			size += i.Size()
		}
	}
	slices.SortFunc(files, func(a, b os.FileInfo) int { return a.ModTime().Compare(b.ModTime()) })
	for _, i := range files[:max(0, len(files)-keep)] {
		if size <= limit {
			break
		}
		if os.Remove(filepath.Join(dir, i.Name())) == nil {
			size -= i.Size()
		}
	}
	return size
}

// A song's download: as fast as the network goes, so that a song is there whole a few
// seconds after it starts, and Wi-Fi lost on the way out does not stop it. A connection
// broken or silent for stallAfter is taken up again where it stopped, every retryAfter;
// after giveUpAfter with no byte, the song fails.
var (
	stallAfter  = 15 * time.Second
	retryAfter  = 2 * time.Second
	giveUpAfter = 90 * time.Second
)

// errBad: Navidrome's answer is not the song (an error, or no room for it here): no retry.
var errBad = errors.New("not a song")

// download: a song being fetched into the songs store (relay.mu guards it). The player
// reads it as it fills (send); a seek further on waits for the bytes.
type download struct {
	file     string // the part as it fills, then the song in the store
	n, total int64  // bytes there; the size (-1: unknown)
	kind     string // Content-Type
	ready    bool   // Navidrome answered: total and kind known
	done     bool   // every byte there, or failed
	failed   bool
	wake     chan struct{} // closed at each change
	cancel   context.CancelFunc
}

func (d *download) changed() {
	close(d.wake)
	d.wake = make(chan struct{})
}

// start downloads the song at u (named id), unless it is being downloaded. play: the
// player asks for it, so the other downloads stop (it moved on) and the next one waits
// for the next ahead. nil: no room for it.
func (c *relay) start(u *url.URL, id string, play bool) *download {
	c.mu.Lock()
	defer c.mu.Unlock()
	if play {
		c.next = nil
	}
	if d := c.loads[id]; d != nil {
		return d
	}
	if play {
		for _, o := range c.loads {
			o.cancel()
		}
	}
	return c.begin(u, id)
}

// begin (relay.mu held) starts the download.
func (c *relay) begin(u *url.URL, id string) *download {
	_ = os.MkdirAll(c.songs.dir, 0o755)
	f, err := os.CreateTemp(c.songs.dir, ".part-*")
	if err != nil {
		return nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	d := &download{file: f.Name(), total: -1, wake: make(chan struct{}), cancel: cancel}
	c.loads[id] = d
	go c.load(ctx, d, f, u, id)
	return d
}

// ahead downloads the song at u once the others are there, unless the store has it.
func (c *relay) ahead(u *url.URL) {
	id := cacheKey(u)
	if _, err := os.Stat(filepath.Join(c.songs.dir, id)); id == "" || err == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.loads[id] != nil {
		return
	}
	if len(c.loads) > 0 {
		c.next = u
		return
	}
	c.begin(u, id)
}

// load fetches the song into f, taking a broken connection up again where it stopped.
func (c *relay) load(ctx context.Context, d *download, f *os.File, u *url.URL, id string) {
	last := time.Now() // the last byte got
	err := c.pull(ctx, d, f, u, &last)
	for again(ctx, err, last, c.giveUp) {
		log.Println("song: taken up again:", err)
		select {
		case <-ctx.Done():
		case <-time.After(c.retry):
		}
		err = c.pull(ctx, d, f, u, &last)
	}
	_ = f.Close()
	if err != nil && ctx.Err() == nil {
		log.Println("song: failed:", err)
	}
	c.finish(d, id, err == nil)
}

// again: the download failed with err, can be taken up again, and is not given up.
func again(ctx context.Context, err error, last time.Time, giveUp time.Duration) bool {
	return err != nil && !errors.Is(err, errBad) && ctx.Err() == nil && time.Since(last) <= giveUp
}

// pull asks Navidrome for the song from the bytes there on, and appends them to f; last:
// when the last byte came.
func (c *relay) pull(ctx context.Context, d *download, f *os.File, u *url.URL, last *time.Time) error {
	ctx, stop := context.WithCancel(ctx)
	defer stop()
	watch := time.AfterFunc(c.stall, stop) // silent too long: dead (Wi-Fi gone)
	defer watch.Stop()
	from := d.n // only this goroutine changes it
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if from > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", from))
	}
	res, err := c.loader.Do(req)
	if err != nil {
		return err
	}
	defer func() { _ = res.Body.Close() }()
	if err := c.answered(d, res, from); err != nil {
		return err
	}
	return c.copyIn(d, f, res.Body, watch, last)
}

// copyIn appends body to f, the watch put back at each read.
func (c *relay) copyIn(d *download, f *os.File, body io.Reader, watch *time.Timer, last *time.Time) error {
	buf := make([]byte, 64<<10)
	for {
		k, err := body.Read(buf)
		if k > 0 {
			if _, err := f.Write(buf[:k]); err != nil {
				return errBad // no room
			}
			*last = time.Now()
			watch.Reset(c.stall)
			c.mu.Lock()
			d.n += int64(k)
			d.changed()
			c.mu.Unlock()
		}
		if err == io.EOF && d.total >= 0 && d.n != d.total {
			return io.ErrUnexpectedEOF
		}
		if err != nil {
			return ignore(err, io.EOF)
		}
	}
}

// ignore is err, nil when it is ok.
func ignore(err, ok error) error {
	if errors.Is(err, ok) {
		return nil
	}
	return err
}

// answered checks Navidrome's answer to the song asked from byte from on: the first one
// gives its size and type; a later one, without Range, is read up to from.
func (c *relay) answered(d *download, res *http.Response, from int64) error {
	ct := res.Header.Get("Content-Type")
	switch {
	case from == 0 && (res.StatusCode != http.StatusOK || strings.Contains(ct, "json") || strings.Contains(ct, "xml")):
		return errBad // Navidrome's error: the player gets it (proxy)
	case from == 0:
		c.mu.Lock()
		d.total, d.kind, d.ready = res.ContentLength, ct, true
		d.changed()
		c.mu.Unlock()
	case res.StatusCode == http.StatusPartialContent && strings.HasPrefix(res.Header.Get("Content-Range"), fmt.Sprintf("bytes %d-", from)):
	case res.StatusCode == http.StatusOK: // no Range: from the start again
		_, err := io.CopyN(io.Discard, res.Body, from)
		return err
	default:
		return fmt.Errorf("answer: %s", res.Status)
	}
	return nil
}

// finish moves the song whole into the store (else drops it), and starts the next.
func (c *relay) finish(d *download, id string, ok bool) {
	c.mu.Lock()
	if c.loads[id] == d {
		delete(c.loads, id)
	}
	if p := filepath.Join(c.songs.dir, id); ok && os.Rename(d.file, p) == nil {
		d.file = p
	} else {
		_ = os.Remove(d.file)
		d.failed = true
	}
	d.done = true
	d.changed()
	if u := c.next; u != nil && len(c.loads) == 0 {
		c.next = nil
		c.begin(u, cacheKey(u))
	}
	c.mu.Unlock()
	if ok {
		c.songs.fit()
	}
}

// send answers r with the song as it downloads (Range works). false: d is nil or failed
// before Navidrome answered, so the proxy asks Navidrome (its error reaches the player).
func (c *relay) send(w http.ResponseWriter, r *http.Request, d *download) bool {
	if d == nil {
		return false
	}
	if _, ok := c.until(d, r, -1); !ok {
		return true // the player is gone
	}
	c.mu.Lock()
	f, err := os.Open(d.file)
	total, kind, ready := d.total, d.kind, d.ready
	c.mu.Unlock()
	if !ready || err != nil {
		return false
	}
	defer func() { _ = f.Close() }()
	w.Header().Set("Content-Type", kind)
	from, to := part(w, r, total)
	c.copyOut(w, r, d, f, from, to)
	return true
}

// copyOut sends bytes [from, to) of d's file f (to -1: to the end) as they come.
func (c *relay) copyOut(w http.ResponseWriter, r *http.Request, d *download, f *os.File, from, to int64) {
	buf := make([]byte, 64<<10)
	for to < 0 || from < to {
		n, ok := c.until(d, r, from)
		if !ok || from >= n {
			return // the player is gone; or failed, or the end (size unknown)
		}
		if to >= 0 {
			n = min(n, to)
		}
		k, err := f.ReadAt(buf[:min(int64(len(buf)), n-from)], from)
		if _, werr := w.Write(buf[:k]); werr != nil || ignore(err, io.EOF) != nil {
			return
		}
		from += int64(k)
		_ = http.NewResponseController(w).Flush()
	}
}

// until waits for d to hold more than from bytes (from -1: Navidrome's answer), or to be
// done, and returns the bytes there. false: r is gone.
func (c *relay) until(d *download, r *http.Request, from int64) (int64, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for !d.done && (from < 0 && !d.ready || from >= 0 && d.n <= from) {
		ch := d.wake
		c.mu.Unlock()
		select {
		case <-ch:
		case <-r.Context().Done():
			c.mu.Lock()
			return 0, false
		}
		c.mu.Lock()
	}
	return d.n, true
}

// part writes the headers for r's Range of a song of total bytes, and returns it:
// [from, to), to -1 for to the end of a song of unknown size.
func part(w http.ResponseWriter, r *http.Request, total int64) (from, to int64) {
	if total < 0 {
		return 0, -1
	}
	h := w.Header()
	h.Set("Accept-Ranges", "bytes")
	end := int64(-1)
	_, err := fmt.Sscanf(r.Header.Get("Range"), "bytes=%d-%d", &from, &end)
	to = total
	if from < 0 || (from >= total && total > 0) {
		from = 0
	} else if err == nil && end >= from && end < total {
		to = end + 1
	}
	h.Set("Content-Length", strconv.FormatInt(to-from, 10))
	if r.Header.Get("Range") != "" {
		h.Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", from, to-1, total))
		w.WriteHeader(http.StatusPartialContent)
	}
	return from, to
}

// onMeter is metered on the system bus; false without one.
var onMeter = func() bool {
	conn, err := dbus.SystemBus()
	return err == nil && metered(conn)
}

// metered: the network in use costs, as mobile data. Sailfish OS: connman's first service
// connected (the one in use) is cellular. Elsewhere: NetworkManager says it is metered
// (yes, or guessed yes). Neither there: false.
func metered(conn *dbus.Conn) bool {
	var services []struct {
		Path  dbus.ObjectPath
		Props map[string]dbus.Variant
	}
	if conn.Object("net.connman", "/").Call("net.connman.Manager.GetServices", 0).Store(&services) == nil {
		for _, s := range services {
			if st, _ := s.Props["State"].Value().(string); st == "ready" || st == "online" {
				kind, _ := s.Props["Type"].Value().(string)
				return kind == "cellular"
			}
		}
		return false
	}
	v, err := conn.Object("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager").GetProperty("org.freedesktop.NetworkManager.Metered")
	m, _ := v.Value().(uint32)
	return err == nil && (m == 1 || m == 3) // NM_METERED_YES, NM_METERED_GUESS_YES
}
