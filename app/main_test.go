package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/godbus/dbus/v5"
)

// serve returns the URL of a server answering every request with a PNG drawn by fill.
func serve(t *testing.T, fill func(x, y int) color.Color) string {
	img := image.NewRGBA(image.Rect(0, 0, 64, 64))
	for y := 0; y < 64; y++ {
		for x := 0; x < 64; x++ {
			img.Set(x, y, fill(x, y))
		}
	}
	var b bytes.Buffer
	png.Encode(&b, img)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(b.Bytes()) }))
	t.Cleanup(srv.Close)
	return srv.URL
}

func TestCoverColor(t *testing.T) {
	red := color.RGBA{200, 30, 30, 255}
	blue := color.RGBA{30, 60, 200, 255}
	grey := color.RGBA{120, 120, 120, 255}
	cases := []struct {
		name string
		fill func(x, y int) color.Color
		want string
	}{
		{"solid red", func(x, y int) color.Color { return red }, "#c81e1e"},
		{"grey gives its grey", func(x, y int) color.Color { return grey }, "#787878"},
		{"mostly blue with a red stripe", func(x, y int) color.Color {
			if x < 10 {
				return red
			}
			return blue
		}, "#1e3cc8"},
		{"vivid beats dark and grey", func(x, y int) color.Color {
			if x < 50 {
				return color.RGBA{10, 10, 10, 255}
			}
			return blue
		}, "#1e3cc8"},
	}
	for _, c := range cases {
		got, _, _, err := coverLook(serve(t, c.fill), 1000)
		if err != nil || got != c.want {
			t.Errorf("%s: got %q %v, want %q", c.name, got, err, c.want)
		}
	}
}

func TestCoverColorErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("not an image")) }))
	defer srv.Close()
	if _, _, _, err := coverLook(srv.URL, 1000); err == nil {
		t.Error("garbage decoded as an image")
	}
	if _, _, _, err := coverLook("http://127.0.0.1:1/none", 1000); err == nil {
		t.Error("unreachable server gave a colour")
	}
}

func TestFlow(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 64, 64))
	data, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(flow(src), "data:image/png;base64,"))
	if err != nil {
		t.Fatal(err)
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil || img.Bounds().Dx() != 32 {
		t.Fatalf("not a 32x32 png: %v", err)
	}
	// AMLL: black becomes a dark grey (contrast 0.4, 1.7, x0.75): 31.
	if r, _, _, _ := img.At(16, 16).RGBA(); r>>8 != 31 {
		t.Errorf("black gives %d, want 31", r>>8)
	}
}

func TestWash(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 64, 64))
	for y := 0; y < 64; y++ {
		for x := 0; x < 64; x++ {
			if x < 32 {
				src.Set(x, y, color.RGBA{220, 40, 40, 255})
			} else {
				src.Set(x, y, color.RGBA{40, 60, 220, 255})
			}
		}
	}
	w := wash(src, 1000)
	data, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(w, "data:image/png;base64,"))
	if err != nil {
		t.Fatal(err)
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil || img.Bounds().Dx() != 128 || img.Bounds().Dy() != 128 {
		t.Fatalf("not a 128x128 png: %v", err)
	}
	// Left red, right blue.
	lr, _, lb, _ := img.At(16, 64).RGBA()
	rr, _, rb, _ := img.At(112, 64).RGBA()
	if lr <= lb || rb <= rr {
		t.Errorf("left %d/%d right %d/%d", lr, lb, rr, rb)
	}
}

func TestHSV(t *testing.T) {
	cases := []struct{ r, g, b, h, s, v float64 }{
		{1, 0, 0, 0, 1, 1},
		{0, 1, 0, 1.0 / 3, 1, 1},
		{0, 0, 1, 2.0 / 3, 1, 1},
		{0.5, 0.5, 0.5, 0, 0, 0.5},
		{0, 0, 0, 0, 0, 0},
		{1, 0, 1, 5.0 / 6, 1, 1},
	}
	for _, c := range cases {
		h, s, v := hsv(c.r, c.g, c.b)
		if abs(h-c.h) > 1e-9 || abs(s-c.s) > 1e-9 || abs(v-c.v) > 1e-9 {
			t.Errorf("hsv(%v,%v,%v) = %v,%v,%v want %v,%v,%v", c.r, c.g, c.b, h, s, v, c.h, c.s, c.v)
		}
	}
}

func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}

func TestMetadata(t *testing.T) {
	m := metadata(&track{ID: "al-12/3.x", Title: "Blink", Artist: "Hiroshi Yoshimura", Album: "Green", Length: 245000000}, nil)
	if p := m["mpris:trackid"].Value().(dbus.ObjectPath); !p.IsValid() || !strings.HasSuffix(string(p), "tal_12_3_x") {
		t.Errorf("track id %q is not a valid D-Bus path", p)
	}
	if m["xesam:artist"].Value().([]string)[0] != "Hiroshi Yoshimura" || m["mpris:length"].Value().(int64) != 245000000 {
		t.Errorf("bad metadata %v", m)
	}
	if _, ok := m["mpris:artUrl"]; ok {
		t.Error("artUrl set without art")
	}
	if metadata(&track{ID: "1", Art: "http://x/c"}, nil)["mpris:artUrl"].Value() != "http://x/c" {
		t.Error("artUrl missing")
	}
	// Nothing played yet in this run: only the last albums' covers (qt-runner's idle cover).
	idle := metadata(nil, []string{"http://x/a", "http://x/b"})
	if len(idle) != 1 || idle["qtrunner:recentArtUrls"].Value().([]string)[1] != "http://x/b" {
		t.Errorf("idle metadata %v", idle)
	}
	if _, ok := m["qtrunner:recentArtUrls"]; ok {
		t.Error("recent covers without any")
	}
}

// QML reports its state as JSON; check it decodes the way mpris.update expects.
func TestPlayerStateJSON(t *testing.T) {
	var s playerState
	msg := `{"status":"Playing","position":1500000,"volume":0.8,"seeked":true,"track":{"id":"s0","title":"Blink","length":245000000},"nonce":0.3}`
	if err := json.Unmarshal([]byte(msg), &s); err != nil {
		t.Fatal(err)
	}
	if s.Status != "Playing" || s.Position != 1500000 || !s.Seeked || s.Track == nil || s.Track.Length != 245000000 {
		t.Errorf("decoded %+v", s)
	}
}

func TestIntrospectionNamesSeek(t *testing.T) {
	names := map[string]bool{}
	for _, m := range playerMethods(&mpris{}) {
		names[m.Name] = true
	}
	for _, want := range []string{"Next", "Previous", "Pause", "PlayPause", "Stop", "Play", "Seek", "SetPosition", "OpenUri"} {
		if !names[want] {
			t.Errorf("MPRIS method %s missing from introspection", want)
		}
	}
	if names["SeekBy"] {
		t.Error("SeekBy leaked into introspection")
	}
}

// The flow mesh (flow.vert) must never fold over itself: a fold shows as a hard arc.
func TestFlowMeshDoesNotFold(t *testing.T) {
	src, err := os.ReadFile("../qml/flow.vert")
	if err != nil {
		t.Fatal(err)
	}
	arr := func(name string) [25][2]float64 {
		var out [25][2]float64
		block := regexp.MustCompile(`(?s)const vec2 ` + name + `\[25\] = vec2\[25\]\((.*?)\);`).FindSubmatch(src)
		if block == nil {
			t.Fatal("no array", name)
		}
		pairs := regexp.MustCompile(`vec2\(([-0-9.e]+), ([-0-9.e]+)\)`).FindAllSubmatch(block[1], -1)
		if len(pairs) != 25 {
			t.Fatal(name, "has", len(pairs), "points")
		}
		for i, p := range pairs {
			out[i][0], _ = strconv.ParseFloat(string(p[1]), 64)
			out[i][1], _ = strconv.ParseFloat(string(p[2]), 64)
		}
		return out
	}
	P, U, V := arr("P"), arr("U"), arr("V")
	h := func(s float64) [4]float64 {
		return [4]float64{2*s*s*s - 3*s*s + 1, -2*s*s*s + 3*s*s, s*s*s - 2*s*s + s, s*s*s - s*s}
	}
	pos := func(x, y float64) [2]float64 { // as flow.vert
		cx, cy := math.Min(math.Floor(x*4), 3), math.Min(math.Floor(y*4), 3)
		a, b := h(x*4-cx), h(y*4-cy)
		i := int(cy)*5 + int(cx)
		var p [2]float64
		for k := range p {
			p[k] = a[0]*(b[0]*P[i][k]+b[1]*P[i+5][k]+b[2]*V[i][k]+b[3]*V[i+5][k]) +
				a[1]*(b[0]*P[i+1][k]+b[1]*P[i+6][k]+b[2]*V[i+1][k]+b[3]*V[i+6][k]) +
				a[2]*(b[0]*U[i][k]+b[1]*U[i+5][k]) + a[3]*(b[0]*U[i+1][k]+b[1]*U[i+6][k])
		}
		return p
	}
	const n = 400
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			p, px, py := pos(float64(x)/n, float64(y)/n), pos(float64(x+1)/n, float64(y)/n), pos(float64(x)/n, float64(y+1)/n)
			if (px[0]-p[0])*(py[1]-p[1])-(px[1]-p[1])*(py[0]-p[0]) <= 0 {
				t.Fatalf("the mesh folds at (%.3f, %.3f)", float64(x)/n, float64(y)/n)
			}
		}
	}
}

// Sailfish OS's Qt (Chum, 6.8; 6.7 elsewhere) lacks newer QML: no RectangularShadow (6.9, use
// Shadow.qml), and retainWhileLoading (6.8) only through a Binding that checks for it.
func TestQMLRunsOnQt67(t *testing.T) {
	files, _ := filepath.Glob("../qml/*.qml")
	// Qt 6.9 types and properties, and property names older parsers reserve (Java's words:
	// "property bool long" fails with "Expected token `identifier'").
	newer := regexp.MustCompile(`^\s*RectangularShadow\b|^\s*retainWhileLoading\s*:|property\s+\S+\s+(abstract|boolean|byte|char|double|enum|final|float|goto|implements|int|interface|long|native|package|private|protected|public|short|static|synchronized|throws|transient|volatile)\s*([:;]|$)`)
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		for i, line := range strings.Split(string(b), "\n") {
			if newer.MatchString(line) {
				t.Errorf("%s:%d needs a Qt newer than 6.7: %s", f, i+1, strings.TrimSpace(line))
			}
		}
	}
}

// The QML folder: the first with a Main.qml; none, "".
func TestQmlDir(t *testing.T) {
	empty, full := t.TempDir(), t.TempDir()
	os.WriteFile(filepath.Join(full, "Main.qml"), nil, 0o644)
	if d := qmlDir("", empty, full); d != full {
		t.Error(d)
	}
	if d := qmlDir(empty); d != "" {
		t.Error(d)
	}
}

// No QML handler on a signal of Qt's render thread: with the threaded render loop (the
// phone's), its JavaScript runs off the GUI thread and the app crashes (frameSwapped did).
func TestQMLNoRenderThreadHandlers(t *testing.T) {
	files, _ := filepath.Glob("../qml/*.qml")
	bad := regexp.MustCompile(`\bon(FrameSwapped|BeforeRendering|AfterRendering|BeforeRenderPassRecording|AfterRenderPassRecording|BeforeSynchronizing|AfterSynchronizing|BeforeFrameBegin|AfterFrameEnd|SceneGraphInitialized|SceneGraphInvalidated)\s*:`)
	for _, f := range files {
		b, _ := os.ReadFile(f)
		for i, line := range strings.Split(string(b), "\n") {
			if bad.MatchString(line) {
				t.Errorf("%s:%d handles a render-thread signal: %s", f, i+1, strings.TrimSpace(line))
			}
		}
	}
}
