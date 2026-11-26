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
	"sync"
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
	res, err = http.Get(prefix + url.QueryEscape("ftp://x/rest/stream?id=s1"))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Error("only http and https go through, got", res.StatusCode)
	}
	res, err = http.Get(prefix + url.QueryEscape("ftp://h/rest/stream?id=s1"))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Error("only http and https go through, got", res.StatusCode)
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
	songs := filepath.Join(dir, "songs")
	cached := func(id string) bool {
		for range 100 {
			if _, err := os.Stat(filepath.Join(songs, id)); err == nil {
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
	if entries, _ := os.ReadDir(songs); len(entries) != 2 {
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
		read  int
	}{
		{10, filepath.Join(dir, "short"), 3},    // fewer bytes than said
		{3, filepath.Join(dir, "no", "dir"), 3}, // nowhere to go
		{-1, filepath.Join(dir, "cut"), 1},      // size unknown, not read to the end
	} {
		f, _ := os.CreateTemp(dir, ".part-*")
		body := &caching{ReadCloser: io.NopCloser(strings.NewReader("abc")), f: f, total: c.total, path: c.path, cache: &store{dir: dir}}
		if c.read == 3 {
			io.ReadAll(body)
		} else {
			body.Read(make([]byte, c.read))
		}
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
	songs, covers := filepath.Join(dir, "songs"), filepath.Join(dir, "covers")
	os.WriteFile(filepath.Join(covers, "cover.360.a"), []byte("jpeg"), 0o644)
	old := filepath.Join(songs, "old")
	os.WriteFile(old, song, 0o644)
	os.Chtimes(old, time.Now().Add(-time.Hour), time.Now().Add(-time.Hour))

	size("on=0")
	play("old") // off: not played from the cache (the server answers)
	play("s1")
	if _, err := os.Stat(filepath.Join(songs, "s1")); err == nil {
		t.Error("off, a song is saved")
	}
	size("on=1")
	play("s1")
	if got := size(""); got != `{"songs":28000,"covers":4}` {
		t.Error("two songs:", got)
	}
	if got := size("limit=0.00002"); got != `{"songs":14000,"covers":4}` { // 21 KB: the newest song left
		t.Error("smaller:", got)
	}
	if _, err := os.Stat(old); err == nil {
		t.Error("the oldest song is kept")
	}
	if got := size("clear=songs"); got != `{"songs":0,"covers":4}` {
		t.Error("songs cleared, covers kept:", got)
	}
	if got := size("clear=covers"); got != `{"songs":0,"covers":0}` {
		t.Error("covers cleared:", got)
	}
}

// A cover (any size, sent chunked) is cached by id and size: it shows with the server gone.
func TestCoverCache(t *testing.T) {
	jpeg := bytes.Repeat([]byte("\xff\xd8jpeg"), 500)
	webp := append([]byte("RIFF\x00\x10\x00\x00WEBPVP8L"), bytes.Repeat([]byte{7}, 500)...) // Navidrome's placeholder
	navidrome := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/getCoverArt" {
			http.NotFound(w, r)
			return
		}
		if r.URL.Query().Get("id") == "al-2_0" {
			w.Write(webp)
			return
		}
		w.Write(jpeg[:100])
		w.(http.Flusher).Flush() // chunked: no Content-Length
		w.Write(jpeg[100:])
	}))
	dir := t.TempDir()
	prefix, err := streamProxy(navidrome.Client().Transport, dir)
	if err != nil {
		t.Fatal(err)
	}
	get := func(q string) (int, []byte) {
		res, err := http.Get(prefix + url.QueryEscape(navidrome.URL+"/rest/getCoverArt?"+q))
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		b, _ := io.ReadAll(res.Body)
		return res.StatusCode, b
	}
	get("id=al-1_0&size=300")
	get("id=al-1_0&size=../x")                                    // not a plain size: not cached
	if _, b := get("id=al-2_0&size=300"); !bytes.Equal(b, webp) { // the placeholder: shown, not cached
		t.Fatalf("placeholder: %d bytes", len(b))
	}
	for range 100 {
		if _, err := os.Stat(filepath.Join(dir, "covers", "cover.300.al-1_0")); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if entries, _ := os.ReadDir(filepath.Join(dir, "covers")); len(entries) != 1 {
		t.Fatal("one cover cached:", entries)
	}
	// Cleared while it runs (Settings › Apps): the next cover is kept again.
	os.RemoveAll(filepath.Join(dir, "covers"))
	get("id=al-3_0&size=300")
	for range 100 {
		if _, err := os.Stat(filepath.Join(dir, "covers", "cover.300.al-3_0")); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if _, err := os.Stat(filepath.Join(dir, "covers", "cover.300.al-3_0")); err != nil {
		t.Fatal("not kept after the cache was cleared:", err)
	}
	get("id=al-1_0&size=300") // back in the cache too, for the check below
	for range 100 {
		if _, err := os.Stat(filepath.Join(dir, "covers", "cover.300.al-1_0")); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	navidrome.Close()
	if code, b := get("id=al-1_0&size=300"); code != http.StatusOK || !bytes.Equal(b, jpeg) {
		t.Fatalf("from the cache: %d, %d bytes", code, len(b))
	}
}

// Covers fetched ahead: the ones missing, one at a time; not songs; also with songs off.
func TestCoverPrefetch(t *testing.T) {
	var asked []string
	var mu sync.Mutex
	navidrome := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		asked = append(asked, r.URL.Path+"?"+r.URL.Query().Get("id"))
		mu.Unlock()
		w.Write([]byte("jpeg " + r.URL.Query().Get("id")))
	}))
	defer navidrome.Close()
	dir := t.TempDir()
	prefix, err := streamProxy(nil, dir)
	if err != nil {
		t.Fatal(err)
	}
	covers := filepath.Join(dir, "covers")
	os.WriteFile(filepath.Join(covers, "cover.360.have"), []byte("jpeg have"), 0o644)
	base := strings.TrimSuffix(prefix, "?u=")
	post := func(list ...string) {
		res, err := http.Post(base+"prefetch", "text/plain", strings.NewReader(strings.Join(list, "\n")))
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
	}
	done := func(n int) bool {
		for range 100 {
			if entries, _ := os.ReadDir(covers); len(entries) == n {
				return true
			}
			time.Sleep(20 * time.Millisecond)
		}
		return false
	}
	cover := func(id string) string { return navidrome.URL + "/rest/getCoverArt?size=360&id=" + id }

	post(cover("a1"), cover("have"), navidrome.URL+"/rest/stream?id=s1", "ftp://x/rest/getCoverArt?id=f",
		cover("../x"), "http://127.0.0.1:1/rest/getCoverArt?size=360&id=gone", cover("a2"))
	if !done(3) { // a2 last: the list is done
		t.Fatal("a1 and a2 fetched")
	}
	mu.Lock()
	if strings.Join(asked, " ") != "/rest/getCoverArt?a1 /rest/getCoverArt?a2" {
		t.Error("asked:", asked)
	}
	mu.Unlock()
	if b, _ := os.ReadFile(filepath.Join(covers, "cover.360.a2")); string(b) != "jpeg a2" {
		t.Errorf("a2: %q", b)
	}

	http.Get(base + "cache?on=0") // the songs' switch: covers are always kept
	time.Sleep(100 * time.Millisecond)
	post(cover("a3"))
	if !done(4) {
		t.Error("songs off, a cover is not fetched")
	}
}
