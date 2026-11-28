//go:build !silica

// The global menu: a menubar that is never shown. Qt exposes it over AT-SPI (with
// QT_ACCESSIBILITY=1), so the desktop's global menu (Noctalia's appmenu) lists its items,
// closed menus included, and clicks them.
package main

import qt "github.com/mappu/miqt/qt6"

// item is a menu entry: its text and the command it sends to QML; no text is a separator.
type item struct {
	text string
	cmd  map[string]any
}

func cmd(name string, args ...any) map[string]any {
	c := map[string]any{"cmd": name}
	for i := 0; i+1 < len(args); i += 2 {
		c[args[i].(string)] = args[i+1]
	}
	return c
}

// fill adds items to a menu; each one sends a copy of its command (send adds to it).
func fill(menu *qt.QMenu, send func(map[string]any), items ...item) {
	for _, it := range items {
		if it.text == "" {
			menu.AddSeparator()
			continue
		}
		c := it.cmd
		menu.AddActionWithText(it.text).OnTriggered(func() {
			m := map[string]any{}
			for k, v := range c {
				m[k] = v
			}
			send(m)
		})
	}
}

func newMenuBar(send func(map[string]any)) *qt.QMenuBar {
	bar := qt.NewQMenuBar2()
	bar.SetNativeMenuBar(false) // a plain widget: AT-SPI shows its items
	fill(bar.AddMenuWithTitle("Ryūgin"), send,
		item{ /*% "Show / hide window" */ qtTrId("ryugin-me-show_hide_window"), cmd("toggleWindow")},
		item{},
		item{ /*% "Quit" */ qtTrId("ryugin-me-quit"), cmd("quit")})
	fill(bar.AddMenuWithTitle( /*% "Playback" */ qtTrId("ryugin-me-playback")), send,
		item{ /*% "Play / pause" */ qtTrId("ryugin-me-play_pause"), cmd("playPause")},
		item{ /*% "Next" */ qtTrId("ryugin-me-next"), cmd("next")},
		item{ /*% "Previous" */ qtTrId("ryugin-me-previous"), cmd("previous")},
		item{},
		item{ /*% "Like / unlike" */ qtTrId("ryugin-me-like_unlike"), cmd("like")},
		item{ /*% "Repeat: off, all, one" */ qtTrId("ryugin-me-repeat"), cmd("repeat")},
		item{ /*% "Shuffle on / off" */ qtTrId("ryugin-me-shuffle"), cmd("shuffle")},
		item{},
		item{ /*% "Roll the dice" */ qtTrId("ryugin-la-roll_the_dice"), cmd("lucky")},
		item{ /*% "Karaoke" */ qtTrId("ryugin-la-karaoke"), cmd("karaoke")})
	fill(bar.AddMenuWithTitle( /*% "View" */ qtTrId("ryugin-me-view")), send,
		item{ /*% "Now playing" */ qtTrId("ryugin-me-now_playing"), cmd("nowPlaying")},
		item{ /*% "Queue" */ qtTrId("ryugin-me-queue"), cmd("queue")},
		item{},
		item{ /*% "Blur background" */ qtTrId("ryugin-me-blur_background"), cmd("backdrop", "value", "blur")},
		item{ /*% "Flow background" */ qtTrId("ryugin-me-flow_background"), cmd("backdrop", "value", "flow")})
	fill(bar.AddMenuWithTitle( /*% "Go" */ qtTrId("ryugin-me-go")), send,
		item{ /*% "Home" */ qtTrId("ryugin-me-home"), cmd("go", "page", "home")},
		item{ /*% "Albums" */ qtTrId("ryugin-me-albums"), cmd("go", "page", "albums")},
		item{ /*% "Artists" */ qtTrId("ryugin-me-artists"), cmd("go", "page", "artists")},
		item{ /*% "Playlists" */ qtTrId("ryugin-me-playlists"), cmd("go", "page", "playlists")},
		item{"Navidrome", cmd("go", "page", "settings")})
	bar.WinId() // creates its window, never shown: AT-SPI lists created windows only
	return bar
}

// qtTrId is Qt's: the text for a translation id; make ts finds the calls and the English
// in the //% comment above each.
func qtTrId(id string) string { return qt.QCoreApplication_Translate("", id) } //nolint:revive,stylecheck // Qt's name, for lupdate
