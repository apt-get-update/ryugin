// Tray icon: click it to show or hide the window; its menu plays, skips and quits.
// With a tray, closing the window only hides it. It is made even with no tray to show it
// (and so is tested headless); it says whether there is one.
package main

import (
	"path/filepath"

	qt "github.com/mappu/miqt/qt6"
)

func newTray(dir string, send func(map[string]any)) (*qt.QSystemTrayIcon, bool) {
	available := qt.QSystemTrayIcon_IsSystemTrayAvailable()
	qt.QGuiApplication_SetQuitOnLastWindowClosed(!available)
	tray := qt.NewQSystemTrayIcon2(qt.NewQIcon4(filepath.Join(dir, "tray.png")))
	tray.SetToolTip("Ryūgin")

	menu := qt.NewQMenu2()
	fill(menu, send,
		item{ /*% "Show / hide" */ qtTrId("ryugin-me-show_hide"), cmd("toggleWindow")},
		item{},
		item{ /*% "Play / pause" */ qtTrId("ryugin-me-play_pause"), cmd("playPause")},
		item{ /*% "Next" */ qtTrId("ryugin-me-next"), cmd("next")},
		item{ /*% "Previous" */ qtTrId("ryugin-me-previous"), cmd("previous")},
		item{},
		item{ /*% "Quit" */ qtTrId("ryugin-me-quit"), cmd("quit")})
	tray.SetContextMenu(menu)

	tray.OnActivated(func(reason qt.QSystemTrayIcon__ActivationReason) {
		if reason == qt.QSystemTrayIcon__Trigger {
			send(map[string]any{"cmd": "toggleWindow"})
		}
	})
	tray.SetVisible(available)
	return tray, available
}
