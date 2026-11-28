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
    // Liked: the list holds its own copy of the song, so a like is followed here (as the
    // desktop's TrackList does).
    property bool starred: !!track.starred
    // The heart's colour, Silica's (inside the Loader, "item" is the Loader's own item).
    readonly property color heartColor: palette.highlightColor

    contentHeight: Theme.itemSizeMedium
    onClicked: R.Player.play(tracks, index)

    menu: Component {
        ContextMenu {
            MenuItem {
                //% "Add to queue"
                text: qsTrId("ryugin-me-add_to_queue")
                onClicked: R.Player.enqueue([item.track])
            }
            MenuItem {
                text: item.starred
                      //% "Unlike"
                      ? qsTrId("ryugin-me-unlike")
                      //% "Like"
                      : qsTrId("ryugin-me-like")
                onClicked: R.Player.setStarred(item.track.id, !item.starred)
            }
            MenuItem {
                visible: item.track.albumId !== "" && !item.showNumber // numbered: on the album already
                //% "Go to album"
                text: qsTrId("ryugin-me-go_to_album")
                onClicked: R.Nav.openAlbum(item.track.albumId)
            }
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

        Loader { // a liked song's heart, made for it only
            visible: active
            active: item.starred
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: Item {
                width: Theme.iconSizeExtraSmall
                height: width

                // Drawn once in white, tinted on the GPU (icon.frag): the song's colour fading
                // in redraws no SVG. Silica's inset: the shape in 24/29 of the box.
                R.Icon {
                    anchors.centerIn: parent
                    name: "heart-fill"
                    size: Math.round(parent.width * 24 / 29)
                    color: heartColor
                }
            }
        }
        Label {
            font.pixelSize: Theme.fontSizeExtraSmall
            color: palette.secondaryColor
            text: R.Theme.time(item.track.duration)
        }
    }

    Connections {
        target: R.Player
        function onLiked(songId, on) { if (songId === item.track.id) item.starred = on }
    }
}
