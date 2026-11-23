// A tiny fake Navidrome (Subsonic JSON API) for the QML tests. It accepts any login,
// serves a fixed library, and records the calls it gets (GET /calls lists them).
//
//	go run ./tests/mocknavidrome -addr 127.0.0.1:4533
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
)

var (
	mu       sync.Mutex
	calls    []string
	scans    int
	lastScan = "2026-11-21T12:00:00Z"
)

func ok(w http.ResponseWriter, body map[string]any) {
	body["status"] = "ok"
	body["version"] = "1.16.1"
	json.NewEncoder(w).Encode(map[string]any{"subsonic-response": body})
}

func song(i int) map[string]any {
	titles := []string{"Blink", "Creek", "Feel"}
	return map[string]any{"id": fmt.Sprint("s", i), "title": titles[i], "artist": "Hiroshi Yoshimura", "artistId": "ar1",
		"album": "Green", "albumId": "a", "coverArt": "c", "duration": 245, "track": i + 1, "starred": i == 1}
}

func songs() []map[string]any { return []map[string]any{song(0), song(1), song(2)} }

func albums(prefix string) []map[string]any {
	out := []map[string]any{}
	for i, n := range []string{"Green", "Music for Nine Postcards", "Wet Land", "Pier & Loft"} {
		out = append(out, map[string]any{"id": fmt.Sprint(prefix, i), "name": n, "artist": "Hiroshi Yoshimura", "artistId": "ar1",
			"coverArt": "c", "year": 1986 + i, "songCount": 3, "duration": 735})
	}
	return out
}

func main() {
	addr := flag.String("addr", "127.0.0.1:4533", "listen address")
	flag.Parse()

	img := image.NewRGBA(image.Rect(0, 0, 64, 64))
	for i := range img.Pix {
		img.Pix[i] = []uint8{40, 90, 200, 255}[i%4]
	}
	img.Set(0, 0, color.White)
	var cover bytes.Buffer
	png.Encode(&cover, img)

	// A new scan of the library (getScanStatus's lastScan).
	http.HandleFunc("/scan", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		scans++
		lastScan = fmt.Sprintf("2026-11-21T12:%02d:00Z", scans)
		mu.Unlock()
	})
	http.HandleFunc("/calls", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		json.NewEncoder(w).Encode(calls)
		if r.URL.Query().Get("reset") != "" {
			calls = nil
		}
	})
	// Go's relay, as QML sees it: the covers to fetch ahead (logged as "prefetch?<body>").
	http.HandleFunc("/prefetch", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		mu.Lock()
		calls = append(calls, "prefetch?"+string(body))
		mu.Unlock()
	})
	// LRCLIB: "Snow" is found by get, "Rain" only by search; both synced.
	http.HandleFunc("/lrclib/", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		mu.Lock()
		calls = append(calls, "lrclib"+strings.TrimPrefix(r.URL.Path, "/lrclib/")+"?"+r.URL.RawQuery)
		mu.Unlock()
		hit := map[string]any{"duration": 200, "plainLyrics": "wind\nrain", "syncedLyrics": "[00:01.00] wind\n[00:02.50] rain\n[00:04.00]"}
		switch {
		case strings.HasSuffix(r.URL.Path, "/get") && q.Get("track_name") == "Snow":
			json.NewEncoder(w).Encode(hit)
		case strings.HasSuffix(r.URL.Path, "/search") && q.Get("track_name") == "Moss" && q.Get("artist_name") == "":
			json.NewEncoder(w).Encode([]any{
				map[string]any{"duration": 100, "syncedLyrics": "[00:01.00] wrong song"},
				map[string]any{"duration": 200, "syncedLyrics": "[00:03.00] moss"}})
		case strings.HasSuffix(r.URL.Path, "/search") && q.Get("q") == "Green":
			json.NewEncoder(w).Encode([]any{
				map[string]any{"duration": 245.05, "trackName": "緑 (インストゥルメンタル)", "syncedLyrics": "[00:01.00] instrumental"},
				map[string]any{"duration": 245.1, "trackName": "緑", "plainLyrics": "みどり\nいろ"},
				map[string]any{"duration": 245.6, "trackName": "other", "syncedLyrics": "[00:01.00] other"}})
		case strings.HasSuffix(r.URL.Path, "/search") && q.Get("track_name") == "ブリンク!!": // NFKC of ‼
			json.NewEncoder(w).Encode([]any{
				map[string]any{"duration": 300, "syncedLyrics": "[00:01.00] too long"},
				map[string]any{"duration": 248, "syncedLyrics": "[00:02.00] まばたき"}})
		case strings.HasSuffix(r.URL.Path, "/search") && q.Get("track_name") == "Rain":
			json.NewEncoder(w).Encode([]any{map[string]any{"plainLyrics": "only plain"}, hit})
		case strings.HasSuffix(r.URL.Path, "/search") && q.Get("track_name") == "Hail": // another version only
			json.NewEncoder(w).Encode([]any{map[string]any{"duration": 230, "plainLyrics": "hail", "syncedLyrics": "[00:01.00] hail"}})
		case strings.HasSuffix(r.URL.Path, "/search"):
			w.Write([]byte("[]"))
		default:
			http.NotFound(w, r)
		}
	})
	// MusicBrainz: the album "Green" with its original (Japanese) titles.
	http.HandleFunc("/mb/", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		calls = append(calls, "mb"+strings.TrimPrefix(r.URL.Path, "/mb/")+"?ua="+r.Header.Get("User-Agent")+"&"+r.URL.RawQuery)
		mu.Unlock()
		switch {
		case r.URL.Path == "/mb/release/" && strings.Contains(r.URL.Query().Get("query"), `"Green"`):
			json.NewEncoder(w).Encode(map[string]any{"releases": []any{map[string]any{"id": "r1"}}})
		case r.URL.Path == "/mb/release/":
			json.NewEncoder(w).Encode(map[string]any{"releases": []any{}})
		case r.URL.Path == "/mb/release/r1":
			tracks := []any{}
			for _, title := range []string{"ブリンク‼", "クリーク", "フィール"} {
				tracks = append(tracks, map[string]any{"title": title, "length": 245000, "artist-credit": []any{map[string]any{"name": "吉村弘"}}})
			}
			json.NewEncoder(w).Encode(map[string]any{"media": []any{map[string]any{"tracks": tracks}}})
		default:
			http.NotFound(w, r)
		}
	})
	http.HandleFunc("/rest/", func(w http.ResponseWriter, r *http.Request) {
		m := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/rest/"), ".view")
		q := r.URL.Query()
		mu.Lock()
		calls = append(calls, m+"?"+r.URL.RawQuery)
		mu.Unlock()
		switch m {
		case "getCoverArt":
			if q.Get("id") == "unresizable" && q.Get("size") != "" { // as some covers on a real server
				http.Error(w, "resize failed", http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "image/png")
			w.Write(cover.Bytes())
		case "stream":
			http.NotFound(w, r)
		case "getAlbumList2":
			ok(w, map[string]any{"albumList2": map[string]any{"album": albums(q.Get("type") + "-")}})
		case "getAlbum":
			ok(w, map[string]any{"album": map[string]any{"id": "a", "name": "Green", "artist": "Hiroshi Yoshimura", "artistId": "ar1",
				"coverArt": "c", "year": 1986, "duration": 735, "song": songs()}})
		case "getArtists":
			ok(w, map[string]any{"artists": map[string]any{"index": []any{map[string]any{"name": "H", "artist": []any{
				map[string]any{"id": "ar1", "name": "Hiroshi Yoshimura", "albumCount": 4}}}}}})
		case "getArtist":
			ok(w, map[string]any{"artist": map[string]any{"id": "ar1", "name": "Hiroshi Yoshimura", "album": albums("ar-")}})
		case "getPlaylists":
			ok(w, map[string]any{"playlists": map[string]any{"playlist": []any{map[string]any{"id": "p1", "name": "Ambient", "songCount": 3, "coverArt": "c"}}}})
		case "getPlaylist":
			ok(w, map[string]any{"playlist": map[string]any{"id": "p1", "name": "Ambient", "entry": songs()}})
		case "search3":
			ok(w, map[string]any{"searchResult3": map[string]any{"artist": []any{map[string]any{"id": "ar1", "name": "Hiroshi Yoshimura"}},
				"album": albums("q-"), "song": songs()}})
		case "getRandomSongs":
			ok(w, map[string]any{"randomSongs": map[string]any{"song": songs()}})
		case "getStarred2":
			ok(w, map[string]any{"starred2": map[string]any{"song": []any{song(1)}}})
		case "getScanStatus":
			mu.Lock()
			last := lastScan
			mu.Unlock()
			ok(w, map[string]any{"scanStatus": map[string]any{"scanning": false, "count": 1234, "lastScan": last}})
		case "getLyricsBySongId":
			// s0 has synced lyrics; the others have none here.
			if q.Get("id") != "s0" {
				ok(w, map[string]any{"lyricsList": map[string]any{}})
				return
			}
			lines := []map[string]any{}
			for i, l := range []string{"Water over stone", "the moss remembers", "a bell, far away"} {
				lines = append(lines, map[string]any{"start": i * 4000, "value": l})
			}
			// Word times for the first line (enhanced): the main voice, then a backing one.
			cue := func(v string, s, e int) map[string]any {
				return map[string]any{"value": v, "start": s, "byteStart": 0, "byteEnd": e}
			}
			words := []any{cue("Water", 0, 4), map[string]any{"value": "over", "start": 800, "byteStart": 6, "byteEnd": 9},
				map[string]any{"value": "stone", "start": 1600, "end": 3000, "byteStart": 11, "byteEnd": 15}}
			cueLines := []any{
				map[string]any{"index": 0, "start": 0, "end": 3000, "value": "Water over stone", "cue": words},
				map[string]any{"index": 0, "start": 0, "value": "ah", "cue": []any{cue("ah", 0, 1)}},
			}
			if q.Get("enhanced") != "true" {
				cueLines = nil
			}
			ok(w, map[string]any{"lyricsList": map[string]any{"structuredLyrics": []any{map[string]any{"synced": true, "line": lines, "cueLine": cueLines}}}})
		case "getLyrics":
			// Plain lyrics for "Creek"; the tag as is (enhanced LRC) for "Sleet".
			switch q.Get("title") {
			case "Sleet":
				ok(w, map[string]any{"lyrics": map[string]any{"value": "[ar:x]\n[00:01.00]<00:01.00>ice <00:01.50>falls<00:02.00>\n[00:03.00]quiet"}})
			case "Creek":
				ok(w, map[string]any{"lyrics": map[string]any{"value": "first line\nsecond line"}})
			default:
				ok(w, map[string]any{"lyrics": map[string]any{}})
			}
		case "fail":
			json.NewEncoder(w).Encode(map[string]any{"subsonic-response": map[string]any{"status": "failed", "error": map[string]any{"code": 40, "message": "Wrong username or password"}}})
		default: // ping, scrobble, star, unstar...
			ok(w, map[string]any{})
		}
	})
	log.Fatal(http.ListenAndServe(*addr, nil))
}
