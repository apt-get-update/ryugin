// qt-runner's own D-Bus (Sailfish OS): a private peer-to-peer bus it gives the app for the
// Maliit keyboard, at $FLATPAK_MALIIT_CONTAINER_DBUS. Its activeState says whether qt-runner
// is in front; when it is not, the home screen shows the app as a card.
package main

import (
	"log"
	"os"
	"strconv"

	"github.com/godbus/dbus/v5"
)

const (
	containerName  = "org.flatpak.sailfish.container"
	containerIface = "org.container"
)

// containerConn connects to qt-runner's bus (peer to peer: no Hello, no bus daemon), as
// this user (EXTERNAL), or anonymously where only that is allowed (the tests' bus).
func containerConn(addr string) (*dbus.Conn, error) {
	conn, err := dbus.Dial(addr)
	if err != nil {
		return nil, err
	}
	if err = conn.Auth([]dbus.Auth{dbus.AuthExternal(strconv.Itoa(os.Geteuid())), dbus.AuthAnonymous()}); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return conn, nil
}

// watchActive sends QML qt-runner's state ({"cmd": "active", "on": bool}) now and on each change.
func watchActive(conn *dbus.Conn, send func(map[string]any)) {
	active := func(on bool) {
		log.Println("qt-runner active:", on)
		send(map[string]any{"cmd": "active", "on": on})
	}
	signals := make(chan *dbus.Signal, 4)
	conn.Signal(signals)
	if v, err := conn.Object(containerName, "/").GetProperty(containerIface + ".activeState"); err == nil {
		active(truthy(v.Value()))
	}
	for s := range signals {
		if s.Name == containerIface+".activeStateChanged" && len(s.Body) == 1 {
			active(truthy(s.Body[0]))
		}
	}
}

// truthy reads the state, a bool or (as qt-runner declares the property) an int.
func truthy(v any) bool {
	switch v := v.(type) {
	case bool:
		return v
	case int32:
		return v != 0
	}
	return false
}
