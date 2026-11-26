//go:build !silica

package main

import (
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
)

func main() {
	if running() {
		return
	}
	startQt()
	log.Println("start, pid", os.Getpid())
	// $RYUGIN_QML, next to the binary, or the installed copy.
	exe, _ := os.Executable()
	dir := qmlDir("Main.qml", os.Getenv("RYUGIN_QML"), filepath.Join(filepath.Dir(exe), "qml"), "/usr/share/"+appID+"/qml")
	root, bridge := loadQML(dir)
	send := sender(root)

	_, hasTray := newTray(dir, send)
	root.SetProperty("hasTray", qt.NewQVariant8(hasTray))
	newMenuBar(send)
	bridge.OnObjectNameChanged(fromQML(startMpris(send), send))

	// SIGTERM (a logout, tests/run.sh) quits cleanly.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, os.Interrupt)
	go func() { log.Println("quit:", <-quit); mainthread.Start(qt.QCoreApplication_Quit) }()

	qt.QGuiApplication_Exec()
	log.Println("exit")
}
