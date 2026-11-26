// The keyboard's link (Sailfish OS): Sailfish's Qt 6 Maliit plugin asks the app's container
// which way the app's content faces and whether it is in front, on a private peer-to-peer
// D-Bus at $FLATPAK_MALIIT_CONTAINER_DBUS, and tells it the keyboard's area. Started
// directly (Keel), Ryūgin is its own container: it serves that link. Without one, the plugin
// crashed as the keyboard opened; with a dead one, the keyboard did not turn with the app.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
	"github.com/godbus/dbus/v5/prop"
)

const containerIface = "org.container" // the plugin's names (maliit-framework, sailfishos-flatpak fork)

// keyboard is the link served, nil while there is none (fromQML gives it the app's turn).
var keyboard *container

// container is the served state: the content's angle as Maliit counts it (0, 90, 180, 270)
// and whether the app is in front; every connected plugin hears its changes.
type container struct {
	mu     sync.Mutex
	angle  int32
	active bool
	peers  []peer
}

// peer is one connected plugin.
type peer struct {
	conn  *dbus.Conn
	props *prop.Properties
}

// serveContainer listens on a socket in dir and returns its D-Bus address.
func serveContainer(dir string) (*container, string, error) {
	path := filepath.Join(dir, fmt.Sprintf("ryugin-keyboard-%d", os.Getpid()))
	_ = os.Remove(path)
	l, err := net.Listen("unix", path)
	if err != nil {
		return nil, "", err
	}
	c := &container{active: true}
	go func() {
		for conn, err := l.Accept(); err == nil; conn, err = l.Accept() {
			go c.serve(conn)
		}
	}()
	return c, "unix:path=" + path, nil
}

// serve answers one plugin: D-Bus's handshake, then the object "/". godbus has no server
// side: it is given the handshake's client side as played (authed), which starts its reader.
func (c *container) serve(nc net.Conn) {
	rest, err := acceptAuth(nc)
	if err != nil {
		_ = nc.Close()
		return
	}
	conn, _ := dbus.NewConn(&authed{Conn: nc, script: strings.NewReader("REJECTED EXTERNAL\r\nOK 0\r\n"), rest: rest})
	_ = conn.ExportMethodTable(map[string]any{"keyboardRect": keyboardRect}, "/", containerIface)
	c.mu.Lock()
	defer c.mu.Unlock()
	p, _ := prop.Export(conn, "/", prop.Map{containerIface: {
		"activeState": {Value: boolInt(c.active), Emit: prop.EmitFalse},
		"orientation": {Value: c.angle, Emit: prop.EmitFalse},
	}})
	// Qt's D-Bus reads properties from the object's description only: without it, the
	// plugin read no state, took the app as not in front and dropped every turn.
	_ = conn.Export(introspect.NewIntrospectable(&introspect.Node{Interfaces: []introspect.Interface{
		introspect.IntrospectData, prop.IntrospectData, {
			Name: containerIface,
			Methods: []introspect.Method{{Name: "keyboardRect", Args: []introspect.Arg{
				{Type: "b", Direction: "in"}, {Type: "i", Direction: "in"}, {Type: "i", Direction: "in"},
				{Type: "i", Direction: "in"}, {Type: "i", Direction: "in"}}}},
			Signals: []introspect.Signal{
				{Name: "orientationChanged", Args: []introspect.Arg{{Type: "i"}}},
				{Name: "activeStateChanged", Args: []introspect.Arg{{Type: "b"}}}},
			Properties: p.Introspection(containerIface),
		}}}), "/", "org.freedesktop.DBus.Introspectable")
	// All is in place before the first call is read.
	_ = conn.Auth([]dbus.Auth{dbus.AuthExternal("0")}) // played from script: it can't fail
	log.Println("keyboard link: plugin connected")
	c.peers = append(c.peers, peer{conn, p})
}

// keyboardRect is the plugin's report of the keyboard's area: Silica lays out by Qt's own.
func keyboardRect(active bool, x, y, w, h int32) *dbus.Error { return nil }

// set changes the state and signals it, as the plugin listens for (not PropertiesChanged).
func (c *container) set(angle int32, active bool) {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, p := range c.peers {
		if angle != c.angle {
			p.props.SetMust(containerIface, "orientation", angle)
			_ = p.conn.Emit("/", containerIface+".orientationChanged", angle)
		}
		if active != c.active {
			p.props.SetMust(containerIface, "activeState", boolInt(active))
			_ = p.conn.Emit("/", containerIface+".activeStateChanged", active)
		}
	}
	c.angle, c.active = angle, active
}

func boolInt(b bool) int32 {
	if b {
		return 1
	}
	return 0
}

// acceptAuth is the server's side of D-Bus's handshake: a NUL byte, then AUTH (any
// mechanism: the socket is the user's own) answered OK, no Unix fds, until BEGIN. It returns
// what the plugin sent after BEGIN, read with it.
func acceptAuth(nc net.Conn) ([]byte, error) {
	r := bufio.NewReader(nc)
	if b, err := r.ReadByte(); err != nil || b != 0 {
		return nil, fmt.Errorf("no handshake")
	}
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return nil, err
		}
		reply := authReply(line)
		if reply == "" {
			return r.Peek(r.Buffered())
		}
		if _, err := io.WriteString(nc, reply); err != nil {
			return nil, err
		}
	}
}

// authReply is the answer to one line of the handshake, "" for BEGIN.
func authReply(line string) string {
	switch cmd := strings.Fields(line); {
	case len(cmd) == 1 && cmd[0] == "AUTH": // which mechanisms?
		return "REJECTED EXTERNAL\r\n"
	case len(cmd) > 1 && cmd[0] == "AUTH":
		return fmt.Sprintf("OK %032x\r\n", os.Getpid())
	case len(cmd) > 0 && cmd[0] == "BEGIN":
		return ""
	}
	return "ERROR\r\n" // NEGOTIATE_UNIX_FD, DATA...
}

// authed is the connection as godbus's client handshake sees it: the server's lines from
// script, its own lines dropped up to BEGIN; then what the plugin sent after BEGIN, then
// the connection.
type authed struct {
	net.Conn
	script io.Reader
	rest   []byte
	begun  bool
}

func (a *authed) Read(p []byte) (int, error) {
	if n, _ := a.script.Read(p); n > 0 {
		return n, nil
	}
	if len(a.rest) > 0 {
		n := copy(p, a.rest)
		a.rest = a.rest[n:]
		return n, nil
	}
	return a.Conn.Read(p)
}

func (a *authed) Write(p []byte) (int, error) {
	if !a.begun {
		a.begun = bytes.Contains(p, []byte("BEGIN"))
		return len(p), nil
	}
	return a.Conn.Write(p)
}
