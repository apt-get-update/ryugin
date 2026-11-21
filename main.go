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
	"os/signal"
	"path/filepath"
	"runtime/coverage"
	"strconv"
	"strings"
	"syscall"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
	"github.com/mappu/miqt/qt6/qml"
)

const appID = "ryugin"

// version is set by the build: -ldflags "-X main.version=1.0.0".
var version = "dev"

// qmlDir is the first of dirs with a Main.qml, or "".
func qmlDir(dirs ...string) string {
	for _, dir := range dirs {
		if _, err := os.Stat(filepath.Join(dir, "Main.qml")); dir != "" && err == nil {
			return dir
		}
	}
	return ""
}

// phoneScale restarts the program with Qt scaling the UI to about 160 dpi, the size it is
// drawn for, on a dense screen whose compositor gives no scale (a phone running Sailfish
// OS's qt-runner). QT_SCALE_FACTOR, when set, wins; RYUGIN_DPI, when set, is the screen's dpi.
func phoneScale() {
	s := qt.QGuiApplication_PrimaryScreen()
	dpi, err := strconv.ParseFloat(os.Getenv("RYUGIN_DPI"), 64)
	if err != nil && s != nil {
		dpi = s.PhysicalDotsPerInch()
	}
	if os.Getenv("QT_SCALE_FACTOR") != "" || s == nil || s.DevicePixelRatio() != 1 || dpi < 200 {
		return
	}
	os.Setenv("QT_SCALE_FACTOR", fmt.Sprintf("%.2f", dpi/160))
	_ = coverage.WriteCountersDir(os.Getenv("GOCOVERDIR")) // tests/run.sh: exec skips the exit that writes them
	log.Println("phone scale:", syscall.Exec("/proc/self/exe", os.Args, os.Environ()))
}

// underQtRunner is true on Sailfish OS, whose qt-runner shows the app, and sets Qt up for
// it: wl-shell, all its small compositor offers (Qt 6 tries xdg-shell otherwise).
func underQtRunner() bool {
	comm, _ := os.ReadFile(fmt.Sprintf("/proc/%d/comm", os.Getppid()))
	if strings.TrimSpace(string(comm)) != "qt-runner" {
		return false
	}
	if os.Getenv("QT_WAYLAND_SHELL_INTEGRATION") == "" {
		os.Setenv("QT_WAYLAND_SHELL_INTEGRATION", "wl-shell")
	}
	// Qt writes to the journal when stderr is no terminal, and Sailfish OS drops QML's
	// console.log there: to stderr (ryugin.log, logFile), console.log included.
	os.Setenv("QT_FORCE_STDERR_LOGGING", "1")
	if os.Getenv("QT_LOGGING_RULES") == "" {
		os.Setenv("QT_LOGGING_RULES", "qml.debug=true")
	}
	// GStreamer, as Chum's qt6-start.sh sets for its Qt 6 apps: FFmpeg's sound came slow and
	// distorted on the phone's speaker.
	if os.Getenv("QT_MEDIA_BACKEND") == "" {
		os.Setenv("QT_MEDIA_BACKEND", "gstreamer")
	}
	// qt-runner gives few frames: Qt's animations step one vsync per frame and crawl
	// (a 0.6 s fade took seconds). Wall-clock steps keep them on time.
	os.Setenv("QSG_USE_SIMPLE_ANIMATION_DRIVER", "1")
	// Waiting for qt-runner's frame callbacks paces frames 8-28 ms apart (judder): draw
	// without waiting, qt-runner shows the newest frame (tried on the phone: smoother).
	os.Setenv("QSG_NO_VSYNC", "1")
	return true
}

// logFile sends stderr (Qt, FFmpeg, Go, a crash's trace) to ~/.cache/ryugin/ryugin.log, the
// last run's kept as ryugin.log.old: Sailfish OS's journal keeps only a few minutes.
func logFile() {
	cache, _ := os.UserCacheDir()
	p := filepath.Join(cache, appID, appID+".log")
	os.MkdirAll(filepath.Dir(p), 0o755)
	os.Rename(p, p+".old")
	if f, err := os.Create(p); err == nil {
		_ = syscall.Dup3(int(f.Fd()), 2, 0) // failed: stderr as it was
	}
}

func main() {
	sailfish := underQtRunner()
	if running(sailfish) {
		return
	}
	startQt()
	if sailfish {
		logFile()
	}
	log.Println("start, pid", os.Getpid())
	// $RYUGIN_QML, next to the binary, or the installed copy.
	exe, _ := os.Executable()
	dir := qmlDir(os.Getenv("RYUGIN_QML"), filepath.Join(filepath.Dir(exe), "qml"), "/usr/share/"+appID+"/qml")
	root, bridge := loadQML(dir, sailfish)
	send := sender(root)

	_, hasTray := newTray(dir, send)
	root.SetProperty("hasTray", qt.NewQVariant8(hasTray))
	newMenuBar(send)
	if addr := os.Getenv("FLATPAK_MALIIT_CONTAINER_DBUS"); sailfish && addr != "" {
		watchContainer(addr, send)
	}
	bridge.OnObjectNameChanged(fromQML(startMpris(send), send))

	// SIGTERM (a logout, tests/run.sh) quits cleanly.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, os.Interrupt)
	go func() { log.Println("quit:", <-quit); mainthread.Start(qt.QCoreApplication_Quit) }()

	qt.QGuiApplication_Exec()
	log.Println("exit")
}

// startQt makes the Qt application: names, 8 bits per colour, scaled on a phone.
func startQt() {
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
	qt.NewQApplication(os.Args) // widgets, for the tray icon
	phoneScale()
}

// loadQML loads dir/Main.qml with goBridge (and on Sailfish OS goStreamProxy) set, and
// returns its window and the bridge.
func loadQML(dir string, sailfish bool) (*qt.QObject, *qt.QObject) {
	engine := qml.NewQQmlApplicationEngine()
	bridge := qt.NewQObject()
	engine.RootContext().SetContextProperty("goBridge", bridge)
	if sailfish { // streams through Go (stream.go)
		if prefix, err := streamProxy(nil); err == nil {
			engine.RootContext().SetContextProperty2("goStreamProxy", qt.NewQVariant14(prefix))
		}
	}
	engine.LoadWithFilePath(filepath.Join(dir, "Main.qml"))
	roots := engine.RootObjects()
	if len(roots) == 0 {
		log.Fatal("QML failed to load (set RYUGIN_QML to the qml folder)")
	}
	return roots[0], bridge
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

// watchContainer tells QML when qt-runner is in front or not (Sailfish OS).
func watchContainer(addr string, send func(map[string]any)) {
	conn, err := containerConn(addr)
	if err != nil {
		fmt.Fprintln(os.Stderr, "qt-runner bus:", err)
		return
	}
	go watchActive(conn, send)
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

// fromQML handles what QML sends (QML -> Go): the player state for MPRIS, or a cover to
// take the colours from.
func fromQML(player *mpris, send func(map[string]any)) func(string) {
	return func(msg string) {
		var req struct {
			CoverURL string  `json:"coverUrl"`
			Side     float64 `json:"side"`
		}
		if json.Unmarshal([]byte(msg), &req) == nil && req.CoverURL != "" {
			go func() {
				if c, w, f, err := coverLook(req.CoverURL, req.Side); err == nil {
					send(map[string]any{"cmd": "coverColor", "color": c, "wash": w, "flow": f, "url": req.CoverURL})
				}
			}()
			return
		}
		var state playerState
		if json.Unmarshal([]byte(msg), &state) == nil && player != nil {
			player.update(state)
		}
	}
}
