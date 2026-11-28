import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// One artist's albums, as a grid of covers.
Page {
    id: page

    property string artistId
    property string name
    property var albums: []
    property bool loaded

    function load() {
        R.Api.getArtist(artistId, function (n, list) {
            if (!page)
                return // gone before Navidrome answered
            page.albums = list
            page.loaded = true
        })
    }

    Component.onCompleted: load()

    Connections {
        target: R.Api

        function onLibraryChanged() { page.load() } // a scan done, an album hidden
    }

    SilicaGridView {
        id: grid

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        cellWidth: width / Math.max(2, Math.round(width / (Theme.itemSizeHuge * 1.5)))
        cellHeight: cellWidth + Theme.itemSizeSmall
        model: page.albums

        header: PageHeader {
            title: page.name
            //% "%n albums"
            description: page.loaded ? qsTrId("ryugin-la-n_albums", page.albums.length) : ""
        }

        delegate: AlbumTile {
            width: grid.cellWidth
            album: modelData
        }

        PageBusyIndicator {
            running: !page.loaded
        }

        ViewPlaceholder {
            enabled: page.loaded && page.albums.length === 0
            text: qsTrId("ryugin-la-no_albums")
            hintText: R.Api.error
        }

        VerticalScrollDecorator {}
    }
}
