// Ryūgin: a Navidrome player. The UI, the Subsonic calls and playback are
// QML (qml/); Go starts it and serves MPRIS (mpris.go) so media keys and shell widgets work.
//
// Bridge: QML sends JSON to Go by setting goBridge.objectName; Go sends JSON to QML by
// setting the root window's goCommand property.
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
	"github.com/mappu/miqt/qt6/qml"
)

const appID = "ryugin"

// version is set by the build: -ldflags "-X main.version=1.0.0".
var version = "dev"

// qmlDir is the first of dirs that holds the file main (Main.qml, Keel's ryugin.qml), or "".
func qmlDir(main string, dirs ...string) string {
	for _, dir := range dirs {
		if _, err := os.Stat(filepath.Join(dir, main)); dir != "" && err == nil {
			return dir
		}
	}
	return ""
}

// startQt makes the Qt application: names, 8 bits per colour.
func startQt() {
	qtSetup()
	qt.NewQApplication(os.Args) // widgets, for the tray icon
}

// qtSetup sets what Qt needs before its application: names, 8 bits per colour.
func qtSetup() {
	qt.QCoreApplication_SetOrganizationName(appID)
	qt.QCoreApplication_SetApplicationName(appID)
	qt.QCoreApplication_SetApplicationVersion(version)
	qt.QGuiApplication_SetDesktopFileName(appID)
	// 8 bits per colour: left unset, EGL may give a 16-bit (RGB565) window, and every
	// gradient (the backdrop above all) shows bands.
	f := qt.NewQSurfaceFormat()
	f.SetRedBufferSize(8)
	f.SetGreenBufferSize(8)
	f.SetBlueBufferSize(8)
	f.SetAlphaBufferSize(8)
	qt.QSurfaceFormat_SetDefaultFormat(f)
}

// loadQML loads dir/Main.qml with goBridge and goStreamProxy set, and returns its window
// and the bridge.
func loadQML(dir string) (*qt.QObject, *qt.QObject) {
	engine := qml.NewQQmlApplicationEngine()
	bridge := setContext(engine.RootContext())
	engine.LoadWithFilePath(filepath.Join(dir, "Main.qml"))
	roots := engine.RootObjects()
	if len(roots) == 0 {
		log.Fatal("QML failed to load (set RYUGIN_QML to the qml folder)")
	}
	return roots[0], bridge
}

// setContext gives QML goBridge and goStreamProxy, and returns the bridge.
func setContext(ctx *qml.QQmlContext) *qt.QObject {
	bridge := qt.NewQObject()
	ctx.SetContextProperty("goBridge", bridge)
	// Streams through Go (stream.go): Sailfish OS's https, and the song cache.
	cache, _ := os.UserCacheDir()
	if prefix, err := streamProxy(nil, filepath.Join(cache, appID)); err == nil {
		ctx.SetContextProperty2("goStreamProxy", qt.NewQVariant14(prefix))
	}
	return bridge
}

// sender sends QML a command (Go -> QML), from any goroutine.
func sender(root *qt.QObject) func(map[string]any) {
	n := 0
	return func(cmd map[string]any) {
		mainthread.Start(func() {
			n++
			cmd["n"] = n // a new value each time, so QML always sees a change
			data, _ := json.Marshal(cmd)
			root.SetProperty("goCommand", qt.NewQVariant14(string(data)))
		})
	}
}

// startMpris puts the player on the session bus, or returns nil (and says why).
func startMpris(send func(map[string]any)) *mpris {
	conn, err := sessionBus()
	var player *mpris
	if err == nil {
		player, err = newMpris(conn, send)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "mpris:", err)
	}
	return player
}

// fromQML handles what QML sends (QML -> Go): the player state for MPRIS, the way the app
// faces for the keyboard, or a cover to
// take the colours from.
func fromQML(player *mpris, send func(map[string]any)) func(string) {
	return func(msg string) {
		var req struct {
			CoverURL string  `json:"coverUrl"`
			Side     float64 `json:"side"`
			Keyboard *struct {
				Angle  int32 `json:"angle"`
				Active bool  `json:"active"`
			} `json:"keyboard"`
		}
		if json.Unmarshal([]byte(msg), &req) == nil && req.Keyboard != nil {
			keyboard.set(req.Keyboard.Angle, req.Keyboard.Active)
			return
		}
		if req.CoverURL != "" {
			go func() {
				c, w, f, err := coverLook(req.CoverURL, req.Side)
				if err != nil {
					log.Println("cover colour:", err)
					return
				}
				send(map[string]any{"cmd": "coverColor", "color": c, "wash": w, "flow": f, "url": req.CoverURL})
			}()
			return
		}
		var state playerState
		if json.Unmarshal([]byte(msg), &state) == nil && player != nil {
			player.update(state)
		}
	}
}
