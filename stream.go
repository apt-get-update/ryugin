package main

import (
	"fmt"
	"io"
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

// songCacheLimit: the song cache's default size, as SPlayer's (10 GB). The songs played
// longest ago go first.
const songCacheLimit = 10 << 30

// songCache: the songs streamed whole, in dir (named by their id). The settings page turns
// it off (no song saved nor played from it) and sets its size.
type songCache struct {
	dir   string
	off   atomic.Bool
	limit atomic.Int64
}

// streamProxy serves Navidrome's streams over plain http on 127.0.0.1, on every platform:
// Sailfish OS needs it (Chum's FFmpeg has no https), and it keeps the song cache in dir.
// QML asks for prefix + the escaped stream URL; Range passes through, so seeking works.
// Only Subsonic stream URLs go through. A song streamed whole is saved in dir; the next
// time it plays from there, with no server. prefix without "?u=" + "cache" is the cache's
// settings (cache.control). rt is the transport (nil: the default).
func streamProxy(rt http.RoundTripper, dir string) (prefix string, err error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	cache := &songCache{dir: dir}
	cache.limit.Store(songCacheLimit)
	target := func(r *http.Request) *url.URL {
		u, err := url.Parse(r.URL.Query().Get("u"))
		if err != nil || (u.Scheme != "https" && u.Scheme != "http") || !strings.HasSuffix(u.Path, "/rest/stream") {
			return nil
		}
		return u
	}
	proxy := &httputil.ReverseProxy{Transport: rt, Rewrite: func(r *httputil.ProxyRequest) {
		r.Out.URL = target(r.In)
		r.Out.Host = ""
	}, ModifyResponse: func(res *http.Response) error {
		cache.save(res)
		return nil
	}}
	serve := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/cache" {
			cache.control(w, r)
			return
		}
		u := target(r)
		if u == nil {
			http.Error(w, "not a stream", http.StatusBadRequest)
			return
		}
		if !cache.serve(w, r, songID(u)) {
			proxy.ServeHTTP(w, r)
		}
	})
	go func() { _ = http.Serve(ln, serve) }() // stops only with the program
	return "http://" + ln.Addr().String() + "/?u=", nil
}

// control applies the settings page's choices, all optional: on (1 or 0), limit (GB),
// clear (1). It answers the cache's size in bytes: {"size": n}.
func (c *songCache) control(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if on := q.Get("on"); on != "" {
		c.off.Store(on == "0")
	}
	if gb, err := strconv.ParseFloat(q.Get("limit"), 64); err == nil && gb > 0 {
		c.limit.Store(int64(gb * (1 << 30)))
	}
	if q.Get("clear") == "1" {
		trim(c.dir, 0)
	}
	_, _ = fmt.Fprintf(w, `{"size":%d}`, trim(c.dir, c.limit.Load()))
}

// save copies res to the cache as the player reads it, when it brings the whole song.
func (c *songCache) save(res *http.Response) {
	if id, total := songID(res.Request.URL), whole(res); !c.off.Load() && id != "" && total > 0 {
		if f, err := os.CreateTemp(c.dir, ".part-*"); err == nil {
			res.Body = &caching{ReadCloser: res.Body, f: f, total: total, path: filepath.Join(c.dir, id), cache: c}
		}
	}
}

// serve plays the song with this id from the cache, if it is there.
func (c *songCache) serve(w http.ResponseWriter, r *http.Request, id string) bool {
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

// songID is the stream URL's song id, "" when it is not a plain file name.
func songID(u *url.URL) string {
	id := u.Query().Get("id")
	for _, c := range id {
		if c != '-' && c != '_' && !unicode.IsLetter(c) && !unicode.IsDigit(c) {
			return ""
		}
	}
	return id
}

// whole is the song's size when res brings all of it (200, or 206 from its first byte to
// its last), else 0.
func whole(res *http.Response) int64 {
	if res.StatusCode == http.StatusOK {
		return max(res.ContentLength, 0)
	}
	var end, total int64
	_, err := fmt.Sscanf(res.Header.Get("Content-Range"), "bytes 0-%d/%d", &end, &total)
	if err == nil && res.StatusCode == http.StatusPartialContent && end == total-1 {
		return total
	}
	return 0
}

// caching copies a stream to f as the player reads it. Closed with every byte there, f
// becomes the cached song; else (the player seeked or stopped) it is dropped.
type caching struct {
	io.ReadCloser
	f        *os.File
	n, total int64
	path     string
	cache    *songCache
}

func (c *caching) Read(p []byte) (int, error) {
	n, err := c.ReadCloser.Read(p)
	w, _ := c.f.Write(p[:n]) // a failed write leaves the copy short: dropped
	c.n += int64(w)
	return n, err
}

func (c *caching) Close() error {
	err := c.ReadCloser.Close()
	_ = c.f.Close()
	if c.n != c.total || os.Rename(c.f.Name(), c.path) != nil {
		_ = os.Remove(c.f.Name())
		return err
	}
	trim(c.cache.dir, c.cache.limit.Load())
	return err
}

// trim deletes the songs played longest ago until dir holds at most limit bytes, and
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
