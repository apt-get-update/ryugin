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

    Component.onCompleted: R.Api.getArtist(artistId, function (n, list) {
        page.albums = list
        page.loaded = true
    })

    SilicaGridView {
        id: grid

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        cellWidth: width / Math.max(2, Math.round(width / (Theme.itemSizeHuge * 1.5)))
        cellHeight: cellWidth + Theme.itemSizeSmall
        model: page.albums

        header: PageHeader {
            title: page.name
            description: page.loaded ? page.albums.length + " albums" : ""
        }

        delegate: AlbumTile {
            width: grid.cellWidth
            album: modelData
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: !page.loaded
        }

        VerticalScrollDecorator {}
    }
}
