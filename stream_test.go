package main

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
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
	prefix, err := streamProxy(navidrome.Client().Transport)
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
	_, err := streamProxy(nil)
	syscall.Setrlimit(syscall.RLIMIT_NOFILE, &old)
	if err == nil {
		t.Error("no error")
	}
}
