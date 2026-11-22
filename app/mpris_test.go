package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// privateBus starts a session bus of its own for the test (TCP, anonymous: it works in a
// sandbox without unix sockets) and points the program at it.
func privateBus(t *testing.T) *dbus.Conn {
	if _, err := exec.LookPath("dbus-daemon"); err != nil {
		t.Skip("no dbus-daemon")
	}
	conf := filepath.Join(t.TempDir(), "bus.conf")
	os.WriteFile(conf, []byte(`<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><type>session</type><listen>tcp:host=127.0.0.1,bind=127.0.0.1,port=0</listen>
<auth>ANONYMOUS</auth><allow_anonymous/>
<policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>`), 0o644)
	daemon := exec.Command("dbus-daemon", "--config-file="+conf, "--print-address=1", "--nofork")
	out, _ := daemon.StdoutPipe()
	if err := daemon.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { daemon.Process.Kill(); daemon.Wait() })
	line, _ := bufio.NewReader(out).ReadString('\n')
	addr := strings.TrimSpace(line)
	t.Log(addr)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", addr)
	c, err := dbus.Connect(addr, dbus.WithAuth(dbus.AuthAnonymous()))
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// What a media widget (Noctalia, Sailfish's lock screen) reads while a song plays, and the
// buttons it (and a headset, through it) sends.
func TestMPRISOnTheBus(t *testing.T) {
	client := privateBus(t)
	sent := make(chan map[string]any, 8)
	m, err := newMpris(anonymous(t), func(c map[string]any) { sent <- c })
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	client.BusObject().Call("org.freedesktop.DBus.ListNames", 0).Store(&names)
	if !strings.Contains(strings.Join(names, " "), busName) {
		t.Fatal("not on the bus:", names)
	}

	// The state as Player.qml's report() sends it, a track starting.
	var s playerState
	msg := `{"status":"Playing","position":12000000,"volume":0.8,"seeked":false,"nonce":0.5,
		"track":{"id":"s-0","title":"布団","artist":"打首獄門同好会","album":"冬盤","art":"http://h/rest/getCoverArt?id=c","length":251000000}}`
	if err := json.Unmarshal([]byte(msg), &s); err != nil {
		t.Fatal(err)
	}
	m.update(s)

	player := client.Object(busName, objPath)
	get := func(name string) dbus.Variant {
		v, err := player.GetProperty(playerIface + "." + name)
		if err != nil {
			t.Fatal(name, err)
		}
		return v
	}
	if st := get("PlaybackStatus").Value(); st != "Playing" {
		t.Error("status", st)
	}
	meta := get("Metadata").Value().(map[string]dbus.Variant)
	if meta["xesam:title"].Value() != "布団" || meta["xesam:artist"].Value().([]string)[0] != "打首獄門同好会" ||
		meta["mpris:length"].Value() != int64(251000000) || meta["mpris:artUrl"].Value() == nil {
		t.Error("metadata", meta)
	}
	if p := get("Position").Value(); p != int64(12000000) {
		t.Error("position", p)
	}

	// Paused, the volume at 0 (left as it was), a seek: the Seeked signal.
	if err := client.AddMatchSignal(dbus.WithMatchInterface(playerIface)); err != nil {
		t.Fatal(err)
	}
	seeked := make(chan *dbus.Signal, 4)
	client.Signal(seeked)
	m.update(playerState{Status: "Paused", Position: 5, Seeked: true})
	m.update(playerState{Status: "Paused", Position: 5})
	if st := get("PlaybackStatus").Value(); st != "Paused" {
		t.Error("status", st)
	}
	if v := get("Volume").Value(); v != 0.8 {
		t.Error("volume", v)
	}
	select {
	case s := <-seeked:
		if s.Name != playerIface+".Seeked" || s.Body[0] != int64(5) {
			t.Error("seeked", s)
		}
	case <-time.After(2 * time.Second):
		t.Error("no Seeked")
	}

	expect := func(what string, want map[string]any) {
		select {
		case c := <-sent:
			if fmt.Sprint(c) != fmt.Sprint(want) {
				t.Errorf("%s sent %v, want %v", what, c, want)
			}
		case <-time.After(2 * time.Second):
			t.Errorf("%s sent nothing", what)
		}
	}
	for method, cmd := range map[string]string{"PlayPause": "playPause", "Next": "next", "Previous": "previous", "Pause": "pause", "Play": "play", "Stop": "stop"} {
		if err := player.Call(playerIface+"."+method, 0).Err; err != nil {
			t.Fatal(method, err)
		}
		expect(method, map[string]any{"cmd": cmd})
	}
	for method, cmd := range map[string]string{"Raise": "raise", "Quit": "quit"} {
		if err := player.Call(rootIface+"."+method, 0).Err; err != nil {
			t.Fatal(method, err)
		}
		expect(method, map[string]any{"cmd": cmd})
	}
	must(0, player.Call(playerIface+".Seek", 0, int64(-5000000)).Err)
	expect("Seek", map[string]any{"cmd": "seek", "offset": int64(-5000000)})
	must(0, player.Call(playerIface+".SetPosition", 0, dbus.ObjectPath("/org/ryugin/track/s0"), int64(7)).Err)
	expect("SetPosition", map[string]any{"cmd": "setPosition", "position": int64(7)})
	must(0, player.SetProperty(playerIface+".Volume", dbus.MakeVariant(0.5)))
	expect("Volume", map[string]any{"cmd": "volume", "value": 0.5})
	must(0, player.Call(playerIface+".OpenUri", 0, "file:///x.flac").Err)
	select {
	case c := <-sent:
		t.Error("OpenUri sent", c)
	case <-time.After(200 * time.Millisecond):
	}

	// The name refused (here: the connection gone): no player.
	gone := anonymous(t)
	gone.Close()
	if _, err := newMpris(gone, func(map[string]any) {}); err == nil {
		t.Error("a player without its name")
	}
}

// anonymous is a new connection to the test's bus.
func anonymous(t *testing.T) *dbus.Conn {
	c, err := dbus.Connect(os.Getenv("DBUS_SESSION_BUS_ADDRESS"), dbus.WithAuth(dbus.AuthAnonymous()))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return c
}

// The real program on a bus of its own, against the mock Navidrome (tests/run.sh sets
// RYUGIN_BIN and runs the mock): Play over MPRIS, with nothing queued, starts random songs,
// and their metadata reaches the bus from QML through Go.
func TestProgramOnTheBus(t *testing.T) {
	bin := os.Getenv("RYUGIN_BIN")
	if bin == "" {
		t.Skip("RYUGIN_BIN not set (tests/run.sh sets it)")
	}
	client := privateBus(t)
	// Like Sailfish's lock screen (Amber MPRIS): read everything the moment the name
	// appears; a failure then hides the player for good.
	if err := client.AddMatchSignal(dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged"), dbus.WithMatchArg(0, busName)); err != nil {
		t.Fatal(err)
	}
	signals := make(chan *dbus.Signal, 4)
	client.Signal(signals)
	readAtOnce := make(chan error, 1)
	go func() {
		<-signals
		obj := client.Object(busName, objPath)
		var props map[string]dbus.Variant
		err := obj.Call("org.freedesktop.DBus.Properties.GetAll", 0, rootIface).Store(&props)
		if err == nil {
			err = obj.Call("org.freedesktop.DBus.Properties.GetAll", 0, playerIface).Store(&props)
		}
		readAtOnce <- err
	}()
	app := exec.Command(bin)
	app.Env = append(os.Environ(), "QT_QPA_PLATFORM=offscreen", "RYUGIN_QML="+filepath.Join(must(os.Getwd()), "..", "qml"))
	if err := app.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stop(app) })

	player := client.Object(busName, objPath)
	waitFor := func(what string, ok func() bool) {
		for end := time.Now().Add(10 * time.Second); time.Now().Before(end); time.Sleep(200 * time.Millisecond) {
			if ok() {
				return
			}
		}
		t.Fatal("waited in vain for", what)
	}
	waitFor("the player on the bus", func() bool { _, err := player.GetProperty(rootIface + ".Identity"); return err == nil })
	select {
	case err := <-readAtOnce:
		if err != nil {
			t.Fatal("the name came before the player:", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no NameOwnerChanged")
	}
	// One player: a second copy shows the first and leaves.
	second := exec.Command(bin)
	second.Env = app.Env
	done := make(chan error, 1)
	if err := second.Start(); err != nil {
		t.Fatal(err)
	}
	go func() { done <- second.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal("the second copy:", err)
		}
	case <-time.After(10 * time.Second):
		second.Process.Kill()
		t.Fatal("a second copy kept running")
	}

	if err := player.Call(playerIface+".Play", 0).Err; err != nil {
		t.Fatal(err)
	}
	waitFor("a song's metadata", func() bool {
		v, err := player.GetProperty(playerIface + ".Metadata")
		if err != nil {
			return false
		}
		meta, _ := v.Value().(map[string]dbus.Variant)
		title, _ := meta["xesam:title"].Value().(string)
		return title != ""
	})
	time.Sleep(time.Second) // its cover's colours, from Go
}

// stop ends the program as a logout does (SIGTERM): it quits cleanly (and so a -cover
// build writes its counts).
func stop(app *exec.Cmd) {
	app.Process.Signal(syscall.SIGTERM)
	done := make(chan struct{})
	go func() { app.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		app.Process.Kill()
		<-done
	}
}

func must[T any](v T, err error) T {
	if err != nil {
		panic(err)
	}
	return v
}
