package main

import (
	"os"
	"runtime"
	"strings"
	"testing"

	qt "github.com/mappu/miqt/qt6"
)

// Qt wants its widgets on the main thread: tests hand it their Qt work through onQt.
func init() { runtime.LockOSThread() }

var qtWork = make(chan func())

func TestMain(m *testing.M) {
	done := make(chan int)
	go func() { done <- m.Run() }()
	for {
		select {
		case f := <-qtWork:
			f()
		case code := <-done:
			os.Exit(code)
		}
	}
}

var qtApp bool

func onQt(f func()) {
	ch := make(chan struct{})
	qtWork <- func() {
		defer close(ch)
		if !qtApp {
			os.Setenv("QT_QPA_PLATFORM", "offscreen")
			os.Setenv("LC_ALL", "C.UTF-8") // the English texts (make qm), as the tests compare
			qt.NewQApplication(os.Args)
			translate("../qml/translations")
			qtApp = true
		}
		f()
	}
	<-ch
}

// The global menu as AT-SPI (and so Noctalia's appmenu, atspi-menu.py) sees it: a menu bar
// in a window of the app, top-level items each wrapping a popup menu, and items that send
// commands QML knows.
func TestGlobalMenu(t *testing.T) {
	qml := ""
	for _, f := range []string{"../qml/Main.qml", "../qml/Player.qml"} {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		qml += string(b)
	}
	onQt(func() { // t.Error and return here: t.Fatal off the test goroutine hangs
		var sent []map[string]any
		bar := newMenuBar(func(c map[string]any) { sent = append(sent, c) })

		found := false
		for _, w := range qt.QGuiApplication_TopLevelWindows() {
			found = found || w.UnsafePointer() == bar.WindowHandle().UnsafePointer()
		}
		if !found {
			t.Error("the menubar has no window: AT-SPI would not list it")
			return
		}
		if bar.IsVisible() {
			t.Error("the menubar is shown")
		}

		a := qt.QAccessible_QueryAccessibleInterface(bar.QObject)
		if a.Role() != qt.QAccessible__MenuBar {
			t.Error("role", a.Role())
			return
		}
		var tops []string
		items := 0
		for i := 0; i < a.ChildCount(); i++ {
			top := a.Child(i)
			tops = append(tops, top.Text(qt.QAccessible__Name))
			if top.Role() != qt.QAccessible__MenuItem || top.ChildCount() != 1 || top.Child(0).Role() != qt.QAccessible__PopupMenu {
				t.Errorf("%q is not menu item > popup menu", tops[i])
				return
			}
			popup := top.Child(0)
			if popup.ChildCount() == 0 {
				t.Errorf("%q is empty while closed", tops[i])
				return
			}
			for _, act := range qt.UnsafeNewQMenu(popup.Object().UnsafePointer()).Actions() {
				if act.IsSeparator() {
					continue
				}
				items++
				act.Trigger()
				c := sent[len(sent)-1]
				if !strings.Contains(qml, `"`+c["cmd"].(string)+`"`) {
					t.Errorf("%q sends %v, which QML does not handle", act.Text(), c)
				}
			}
		}
		if strings.Join(tops, ",") != "Ryūgin,Playback,View,Go" {
			t.Error("menus", tops)
		}
		if len(sent) != items || items < 15 {
			t.Errorf("%d items sent %d commands", items, len(sent))
		}
		// Each click sends its own copy: send adds a counter to it.
		sent[0]["n"] = 1
		if _, shared := sent[len(sent)-1]["n"]; shared && len(sent) > 1 {
			t.Error("the items share one command map")
		}
	})
}

// The tray, made headless (no tray to show it): a click shows or hides the window.
func TestTray(t *testing.T) {
	onQt(func() {
		var sent []map[string]any
		tray, ok := newTray("../qml", func(c map[string]any) { sent = append(sent, c) })
		if ok || tray.IsVisible() {
			t.Error("a tray with no tray")
		}
		tray.Activated(qt.QSystemTrayIcon__Context)
		tray.Activated(qt.QSystemTrayIcon__Trigger)
		if len(sent) != 1 || sent[0]["cmd"] != "toggleWindow" {
			t.Error(sent)
		}
		if tray.ContextMenu().Actions()[0].Text() != "Show / hide" {
			t.Error("menu")
		}
	})
}
