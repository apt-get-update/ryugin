package main

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

// The phone's player gets Navidrome's https stream over plain http, and can seek in it.
func TestStreamProxy(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/stream" || r.URL.Query().Get("id") != "s1" {
			http.NotFound(w, r)
			return
		}
		http.ServeContent(w, r, "song.flac", time.Time{}, bytes.NewReader(song))
	}))
	defer navidrome.Close()
	prefix, err := streamProxy(navidrome.Client().Transport, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}

	req, _ := http.NewRequest("GET", prefix+url.QueryEscape(navidrome.URL+"/rest/stream?u=x&id=s1"), nil)
	req.Header.Set("Range", "bytes=100-109")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if res.StatusCode != http.StatusPartialContent || !bytes.Equal(body, song[100:110]) {
		t.Fatalf("seek: %d %q", res.StatusCode, body)
	}

	res, err = http.Get(prefix + url.QueryEscape(navidrome.URL+"/rest/getUser?id=s1"))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Error("only streams go through, got", res.StatusCode)
	}
}

// No socket left (too many open files): an error, not a crash.
func TestStreamProxyNoSocket(t *testing.T) {
	var old syscall.Rlimit
	syscall.Getrlimit(syscall.RLIMIT_NOFILE, &old)
	low := old
	low.Cur = 0
	syscall.Setrlimit(syscall.RLIMIT_NOFILE, &low)
	_, err := streamProxy(nil, t.TempDir())
	syscall.Setrlimit(syscall.RLIMIT_NOFILE, &old)
	if err == nil {
		t.Error("no error")
	}
}

// A song streamed whole is cached: it plays again (and seeks) with the server gone.
func TestSongCache(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeContent(w, r, "song.flac", time.Time{}, bytes.NewReader(song))
	}))
	dir := t.TempDir()
	prefix, err := streamProxy(navidrome.Client().Transport, dir)
	if err != nil {
		t.Fatal(err)
	}
	get := func(id, rng string) (int, []byte) {
		req, _ := http.NewRequest("GET", prefix+url.QueryEscape(navidrome.URL+"/rest/stream?id="+id), nil)
		if rng != "" {
			req.Header.Set("Range", rng)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		body, _ := io.ReadAll(res.Body)
		return res.StatusCode, body
	}
	cached := func(id string) bool {
		for range 100 {
			if _, err := os.Stat(filepath.Join(dir, id)); err == nil {
				return true
			}
			time.Sleep(20 * time.Millisecond)
		}
		return false
	}
	get("s1", "bytes=0-") // FFmpeg's first request: 206, every byte
	get("s2", "")         // 200
	get("s3", "bytes=100-109")
	get("..", "") // not a file name: never cached
	if !cached("s1") || !cached("s2") {
		t.Fatal("not cached")
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 2 {
		t.Error("only s1 and s2 are cached, not a part or a bad id:", entries)
	}

	navidrome.Close()
	if code, body := get("s1", "bytes=100-109"); code != http.StatusPartialContent || !bytes.Equal(body, song[100:110]) {
		t.Fatalf("from the cache: %d %q", code, body)
	}
}

// A copy cut short, or one with nowhere to go, is dropped.
func TestSongCacheDropped(t *testing.T) {
	dir := t.TempDir()
	for _, c := range []struct {
		total int64
		path  string
	}{{10, filepath.Join(dir, "short")}, {3, filepath.Join(dir, "no", "dir")}} {
		f, _ := os.CreateTemp(dir, ".part-*")
		body := &caching{ReadCloser: io.NopCloser(strings.NewReader("abc")), f: f, total: c.total, path: c.path, cache: &songCache{dir: dir}}
		io.ReadAll(body)
		body.Close()
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 0 {
		t.Error("left:", entries)
	}
}

// Over its size, the cache drops the songs played longest ago.
func TestSongCacheTrim(t *testing.T) {
	dir := t.TempDir()
	for i, name := range []string{"old", "new"} {
		p := filepath.Join(dir, name)
		os.WriteFile(p, make([]byte, 10), 0o644)
		at := time.Now().Add(time.Duration(i-2) * time.Hour)
		os.Chtimes(p, at, at)
	}
	trim(dir, 15)
	if _, err := os.Stat(filepath.Join(dir, "old")); err == nil {
		t.Error("the oldest song is kept")
	}
	if _, err := os.Stat(filepath.Join(dir, "new")); err != nil {
		t.Error("the newest song is gone")
	}
}

// The settings page: off (nothing saved nor played from the cache), its size, clear.
func TestSongCacheControl(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.ServeContent(w, r, "song.flac", time.Time{}, bytes.NewReader(song))
	}))
	defer navidrome.Close()
	dir := t.TempDir()
	prefix, err := streamProxy(navidrome.Client().Transport, dir)
	if err != nil {
		t.Fatal(err)
	}
	control := strings.TrimSuffix(prefix, "?u=") + "cache?"
	size := func(q string) string {
		res, err := http.Get(control + q)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		b, _ := io.ReadAll(res.Body)
		return string(b)
	}
	play := func(id string) {
		res, err := http.Get(prefix + url.QueryEscape(navidrome.URL+"/rest/stream?id="+id))
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, res.Body)
		res.Body.Close()
		time.Sleep(100 * time.Millisecond) // the copy is renamed after the answer
	}
	old := filepath.Join(dir, "old")
	os.WriteFile(old, song, 0o644)
	os.Chtimes(old, time.Now().Add(-time.Hour), time.Now().Add(-time.Hour))

	size("on=0")
	play("old") // off: not played from the cache (the server answers)
	play("s1")
	if _, err := os.Stat(filepath.Join(dir, "s1")); err == nil {
		t.Error("off, a song is saved")
	}
	size("on=1")
	play("s1")
	if got := size(""); got != `{"size":28000}` {
		t.Error("two songs:", got)
	}
	if got := size("limit=0.00002"); got != `{"size":14000}` { // 21 KB: the newest song left
		t.Error("smaller:", got)
	}
	if _, err := os.Stat(old); err == nil {
		t.Error("the oldest song is kept")
	}
	if got := size("clear=1"); got != `{"size":0}` {
		t.Error("cleared:", got)
	}
}
