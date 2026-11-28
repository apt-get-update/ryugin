import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// An album (or a song) as its cover, title and artist under it. A tap opens the album, or
// does what the row says (tapped); while a menu (of its row) is open, a tap only closes it.
BackgroundItem {
    id: tile

    property var album
    property bool opens: true
    property ContextMenu menu: null

    property bool _menuWasOpen // at the press: still shown (it starts closing at a press anywhere)

    signal tapped()

    height: width + Theme.itemSizeSmall
    onPressed: _menuWasOpen = menu !== null && menu._open
    onClicked: {
        if (_menuWasOpen) {
            menu.close()
        } else if (opens) {
            R.Nav.openAlbum(album.id)
        } else {
            tapped()
        }
    }

    Image {
        id: art

        x: Theme.paddingSmall
        y: Theme.paddingSmall
        width: parent.width - 2 * Theme.paddingSmall
        height: width
        sourceSize {
            width: width
            height: height
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: R.Api.cover(tile.album.cover, R.Api.albumCover) // the size Go fetched ahead
    }

    Column {
        anchors {
            left: art.left
            right: art.right
            top: art.bottom
            topMargin: Theme.paddingSmall
        }

        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: tile.highlighted ? palette.highlightColor : palette.primaryColor
            text: tile.album.title
        }
        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeTiny
            color: tile.highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
            text: tile.album.artist
        }
    }
}
