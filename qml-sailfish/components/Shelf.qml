import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// A row of albums, or of songs (songs set: recently played), under a section header, flicked
// sideways. Hidden while empty. A tap opens an album, or plays the songs from the one
// tapped (as 1.2's); a long press opens a menu under the row: play the album (a song's:
// from it).
Column {
    id: shelf

    property alias title: header.text
    property var albums: []
    property var songs: []
    property var _held: null // the album or song whose menu is open
    property ContextMenu _menu: null

    width: parent.width
    property bool shown: true // Settings › Home can hide it
    visible: shown && albums.length + songs.length > 0

    // The album's songs (of the album, or of the song's), then f(songs).
    function _withAlbum(f) {
        var held = _held
        R.Api.getAlbum(songs.length > 0 ? held.albumId : held.id, function (a, tracks) {
            if (tracks.length > 0) {
                f(tracks, held)
            }
        })
    }

    SectionHeader {
        id: header
    }

    SilicaListView {
        width: parent.width
        height: Theme.itemSizeHuge * 1.4 + Theme.itemSizeSmall
        // Its albums past the page's edge stay hidden (they showed over the next page as
        // pages slid).
        clip: true
        orientation: ListView.Horizontal
        leftMargin: Theme.horizontalPageMargin - Theme.paddingSmall
        rightMargin: leftMargin
        model: shelf.songs.length > 0 ? shelf.songs : shelf.albums

        delegate: AlbumTile {
            width: Theme.itemSizeHuge * 1.4
            album: modelData
            opens: shelf.songs.length === 0
            menu: shelf._menu
            highlighted: down || (menu !== null && menu.active && shelf._held === modelData)
            onTapped: R.Player.play(shelf.songs, index)
            onPressAndHold: {
                shelf._held = modelData
                if (shelf._menu === null) {
                    shelf._menu = (shelf.songs.length > 0 ? songMenu : albumMenu).createObject(shelf)
                }
                shelf._menu.open(menuSpace)
            }
        }

        HorizontalScrollDecorator {}
    }

    // Room for the menu, as tall as it is open: what is under the row moves down. As it
    // opens, the page scrolls it clear of the player docked over the page's end (Silica
    // shows it above the page's end, under the player).
    Item {
        id: menuSpace

        width: parent.width
        height: shelf._menu !== null && shelf._menu.parent === menuSpace ? shelf._menu.height : 0
        onHeightChanged: {
            var f = shelf._menu !== null && shelf._menu.active ? shelf._menu._flickable : null
            if (f) {
                var end = menuSpace.mapToItem(f.contentItem, 0, height).y
                var shown = f.contentY + f.height - (R.Player.current ? Theme.itemSizeLarge : 0)
                if (end > shown) {
                    f.contentY += end - shown
                }
            }
        }
    }

    Component {
        id: albumMenu

        ContextMenu {
            MenuItem {
                //% "Play"
                text: qsTrId("ryugin-me-play")
                onClicked: shelf._withAlbum(function (tracks) { R.Player.play(tracks, 0) })
            }
        }
    }

    Component {
        id: songMenu

        ContextMenu {
            MenuItem {
                //% "Play album"
                text: qsTrId("ryugin-me-play_album")
                onClicked: shelf._withAlbum(function (tracks, song) {
                    R.Player.play(tracks, Math.max(0, tracks.findIndex(function (t) { return t.id === song.id })))
                })
            }
        }
    }
}
