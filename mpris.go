// MPRIS (org.mpris.MediaPlayer2) on the session bus: playerctl, media keys and shell
// media widgets see and control the player.
package main

import (
	"os"
	"regexp"
	"sync"
	"syscall"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
	"github.com/godbus/dbus/v5/prop"
)

const (
	busName     = "org.mpris.MediaPlayer2." + "ryugin"
	objPath     = "/org/mpris/MediaPlayer2"
	rootIface   = "org.mpris.MediaPlayer2"
	playerIface = "org.mpris.MediaPlayer2.Player"
)

// playerState is what QML reports (times in microseconds).
type playerState struct {
	Status   string  `json:"status"` // Playing, Paused, Stopped
	Position int64   `json:"position"`
	Volume   float64 `json:"volume"`
	Seeked   bool    `json:"seeked"`
	Track    *track  `json:"track"`
	// The covers of the last albums played (with the track), for qt-runner's cover.
	RecentArt []string `json:"recentArt"`
	CanPlay   *bool    `json:"canPlay"` // false until connected to Navidrome
}

type track = struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Art    string `json:"art"`
	Length int64  `json:"length"`
}

// metadata is the MPRIS Metadata map for a track (nil: none yet), with the covers of the
// last albums played under qtrunner:recentArtUrls (qt-runner's cover on Sailfish OS shows
// them while nothing plays).
func metadata(t *track, recent []string) map[string]dbus.Variant {
	meta := map[string]dbus.Variant{}
	if len(recent) > 0 {
		meta["qtrunner:recentArtUrls"] = dbus.MakeVariant(recent)
	}
	if t == nil {
		return meta
	}
	meta["mpris:trackid"] = dbus.MakeVariant(dbus.ObjectPath("/org/ryugin/track/t" + notPath.ReplaceAllString(t.ID, "_")))
	meta["mpris:length"] = dbus.MakeVariant(t.Length)
	meta["xesam:title"] = dbus.MakeVariant(t.Title)
	meta["xesam:artist"] = dbus.MakeVariant([]string{t.Artist})
	meta["xesam:album"] = dbus.MakeVariant(t.Album)
	if t.Art != "" {
		meta["mpris:artUrl"] = dbus.MakeVariant(t.Art)
	}
	return meta
}

type mpris struct {
	conn   *dbus.Conn
	props  *prop.Properties
	send   func(map[string]any)
	track  *track   // the song, for Metadata
	recent []string // the last albums' covers, for Metadata
}

type rootObj struct{ m *mpris }
type playerObj struct{ m *mpris }

func (r rootObj) Raise() *dbus.Error {
	r.m.send(map[string]any{"cmd": "raise"})
	activateQtRunner(r.m.conn) // Sailfish OS: the lock screen's player shows the app
	return nil
}
func (r rootObj) Quit() *dbus.Error { r.m.send(map[string]any{"cmd": "quit"}); return nil }

func (p playerObj) cmd(name string) *dbus.Error {
	p.m.send(map[string]any{"cmd": name})
	return nil
}
func (p playerObj) Next() *dbus.Error      { return p.cmd("next") }
func (p playerObj) Previous() *dbus.Error  { return p.cmd("previous") }
func (p playerObj) Pause() *dbus.Error     { return p.cmd("pause") }
func (p playerObj) PlayPause() *dbus.Error { return p.cmd("playPause") }
func (p playerObj) Stop() *dbus.Error      { return p.cmd("stop") }
func (p playerObj) Play() *dbus.Error      { return p.cmd("play") }

// SeekBy is MPRIS Seek (exported under that name; Go's vet keeps "Seek" for io.Seeker).
func (p playerObj) SeekBy(offset int64) *dbus.Error {
	p.m.send(map[string]any{"cmd": "seek", "offset": offset})
	return nil
}
func (p playerObj) SetPosition(_ dbus.ObjectPath, position int64) *dbus.Error {
	p.m.send(map[string]any{"cmd": "setPosition", "position": position})
	return nil
}
func (p playerObj) OpenUri(string) *dbus.Error { return nil }

// sessionBus is the session bus, one connection for the program; anonymous when the bus
// allows only that (the tests' bus).
var sessionBus = sync.OnceValues(func() (*dbus.Conn, error) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		if c, err2 := dbus.Connect(os.Getenv("DBUS_SESSION_BUS_ADDRESS"), dbus.WithAuth(dbus.AuthAnonymous())); err2 == nil {
			return c, nil
		}
	}
	return conn, err
})

func newMpris(conn *dbus.Conn, send func(map[string]any)) (*mpris, error) {
	m := &mpris{conn: conn, send: send}
	ro := func(v any) *prop.Prop { return &prop.Prop{Value: v, Emit: prop.EmitTrue} }
	props := prop.Map{
		rootIface: {
			"CanQuit":             ro(true),
			"CanRaise":            ro(true),
			"HasTrackList":        ro(false),
			"Identity":            ro("Ryūgin"),
			"DesktopEntry":        ro(appID),
			"SupportedUriSchemes": ro([]string{}),
			"SupportedMimeTypes":  ro([]string{}),
		},
		playerIface: {
			"PlaybackStatus": ro("Stopped"),
			"LoopStatus":     ro("None"),
			"Rate":           ro(1.0),
			"Shuffle":        ro(false),
			"Metadata":       ro(map[string]dbus.Variant{}),
			"Volume": {Value: 1.0, Writable: true, Emit: prop.EmitTrue, Callback: func(c *prop.Change) *dbus.Error {
				m.send(map[string]any{"cmd": "volume", "value": c.Value})
				return nil
			}},
			"Position":      {Value: int64(0), Emit: prop.EmitFalse},
			"MinimumRate":   ro(1.0),
			"MaximumRate":   ro(1.0),
			"CanGoNext":     ro(true),
			"CanGoPrevious": ro(true),
			"CanPlay":       ro(true),
			"CanPause":      ro(true),
			"CanSeek":       ro(true),
			"CanControl":    ro(true),
		},
	}
	// Exports fail only on a bad object path: objPath is a good one.
	m.props, _ = prop.Export(conn, objPath, props)
	_ = conn.Export(rootObj{m}, objPath, rootIface)
	_ = conn.ExportWithMap(playerObj{m}, map[string]string{"SeekBy": "Seek"}, objPath, playerIface)
	node := &introspect.Node{Name: objPath, Interfaces: []introspect.Interface{
		introspect.IntrospectData,
		prop.IntrospectData,
		{Name: rootIface, Methods: introspect.Methods(rootObj{m}), Properties: m.props.Introspection(rootIface)},
		{Name: playerIface, Methods: playerMethods(m), Properties: m.props.Introspection(playerIface),
			Signals: []introspect.Signal{{Name: "Seeked", Args: []introspect.Arg{{Name: "Position", Type: "x"}}}}},
	}}
	_ = conn.Export(introspect.NewIntrospectable(node), objPath, "org.freedesktop.DBus.Introspectable")
	if _, err := conn.RequestName(busName, dbus.NameFlagDoNotQueue); err != nil {
		return nil, err
	}
	return m, nil
}

var notPath = regexp.MustCompile(`[^A-Za-z0-9_]`)

// activateQtRunner brings the window of the qt-runner that runs this program to the front
// (Sailfish OS; a qt-runner with org.sailfishos.qtrunner, else nothing happens).
func activateQtRunner(conn *dbus.Conn) {
	exe, _ := os.Executable()
	name := "org.sailfishos.qtrunner.p" + notPath.ReplaceAllString(exe, "_")
	conn.Object(name, "/").Go("org.sailfishos.qtrunner.activate", dbus.FlagNoReplyExpected|dbus.FlagNoAutoStart, nil)
}

func (m *mpris) update(s playerState) {
	if s.Status != "" {
		m.set("PlaybackStatus", s.Status)
	}
	if s.CanPlay != nil {
		m.set("CanPlay", *s.CanPlay)
	}
	m.props.SetMust(playerIface, "Position", s.Position)
	if s.Volume > 0 {
		m.set("Volume", s.Volume)
	}
	if s.Track != nil || s.RecentArt != nil { // QML sends them only when they change
		if s.Track != nil {
			m.track = s.Track
		}
		if s.RecentArt != nil {
			m.recent = s.RecentArt
		}
		m.props.SetMust(playerIface, "Metadata", metadata(m.track, m.recent))
	}
	if s.Seeked {
		_ = m.conn.Emit(objPath, playerIface+".Seeked", s.Position)
	}
}

// set changes a property only when it differs, so clients get no needless signals.
func (m *mpris) set(name string, value any) {
	if old, err := m.props.Get(playerIface, name); err == nil && old.Value() == value {
		return
	}
	m.props.SetMust(playerIface, name, value)
}

// playerMethods lists the player's methods for introspection, with SeekBy as Seek.
func playerMethods(m *mpris) []introspect.Method {
	methods := introspect.Methods(playerObj{m})
	for i := range methods {
		if methods[i].Name == "SeekBy" {
			methods[i].Name = "Seek"
		}
	}
	return methods
}

// running is true when a copy already runs: it is asked to show its window, and this one
// should exit (one player, one tray icon). It only asks: the name is taken by newMpris once
// the player is exported, as Sailfish's lock screen reads it the moment the name appears
// (and ignores a player it could not read then). Under qt-runner (sailfish), the first
// copy's qt-runner comes to the front and this one's, an empty window, is ended.
func running(sailfish bool) bool {
	conn, err := sessionBus()
	if err != nil {
		return false
	}
	var owned bool
	if conn.BusObject().Call("org.freedesktop.DBus.NameHasOwner", 0, busName).Store(&owned) != nil || !owned {
		return false
	}
	conn.Object(busName, objPath).Call(rootIface+".Raise", 0)
	if sailfish {
		activateQtRunner(conn)
		_ = syscall.Kill(os.Getppid(), syscall.SIGTERM)
	}
	return true
}
