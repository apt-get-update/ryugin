//go:build silica

// Sailfish OS with Keel (Silica on Qt 6): a native Silica UI (qml-sailfish/), started by
// Keel's SailfishApp in direct mode. The desktop's main is main_desktop.go.
// Keel's headers and library are in .keel/, fetched by packaging/sailfish/build.sh.
package main

/*
#cgo pkg-config: Qt6Quick
#cgo CXXFLAGS: -std=c++17
#cgo CXXFLAGS: -I${SRCDIR}/../.keel/usr/include/keel/sailfishapp
#cgo LDFLAGS: -L${SRCDIR}/../.keel/usr/lib64 -Wl,-rpath-link,${SRCDIR}/../.keel/usr/lib64 -lkeel-sailfishapp
#include <stdlib.h>
#include "silica.h"
*/
import "C"

import (
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"unsafe"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
	"github.com/mappu/miqt/qt6/qml"
)

// Qt's application and its loop must stay on the process's main thread: Keel's is made in
// C (silica.cpp), where miqt does not pin the thread as for its own.
func init() { runtime.LockOSThread() }

func main() {
	sailfishEnv()
	if running() { // a copy runs: it was asked to show itself (MPRIS Raise)
		return
	}
	logFile()
	emojiFont()
	qtSetup()
	// The keyboard's Qt 6 plugin (Maliit, Sailfish's) needs a container's D-Bus link
	// (container.go); started directly, Ryūgin serves it. Without one it crashed as the
	// keyboard opened; if serving fails, a link that leads nowhere: it skips it.
	if os.Getenv("FLATPAK_MALIIT_CONTAINER_DBUS") == "" {
		addr := "unix:path=/nonexistent"
		if c, a, err := serveContainer(os.Getenv("XDG_RUNTIME_DIR")); err == nil {
			keyboard, addr = c, a
		} else {
			log.Println("keyboard link:", err)
		}
		os.Setenv("FLATPAK_MALIIT_CONTAINER_DBUS", addr)
	}
	silicaApplication()
	log.Println("start (silica), pid", os.Getpid())
	exe, _ := os.Executable()
	dir := qmlDir("ryugin.qml", os.Getenv("RYUGIN_QML"),
		filepath.Join(filepath.Dir(exe), "qml-sailfish"), "/usr/share/"+appID+"/qml-sailfish")
	translate(filepath.Join(filepath.Dir(dir), "qml", "translations")) // qml-sailfish/ uses qml/'s
	ctx := qml.UnsafeNewQQmlContext(C.silica_view())
	bridge := setContext(ctx)
	// tests/silica.sh: the page to open first, and where to save the window's picture.
	for name, env := range map[string]string{"goStartPage": "RYUGIN_PAGE", "goShot": "RYUGIN_SHOT", "goScroll": "RYUGIN_SCROLL", "goLandscape": "RYUGIN_LANDSCAPE", "goPerf": "RYUGIN_PERF", "goKeyboard": "RYUGIN_KEYBOARD"} {
		if v := os.Getenv(env); v != "" {
			ctx.SetContextProperty2(name, qt.NewQVariant14(v))
		}
	}
	path := C.CString(filepath.Join(dir, "ryugin.qml"))
	root := qt.UnsafeNewQObject(C.silica_show(path))
	C.free(unsafe.Pointer(path))
	if root == nil {
		log.Fatal("QML failed to load (set RYUGIN_QML to the qml-sailfish folder)")
	}
	send := sender(root)
	bridge.OnObjectNameChanged(fromQML(startMpris(send), send))

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, os.Interrupt)
	// Out of the event loop at once (silica.cpp: a plain quit loops with Keel).
	go func() { log.Println("quit:", <-quit); mainthread.Start(qt.QCoreApplication_Exit) }()

	qt.QGuiApplication_Exec()
	log.Println("exit")
}

// silicaApplication makes Keel's application from os.Args (kept for the program's life, as
// Qt keeps argc and argv).
func silicaApplication() {
	argc := (*C.int)(C.malloc(C.size_t(unsafe.Sizeof(C.int(0)))))
	*argc = C.int(len(os.Args))
	argv := (**C.char)(C.malloc(C.size_t(len(os.Args)+1) * C.size_t(unsafe.Sizeof(uintptr(0)))))
	args := unsafe.Slice(argv, len(os.Args)+1)
	for i, a := range os.Args {
		args[i] = C.CString(a)
	}
	args[len(os.Args)] = nil
	C.silica_application(argc, argv)
}

// sailfishEnv sets Qt up for Sailfish OS (Keel).
func sailfishEnv() {
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
	// Sailjail lets the app write only in its own folders (ryugin.desktop's OrganizationName
	// and ApplicationName): the caches and the settings go there (the package moves the old).
	home, _ := os.UserHomeDir()
	os.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache", jailDir))
	qt.QSettings_SetPath(qt.QSettings__NativeFormat, qt.QSettings__UserScope, filepath.Join(home, ".config", jailDir))
}

// jailDir is the app's folder in ~/.cache and ~/.config under Sailjail.
const jailDir = "dragon/ryugin"

// logFile sends stderr (Qt, FFmpeg, Go, a crash's trace) to
// ~/.cache/dragon/ryugin/ryugin/ryugin.log, the last run's kept as ryugin.log.old: Sailfish
// OS's journal keeps only a few minutes.
func logFile() {
	cache, _ := os.UserCacheDir()
	p := filepath.Join(cache, appID, appID+".log")
	os.MkdirAll(filepath.Dir(p), 0o755)
	os.Rename(p, p+".old")
	if f, err := os.Create(p); err == nil {
		_ = syscall.Dup3(int(f.Fd()), 2, 0) // failed: stderr as it was
	}
}

// emojiFont: emoji in titles drawn in colour. Qt 6.8 asks fontconfig for its emoji font,
// which can be one it cannot draw (Twitter Color Emoji, SVG in OpenType): the emoji showed
// nothing. The app's own fontconfig file (the system's, then this) skips that one, and Noto
// Emoji (black and white, taken next), and puts Noto Color Emoji (COLRv1, which Qt draws)
// first. Before Qt starts.
func emojiFont() {
	if os.Getenv("FONTCONFIG_FILE") != "" {
		return
	}
	cache, _ := os.UserCacheDir()
	conf := filepath.Join(cache, "fonts.conf")
	_ = os.MkdirAll(cache, 0o755)
	err := os.WriteFile(conf, []byte(`<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <selectfont><rejectfont><glob>*TwitterColorEmoji*</glob><glob>*/NotoEmoji-*</glob></rejectfont></selectfont>
  <match target="pattern">
    <test name="family"><string>emoji</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>Noto Color Emoji</string></edit>
  </match>
</fontconfig>
`), 0o644)
	if err == nil {
		os.Setenv("FONTCONFIG_FILE", conf)
	}
}
