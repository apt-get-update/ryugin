package main

import (
	"io"
	"net"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// The plugin's side: it connects, reads the state, reports the keyboard, hears the changes.
func TestContainer(t *testing.T) {
	if _, _, err := serveContainer(filepath.Join(t.TempDir(), "none")); err == nil {
		t.Fatal("served in a folder that is not there")
	}
	c, addr, err := serveContainer(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	conn, err := dbus.Dial(addr)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err := conn.Auth(nil); err != nil {
		t.Fatal(err)
	}
	signals := make(chan *dbus.Signal, 4)
	conn.Signal(signals)
	obj := conn.Object("org.flatpak.sailfish.container", "/")
	if err := obj.Call(containerIface+".keyboardRect", 0, true, int32(0), int32(0), int32(10), int32(10)).Err; err != nil {
		t.Fatal(err)
	}
	for i := 0; ; i++ { // the link is served once the call came back; its peer is listed after
		c.mu.Lock()
		n := len(c.peers)
		c.mu.Unlock()
		if n == 1 {
			break
		}
		if i > 100 {
			t.Fatal("no peer")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if v, err := obj.GetProperty(containerIface + ".activeState"); err != nil || v.Value() != int32(1) {
		t.Fatal(v, err)
	}
	keyboard = c
	defer func() { keyboard = nil }()
	fromQML(nil, nil)(`{"keyboard":{"angle":90,"active":false}}`) // QML's turn
	c.set(90, false)                                              // no change: no signal
	for _, want := range []string{"orientationChanged", "activeStateChanged"} {
		select {
		case s := <-signals:
			if s.Name != containerIface+"."+want {
				t.Fatal(s.Name)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("no", want)
		}
	}
	if v, err := obj.GetProperty(containerIface + ".orientation"); err != nil || v.Value() != int32(90) {
		t.Fatal(v, err)
	}
	select {
	case s := <-signals:
		t.Fatal("signal with no change:", s.Name)
	case <-time.After(100 * time.Millisecond):
	}
	var none *container
	none.set(0, true) // no link: nothing
}

// A connection that is not D-Bus is closed.
func TestContainerNotDBus(t *testing.T) {
	_, addr, err := serveContainer(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	nc, err := net.Dial("unix", strings.TrimPrefix(addr, "unix:path="))
	if err != nil {
		t.Fatal(err)
	}
	_, _ = nc.Write([]byte("GET / HTTP/1.1\r\n"))
	if _, err := nc.Read(make([]byte, 1)); err != io.EOF {
		t.Fatal(err)
	}
}

func TestAcceptAuth(t *testing.T) {
	for _, tc := range []struct {
		send, reply, rest string
		ok                bool
	}{
		{send: "x"},
		{send: "\x00"},
		{send: "\x00AUTH\r\n\r\nNEGOTIATE_UNIX_FD\r\nAUTH EXTERNAL 30\r\nBEGIN\r\nhello", reply: "REJECTED EXTERNAL\r\nERROR\r\nERROR\r\nOK ", rest: "hello", ok: true},
	} {
		srv, cli := net.Pipe()
		got := make(chan string)
		go func() {
			_, _ = cli.Write([]byte(tc.send))
			b, _ := io.ReadAll(cli)
			got <- string(b)
		}()
		go func() { // the plugin's side ends once all was answered
			time.Sleep(100 * time.Millisecond)
			_ = cli.Close()
		}()
		rest, err := acceptAuth(srv)
		_ = srv.Close()
		if (err == nil) != tc.ok || string(rest) != tc.rest || !strings.HasPrefix(<-got, tc.reply) {
			t.Fatal(tc.send, err, string(rest))
		}
	}
	// The plugin gone before the answer.
	srv, cli := net.Pipe()
	go func() { _, _ = cli.Write([]byte("\x00AUTH X\r\n")); _ = cli.Close() }()
	if _, err := acceptAuth(srv); err == nil {
		t.Fatal("answered a closed connection")
	}
}

// What the plugin sent with BEGIN is read before the connection.
func TestAuthedRest(t *testing.T) {
	srv, cli := net.Pipe()
	defer srv.Close()
	a := &authed{Conn: srv, script: strings.NewReader(""), rest: []byte("he")}
	go func() { _, _ = cli.Write([]byte("llo")) }()
	b := make([]byte, 8)
	n, _ := a.Read(b)
	m, _ := a.Read(b[n:])
	if string(b[:n+m]) != "hello" {
		t.Fatal(string(b[:n+m]))
	}
}
