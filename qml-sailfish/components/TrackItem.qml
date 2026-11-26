import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// One song in a list: its album's cover (or its number, on its album), title over artist,
// its length; the playing one lit. A tap plays the
// list from it, a long press offers the rest.
ListItem {
    id: item

    property var tracks: []
    property int index
    property bool showArtist: true
    property bool showNumber
    readonly property var track: tracks[index]
    readonly property bool current: R.Player.current !== null && R.Player.current.id === track.id

    contentHeight: Theme.itemSizeMedium
    onClicked: R.Player.play(tracks, index)

    menu: ContextMenu {
        MenuItem {
            text: "Add to queue"
            onClicked: R.Player.enqueue([item.track])
        }
        MenuItem {
            text: item.track.starred ? "Unlike" : "Like"
            onClicked: R.Player.setStarred(item.track.id, !item.track.starred)
        }
        MenuItem {
            visible: item.track.albumId !== ""
            text: "Go to album"
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("../pages/AlbumPage.qml"), { albumId: item.track.albumId })
        }
    }

    Label {
        id: number

        visible: item.showNumber
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        width: visible ? Theme.itemSizeExtraSmall / 2 : 0
        color: item.current ? palette.highlightColor : palette.secondaryColor
        font.pixelSize: Theme.fontSizeSmall
        text: item.track.number || ""
    }

    Image {
        id: art

        visible: !item.showNumber
        anchors {
            left: parent.left
            leftMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        width: visible ? Theme.itemSizeMedium - 2 * Theme.paddingSmall : 0
        height: width
        sourceSize {
            width: width
            height: height
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: visible ? R.Api.cover(item.track.cover, 128) : ""
    }

    Column {
        anchors {
            left: item.showNumber ? number.right : art.right
            leftMargin: item.showNumber ? Theme.paddingMedium : Theme.paddingLarge
            right: length.left
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            color: item.current || item.highlighted ? palette.highlightColor : palette.primaryColor
            text: item.track.title
        }
        Label {
            visible: item.showArtist
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: item.current || item.highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
            text: item.track.artist
        }
    }

    Row {
        id: length

        anchors {
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.paddingSmall

        Icon {
            visible: item.track.starred
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeExtraSmall
            height: width
            source: "image://theme/icon-s-favorite"
            color: palette.highlightColor
        }
        Label {
            font.pixelSize: Theme.fontSizeExtraSmall
            color: palette.secondaryColor
            text: R.Theme.time(item.track.duration)
        }
    }
}
