import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// Every album, by name, as a grid of covers.
Page {
    id: page

    property var albums: []

    Component.onCompleted: R.Api.allAlbums(function (list) { page.albums = list })

    SilicaGridView {
        id: grid

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        cellWidth: width / Math.max(2, Math.round(width / (Theme.itemSizeHuge * 1.5)))
        cellHeight: cellWidth + Theme.itemSizeSmall
        model: page.albums
        quickScroll: true

        header: PageHeader {
            title: "Albums"
        }

        delegate: AlbumTile {
            width: grid.cellWidth
            album: modelData
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.albums.length === 0 && R.Api.configured
        }

        VerticalScrollDecorator {}
    }
}
