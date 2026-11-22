package main

import (
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/prop"
)

// A stand-in for qt-runner exports activeState (an int, as it declares it) and signals the
// change when it goes to the home screen; the app hears both.
func TestWatchActive(t *testing.T) {
	runner := privateBus(t)
	if _, err := prop.Export(runner, "/", prop.Map{containerIface: {"activeState": {Value: int32(1), Emit: prop.EmitFalse}}}); err != nil {
		t.Fatal(err)
	}
	if _, err := runner.RequestName(containerName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	app, err := dbus.Connect(os.Getenv("DBUS_SESSION_BUS_ADDRESS"), dbus.WithAuth(dbus.AuthAnonymous()))
	if err != nil {
		t.Fatal(err)
	}
	app.AddMatchSignal(dbus.WithMatchInterface(containerIface))
	got := make(chan bool, 4)
	go watchActive(app, func(c map[string]any) {
		if c["cmd"] == "active" {
			got <- c["on"].(bool)
		}
	})
	want := func(v bool) {
		select {
		case on := <-got:
			if on != v {
				t.Fatalf("active %v, want %v", on, v)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("no state")
		}
	}
	want(true)
	runner.Emit("/", containerIface+".activeStateChanged", false)
	want(false)
}

// qt-runner's bus: connected (no Hello), or an error for a bad address or a peer that
// does not speak D-Bus. A state of another type is false.
func TestContainerConn(t *testing.T) {
	privateBus(t)
	conn, err := containerConn(os.Getenv("DBUS_SESSION_BUS_ADDRESS"))
	if err != nil {
		t.Fatal(err)
	}
	conn.Close()
	if _, err := containerConn("unix:path=/nonexistent"); err == nil {
		t.Error("no bus, no error")
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()
	if _, err := containerConn("tcp:host=127.0.0.1,port=" + strconv.Itoa(ln.Addr().(*net.TCPAddr).Port)); err == nil {
		t.Error("no D-Bus, no error")
	}
	if truthy("1") || !truthy(int32(1)) || truthy(int32(0)) {
		t.Error("truthy")
	}
}

// The real program as on Sailfish OS (tests/run.sh sets RYUGIN_BIN): under qt-runner, on a
// dense screen (it restarts itself scaled), told by qt-runner's bus when it is in front;
// a bad bus address is only logged, in its log file (the last run's kept).
func TestProgramOnSailfish(t *testing.T) {
	bin := os.Getenv("RYUGIN_BIN")
	if bin == "" {
		t.Skip("RYUGIN_BIN not set (tests/run.sh sets it)")
	}
	client := privateBus(t)
	if _, err := prop.Export(client, "/", prop.Map{containerIface: {"activeState": {Value: true, Emit: prop.EmitFalse}}}); err != nil {
		t.Fatal(err)
	}
	if _, err := client.RequestName(containerName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	// qt-runner: the parent's name is all the program looks at.
	runner := filepath.Join(t.TempDir(), "qt-runner")
	os.WriteFile(runner, []byte("#!/bin/sh\n\"$@\"\nexit $?\n"), 0o755)
	cache := t.TempDir()
	log := filepath.Join(cache, "ryugin", "ryugin.log")
	for _, bus := range []string{os.Getenv("DBUS_SESSION_BUS_ADDRESS"), "unix:path=/nonexistent"} {
		app := exec.Command(runner, bin)
		app.Env = append(os.Environ(), "QT_QPA_PLATFORM=offscreen", "RYUGIN_DPI=320", "FLATPAK_MALIIT_CONTAINER_DBUS="+bus, "XDG_CACHE_HOME="+cache,
			"RYUGIN_QML="+filepath.Join(must(os.Getwd()), "..", "qml"))
		if err := app.Start(); err != nil {
			t.Fatal(err)
		}
		player := client.Object(busName, objPath)
		for end := time.Now().Add(10 * time.Second); time.Now().Before(end); time.Sleep(200 * time.Millisecond) {
			if _, err := player.GetProperty(rootIface + ".Identity"); err == nil {
				break
			}
		}
		if !strings.HasPrefix(bus, "unix:") {
			secondCopy(t, client, runner, bin)
		}
		client.Emit("/", containerIface+".activeStateChanged", false)
		time.Sleep(500 * time.Millisecond)
		// The shell passes SIGTERM on only once it has waited: signal the program itself.
		exec.Command("pkill", "-TERM", "-P", strconv.Itoa(app.Process.Pid)).Run()
		app.Wait()
		out, _ := os.ReadFile(log)
		if strings.HasPrefix(bus, "unix:") && !strings.Contains(string(out), "qt-runner bus:") {
			t.Error("a bad qt-runner bus is not logged in its file:", string(out))
		}
	}
	if _, err := os.Stat(log + ".old"); err != nil {
		t.Error("the last run's log is not kept")
	}
}

type qtRunnerObj struct{ activated chan bool }

func (q qtRunnerObj) Activate() *dbus.Error { q.activated <- true; return nil }

// secondCopy starts the program again under its own qt-runner: it brings the first one's
// qt-runner to the front (org.sailfishos.qtrunner activate) and ends its own, an empty window.
func secondCopy(t *testing.T, client *dbus.Conn, runner, bin string) {
	exe, _ := filepath.EvalSymlinks(bin)
	q := qtRunnerObj{make(chan bool, 1)}
	_ = client.ExportMethodTable(map[string]any{"activate": q.Activate}, "/", "org.sailfishos.qtrunner")
	name := "org.sailfishos.qtrunner.p" + notPath.ReplaceAllString(exe, "_")
	if _, err := client.RequestName(name, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	second := exec.Command(runner, bin)
	second.Env = append(os.Environ(), "QT_QPA_PLATFORM=offscreen")
	if err := second.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- second.Wait() }()
	select {
	case err := <-done:
		if err == nil {
			t.Error("the second copy's qt-runner was not ended")
		}
	case <-time.After(10 * time.Second):
		second.Process.Kill()
		t.Error("the second copy's qt-runner still runs")
	}
	select {
	case <-q.activated:
	case <-time.After(2 * time.Second):
		t.Error("the first copy's qt-runner was not brought to the front")
	}
}
