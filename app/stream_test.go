package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/prop"
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
		if r.URL.Query().Get("id") == "gone" { // Navidrome's error, with a 200
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"subsonic-response":{"status":"failed","error":{"code":0,"message":"no such file"}}}`))
			return
		}
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
	get("..", "")   // not a file name: never cached
	get("gone", "") // an error: never cached
	if !cached("s1") || !cached("s2") || !cached("s3") {
		t.Fatal("not cached")
	}
	if entries, _ := os.ReadDir(songs); len(entries) != 3 {
		t.Error("only the songs are cached (a seek's too: downloaded whole), not a part, a bad id or an error:", entries)
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
	trim(dir, 15, 0)
	if _, err := os.Stat(filepath.Join(dir, "old")); err == nil {
		t.Error("the oldest song is kept")
	}
	if _, err := os.Stat(filepath.Join(dir, "new")); err != nil {
		t.Error("the newest song is gone")
	}
}

// The settings page: off (only the song playing and the next kept), its size, clear.
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
	play("s1")
	play("s2")
	play("s3")
	if entries, _ := os.ReadDir(songs); len(entries) != 2 || entries[0].Name() != "s2" || entries[1].Name() != "s3" {
		t.Error("off, only the 2 newest songs stay:", entries)
	}
	size("on=1")
	play("s1")
	if got := size(""); got != `{"songs":42000,"covers":4}` {
		t.Error("three songs:", got)
	}
	if got := size("limit=0.00002"); got != `{"songs":14000,"covers":4}` { // 21 KB: the newest song left
		t.Error("smaller:", got)
	}
	if _, err := os.Stat(filepath.Join(songs, "s1")); err != nil {
		t.Error("the newest song is gone")
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

// quick makes the downloads' waits short for a test.
func quick(t *testing.T, giveUp time.Duration) {
	s, r, g := stallAfter, retryAfter, giveUpAfter
	stallAfter, retryAfter, giveUpAfter = 100*time.Millisecond, 10*time.Millisecond, giveUp
	t.Cleanup(func() { stallAfter, retryAfter, giveUpAfter = s, r, g })
}

// flaky is Navidrome on a network that comes and goes: the answer to each request, in
// turn ("half": the headers and half the song, then the connection drops; "drop": it
// drops at once; "silent": half, then nothing; "missing": a 404; "shortrange": 10 bytes
// from the Range asked; "short": the song but its last byte; "norange": the whole song,
// Range or not; "chunked": the whole song, size unknown), then the song as asked.
func flaky(song []byte, turns ...string) *httptest.Server {
	var mu sync.Mutex
	return httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		turn := ""
		if len(turns) > 0 {
			turn, turns = turns[0], turns[1:]
		}
		mu.Unlock()
		switch turn {
		case "half", "silent":
			w.Header().Set("Content-Length", strconv.Itoa(len(song)))
			w.Write(song[:len(song)/2])
			w.(http.Flusher).Flush()
			if turn == "silent" {
				<-r.Context().Done()
				return
			}
			panic(http.ErrAbortHandler)
		case "drop":
			panic(http.ErrAbortHandler)
		case "missing":
			http.NotFound(w, r)
		case "shortrange":
			var from int
			fmt.Sscanf(r.Header.Get("Range"), "bytes=%d-", &from)
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", from, from+9, len(song)))
			w.Header().Set("Content-Length", "10")
			w.WriteHeader(http.StatusPartialContent)
			w.Write(song[from : from+10])
		case "short":
			w.Header().Set("Content-Length", strconv.Itoa(len(song)))
			w.Write(song[:len(song)-1])
			panic(http.ErrAbortHandler)
		case "norange":
			w.Write(song)
		case "chunked":
			w.Write(song[:100])
			w.(http.Flusher).Flush()
			w.Write(song[100:])
		default:
			http.ServeContent(w, r, "song.flac", time.Time{}, bytes.NewReader(song))
		}
	}))
}

// listen starts the relay in front of navidrome, and gives a song's URL through it.
func listen(t *testing.T, navidrome *httptest.Server, dir string) func(id string) string {
	prefix, err := streamProxy(navidrome.Client().Transport, dir)
	if err != nil {
		t.Fatal(err)
	}
	return func(id string) string { return prefix + url.QueryEscape(navidrome.URL+"/rest/stream?id="+id) }
}

func fetchSong(_ *testing.T, u, rng string) (int, []byte) {
	return fetchSongCtx(context.Background(), u, rng)
}

func fetchSongCtx(ctx context.Context, u, rng string) (int, []byte) {
	req, _ := http.NewRequestWithContext(ctx, "GET", u, nil)
	if rng != "" {
		req.Header.Set("Range", rng)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return 0, nil
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	return res.StatusCode, body
}

func waitFor(path string, there bool) bool {
	for range 300 {
		if _, err := os.Stat(path); (err == nil) == there {
			return true
		}
		time.Sleep(10 * time.Millisecond)
	}
	return false
}

func parts(dir string) []string {
	p, _ := filepath.Glob(filepath.Join(dir, "songs", ".part-*"))
	return p
}

// Wi-Fi lost on the way out, mobile data a moment after: the song plays on, whole, and is
// cached.
func TestSongTakenUpAgain(t *testing.T) {
	quick(t, time.Minute)
	song := bytes.Repeat([]byte("fLaC0123456789"), 20000)
	navidrome := flaky(song, "half", "missing", "shortrange", "half", "silent", "drop", "short", "norange")
	defer navidrome.Close()
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "songs"), 0o755)
	os.WriteFile(filepath.Join(dir, "songs", ".part-1"), []byte("x"), 0o644) // the last run's
	stream := listen(t, navidrome, dir)
	if len(parts(dir)) != 0 {
		t.Error("the last run's part is kept")
	}
	if code, body := fetchSong(t, stream("s1"), ""); code != http.StatusOK || !bytes.Equal(body, song) {
		t.Fatalf("%d, %d bytes of %d", code, len(body), len(song))
	}
	if !waitFor(filepath.Join(dir, "songs", "s1"), true) {
		t.Fatal("not cached")
	}
}

// A song of unknown size plays to its end, and is cached.
func TestSongUnknownSize(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := flaky(song, "chunked", "chunked")
	defer navidrome.Close()
	dir := t.TempDir()
	stream := listen(t, navidrome, dir)
	if code, body := fetchSong(t, stream("s1"), "bytes=100-"); code != http.StatusOK || !bytes.Equal(body, song) {
		t.Fatalf("%d, %d bytes", code, len(body))
	}
	if !waitFor(filepath.Join(dir, "songs", "s1"), true) {
		t.Fatal("not cached")
	}
}

// A Range out of the song: all of it.
func TestSongRangeOut(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := flaky(song)
	defer navidrome.Close()
	stream := listen(t, navidrome, t.TempDir())
	for i, rng := range []string{"bytes=-500", "bytes=999999-"} {
		if code, body := fetchSong(t, stream(fmt.Sprint("s", i)), rng); code != http.StatusPartialContent || !bytes.Equal(body, song) {
			t.Errorf("%s: %d, %d bytes", rng, code, len(body))
		}
	}
}

// No network for too long: the song stops where it got to, nothing is kept. With no
// answer at all, the player gets the relay's error.
func TestSongGivenUp(t *testing.T) {
	quick(t, 50*time.Millisecond)
	song := bytes.Repeat([]byte("fLaC0123456789"), 20000)
	drops := make([]string, 200)
	for i := range drops {
		drops[i] = "drop"
	}
	navidrome := flaky(song, append([]string{"half"}, drops...)...)
	defer navidrome.Close()
	dir := t.TempDir()
	stream := listen(t, navidrome, dir)
	if _, body := fetchSong(t, stream("s1"), ""); len(body) != len(song)/2 {
		t.Errorf("%d bytes, not the half that came", len(body))
	}
	if code, _ := fetchSong(t, stream("s2"), ""); code != http.StatusBadGateway {
		t.Error("no answer:", code)
	}
	if entries, _ := os.ReadDir(filepath.Join(dir, "songs")); len(entries) != 0 {
		t.Error("kept:", entries)
	}
}

// The player gone while it waits for the song (or for bytes further on): nothing stays
// waiting.
func TestSongPlayerGone(t *testing.T) {
	quick(t, time.Minute)
	song := bytes.Repeat([]byte("fLaC0123456789"), 20000)
	navidrome := flaky(song, "silent", "drop", "drop", "drop", "drop", "drop", "drop", "drop", "drop")
	defer navidrome.Close()
	stream := listen(t, navidrome, t.TempDir())
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if _, body := fetchSongCtx(ctx, stream("s1"), "bytes=270000-"); len(body) != 0 {
		t.Error("bytes not there yet:", len(body))
	}
	ctx, cancel = context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if _, body := fetchSongCtx(ctx, stream("s2"), ""); len(body) != 0 {
		t.Error("no answer yet:", len(body))
	}
}

// The player stops reading (another song): the relay stops sending.
func TestSongPlayerStops(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 2_000_000) // 28 MB: more than the sockets hold
	navidrome := flaky(song)
	defer navidrome.Close()
	dir := t.TempDir()
	stream := listen(t, navidrome, dir)
	res, err := http.Get(stream("s1"))
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Read(make([]byte, 10))
	res.Body.Close()
	if !waitFor(filepath.Join(dir, "songs", "s1"), true) {
		t.Fatal("not downloaded to the end")
	}
}

// The next song is downloaded once the one playing is there; a song played stops the
// other downloads.
func TestSongAhead(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	gate := make(chan struct{})
	navidrome := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Query().Get("id") {
		case "nf":
			http.NotFound(w, r)
			return
		case "s1":
			<-gate
		case "s4": // no network: it waits to try again
			panic(http.ErrAbortHandler)
		}
		http.ServeContent(w, r, "song.flac", time.Time{}, bytes.NewReader(song))
	}))
	defer navidrome.Close()
	dir := t.TempDir()
	stream := listen(t, navidrome, dir)
	songs := filepath.Join(dir, "songs")
	ahead := func(id string) {
		res, err := http.Get(strings.Replace(stream(id), "/?u=", "/ahead?u=", 1))
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != http.StatusAccepted {
			t.Error("ahead:", res.StatusCode)
		}
	}

	ahead("s2") // nothing else: at once
	if !waitFor(filepath.Join(songs, "s2"), true) {
		t.Fatal("s2 not downloaded")
	}
	ahead("s2") // there
	ahead("..") // not a song id

	var wg sync.WaitGroup
	for range 2 { // played twice at once: one download
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, body := fetchSong(t, stream("s1"), ""); !bytes.Equal(body, song) {
				t.Error("s1:", len(body))
			}
		}()
	}
	for len(parts(dir)) == 0 {
		time.Sleep(10 * time.Millisecond)
	}
	ahead("s1") // being downloaded
	ahead("s3") // after s1
	time.Sleep(50 * time.Millisecond)
	if _, err := os.Stat(filepath.Join(songs, "s3")); err == nil {
		t.Error("s3 downloaded before s1 is there")
	}
	close(gate)
	wg.Wait()
	if !waitFor(filepath.Join(songs, "s3"), true) {
		t.Fatal("s3 not downloaded after s1")
	}

	ahead("s4")                                                              // never comes
	time.Sleep(200 * time.Millisecond)                                       // waiting to try again
	if _, body := fetchSong(t, stream("s5"), ""); !bytes.Equal(body, song) { // s4 stops
		t.Error("s5:", len(body))
	}
	if !waitFor(filepath.Join(songs, "s5"), true) || !waitFor(filepath.Join(songs, "s4"), false) {
		t.Error("s5 not kept, or s4 kept")
	}
	for range 100 {
		if len(parts(dir)) == 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if p := parts(dir); len(p) != 0 {
		t.Error("s4's part kept:", p)
	}
	if code, _ := fetchSong(t, stream("nf"), ""); code != http.StatusNotFound {
		t.Error("Navidrome's 404:", code)
	}
}

// No room for the song (store not writable, or full): it plays all the same, from
// Navidrome, or as far as it got.
func TestSongNoRoom(t *testing.T) {
	song := bytes.Repeat([]byte("fLaC0123456789"), 1000)
	navidrome := flaky(song)
	defer navidrome.Close()
	dir := t.TempDir()
	stream := listen(t, navidrome, dir)
	songs := filepath.Join(dir, "songs")
	os.Chmod(songs, 0o500)
	if _, body := fetchSong(t, stream("s1"), ""); !bytes.Equal(body, song) {
		t.Error("not writable:", len(body))
	}
	res, err := http.Get(strings.Replace(stream("s2"), "/?u=", "/ahead?u=", 1))
	if err == nil {
		res.Body.Close()
	}
	os.Chmod(songs, 0o755)

	signal.Ignore(syscall.SIGXFSZ)
	defer signal.Reset(syscall.SIGXFSZ)
	var old syscall.Rlimit
	syscall.Getrlimit(syscall.RLIMIT_FSIZE, &old)
	low := old
	low.Cur = 5000
	syscall.Setrlimit(syscall.RLIMIT_FSIZE, &low)
	_, body := fetchSong(t, stream("s3"), "")
	syscall.Setrlimit(syscall.RLIMIT_FSIZE, &old)
	if len(body) >= len(song) {
		t.Error("full: all of it", len(body))
	}
	if entries, _ := os.ReadDir(songs); len(entries) != 0 {
		t.Error("kept:", entries)
	}
}

// connman is Sailfish OS's network service, on a test bus: its services, the one in use
// first.
type connman struct{ services [][2]string } // type, state

//nolint:unparam // a D-Bus method returns its error
func (c *connman) GetServices() ([]struct {
	Path  dbus.ObjectPath
	Props map[string]dbus.Variant
}, *dbus.Error) {
	out := []struct {
		Path  dbus.ObjectPath
		Props map[string]dbus.Variant
	}{}
	for i, s := range c.services {
		out = append(out, struct {
			Path  dbus.ObjectPath
			Props map[string]dbus.Variant
		}{dbus.ObjectPath(fmt.Sprint("/net/connman/service/s", i)), map[string]dbus.Variant{"Type": dbus.MakeVariant(s[0]), "State": dbus.MakeVariant(s[1])}})
	}
	return out, nil
}

// Mobile data or not: NetworkManager's word (a desktop), else connman's (Sailfish OS).
func TestMetered(t *testing.T) {
	srv := privateBus(t)
	conn := anonymous(t)
	if metered(conn) {
		t.Error("nothing on the bus: metered")
	}
	nm, err := prop.Export(srv, "/org/freedesktop/NetworkManager", prop.Map{"org.freedesktop.NetworkManager": {"Metered": {Value: uint32(1)}}})
	if err != nil {
		t.Fatal(err)
	}
	srv.RequestName("org.freedesktop.NetworkManager", dbus.NameFlagDoNotQueue)
	for m, want := range map[uint32]bool{1: true, 3: true, 2: false, 4: false, 0: false} {
		nm.SetMust("org.freedesktop.NetworkManager", "Metered", m)
		if metered(conn) != want {
			t.Errorf("NetworkManager %d: not %v", m, want)
		}
	}
	c := &connman{}
	srv.Export(c, "/", "net.connman.Manager")
	srv.RequestName("net.connman", dbus.NameFlagDoNotQueue)
	for _, s := range []struct {
		services [][2]string
		want     bool
	}{
		{[][2]string{{"cellular", "ready"}, {"wifi", "idle"}}, true},
		{[][2]string{{"wifi", "online"}, {"cellular", "ready"}}, false},
		{[][2]string{{"wifi", "idle"}, {"cellular", "online"}}, true},
		{[][2]string{{"wifi", "idle"}}, false}, // offline (NetworkManager's 1 not asked)
	} {
		c.services = s.services
		if metered(conn) != s.want {
			t.Errorf("connman %v: not %v", s.services, s.want)
		}
	}
	onMeter() // the system bus, if any: no crash
}

// QML asks the relay whether the network costs.
func TestNetworkAsked(t *testing.T) {
	old := onMeter
	onMeter = func() bool { return true }
	defer func() { onMeter = old }()
	prefix, err := streamProxy(nil, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	res, err := http.Get(strings.TrimSuffix(prefix, "?u=") + "network")
	if err != nil {
		t.Fatal(err)
	}
	b, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if string(b) != `{"metered":true}` {
		t.Error(string(b))
	}
}
