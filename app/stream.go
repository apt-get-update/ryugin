package main

import (
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
	"sync/atomic"
	"time"
	"unicode"
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
	s := &store{dir: dir}
	s.limit.Store(limit)
	return s
}

// relay: the cache behind Go's relay, songs and covers apart, and the covers fetched ahead.
type relay struct {
	songs, covers *store
	client        *http.Client // Navidrome, for the covers fetched ahead
	fetching      atomic.Bool
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
// passes through, so seeking works. Only Subsonic stream and getCoverArt URLs go through.
// A song or cover fetched whole is saved; the next time it comes from there, with no
// server. prefix without "?u=", + "cache": the settings (control); + "prefetch": the
// covers to fetch ahead. rt is the transport (nil: the default).
func streamProxy(rt http.RoundTripper, dir string) (prefix string, err error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	cache := &relay{
		songs:  newStore(filepath.Join(dir, "songs"), songCacheLimit),
		covers: newStore(filepath.Join(dir, "covers"), math.MaxInt64),
		client: &http.Client{Transport: rt, Timeout: time.Minute},
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
		switch r.URL.Path {
		case "/cache":
			cache.control(w, r)
			return
		case "/prefetch":
			cache.prefetch(w, r)
			return
		}
		u := target(r)
		if u == nil {
			http.Error(w, "not a stream", http.StatusBadRequest)
			return
		}
		if !cache.storeFor(u).serve(w, r, cacheKey(u)) {
			proxy.ServeHTTP(w, r)
		}
	})
	go func() { _ = http.Serve(ln, serve) }() // stops only with the program
	return "http://" + ln.Addr().String() + "/?u=", nil
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
		trim(c.songs.dir, 0)
	case "covers":
		trim(c.covers.dir, 0)
	}
	_, _ = fmt.Fprintf(w, `{"songs":%d,"covers":%d}`, trim(c.songs.dir, c.songs.limit.Load()), trim(c.covers.dir, c.covers.limit.Load()))
}

// save copies res to the store as the player reads it, when it brings the whole file.
func (c *store) save(res *http.Response) {
	if id, total := cacheKey(res.Request.URL), whole(res); !c.off.Load() && id != "" && total != 0 {
		if f, err := os.CreateTemp(c.dir, ".part-*"); err == nil {
			res.Body = &caching{ReadCloser: res.Body, f: f, total: total, path: filepath.Join(c.dir, id), cache: c}
		}
	}
}

// serve answers with the file of this id from the store, if it is there.
func (c *store) serve(w http.ResponseWriter, r *http.Request, id string) bool {
	if c.off.Load() || id == "" {
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

// whole is the file's size when res brings all of it (200, or 206 from its first byte to
// its last), -1 for a 200 of unknown size (a cover, chunked), else 0.
func whole(res *http.Response) int64 {
	if res.StatusCode == http.StatusOK {
		return res.ContentLength
	}
	var end, total int64
	_, err := fmt.Sscanf(res.Header.Get("Content-Range"), "bytes 0-%d/%d", &end, &total)
	if err == nil && res.StatusCode == http.StatusPartialContent && end == total-1 {
		return total
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
	trim(c.cache.dir, c.cache.limit.Load())
	return err
}

// trim deletes the files used longest ago until dir holds at most limit bytes, and
// returns what it holds then.
func trim(dir string, limit int64) int64 {
	entries, _ := os.ReadDir(dir)
	var files []os.FileInfo
	var size int64
	for _, e := range entries {
		if i, err := e.Info(); err == nil {
			files = append(files, i)
			size += i.Size()
		}
	}
	slices.SortFunc(files, func(a, b os.FileInfo) int { return a.ModTime().Compare(b.ModTime()) })
	for _, i := range files {
		if size <= limit {
			break
		}
		if os.Remove(filepath.Join(dir, i.Name())) == nil {
			size -= i.Size()
		}
	}
	return size
}
