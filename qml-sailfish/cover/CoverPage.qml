import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The home screen's card, as the media player's (and 1.2's qt-runner cover): the song's
// art with its artist and title, dimmed while paused, with play/pause and next. Idle
// (nothing played yet this run): the last 3 albums played, one large and two small, with
// play; with none, the app's icon and name.
CoverBackground {
    id: cover

    readonly property var track: R.Player.current
    readonly property bool idle: track === null || R.Player.restored
    readonly property var idleArt: {
        R.Player.history
        R.Player.serverCovers
        return R.Player.recentArt()
    }

    CoverPlaceholder {
        visible: cover.idle && cover.idleArt.length === 0
        text: "Ryūgin"
        icon.source: "/usr/share/icons/hicolor/172x172/apps/ryugin.png"
    }

    // Idle: one large art, two small ones under it (dimmed).
    Item {
        anchors.fill: parent
        visible: cover.idle

        Image {
            id: large

            width: parent.width
            height: cover.idleArt.length > 1 ? width : parent.height
            sourceSize {
                width: width
                height: height
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: cover.idleArt.length > 0 ? cover.idleArt[0] : ""
        }
        Image {
            id: second

            anchors.top: large.bottom
            width: cover.idleArt.length > 2 ? parent.width / 2 : parent.width
            height: parent.height - large.height
            visible: cover.idleArt.length > 1
            sourceSize {
                width: width
                height: height
            }
            fillMode: Image.PreserveAspectCrop
            opacity: Theme.opacityLow
            asynchronous: true
            source: visible ? cover.idleArt[1] : ""
        }
        Image {
            anchors {
                top: second.top
                left: second.right
            }
            width: parent.width / 2
            height: second.height
            visible: cover.idleArt.length > 2
            sourceSize {
                width: width
                height: height
            }
            fillMode: Image.PreserveAspectCrop
            opacity: Theme.opacityLow
            asynchronous: true
            source: visible ? cover.idleArt[2] : ""
        }
    }

    Image {
        id: art

        anchors.fill: parent
        visible: !cover.idle && status === Image.Ready
        sourceSize {
            width: width
            height: height
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: cover.track ? R.Api.cover(cover.track.cover, 512) : ""
    }

    Rectangle {
        visible: art.visible
        width: parent.width
        height: column.y + column.height + 2 * Theme.paddingLarge
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Theme.opacityHigh) }
            GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, Theme.opacityLow) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Column {
        id: column

        x: Theme.paddingMedium
        y: Theme.paddingMedium
        width: parent.width - 2 * Theme.paddingMedium
        spacing: Theme.paddingSmall
        visible: !cover.idle
        // Paused: dimmed, as 1.2's.
        opacity: R.Player.playing ? 1.0 : Theme.opacityHigh

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width)
            visible: text !== ""
            truncationMode: TruncationMode.Fade
            maximumLineCount: 1
            font.pixelSize: Theme.fontSizeLarge
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.itemSizeMedium / 2 // aligned with the clock cover's text
            color: art.visible && Theme.colorScheme === Theme.DarkOnLight
                   ? Theme.highlightFromColor(Theme.highlightColor, Theme.LightOnDark)
                   : Theme.highlightColor
            text: cover.track ? cover.track.artist : ""
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width)
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeLarge
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.itemSizeMedium / 2
            color: art.visible && Theme.colorScheme === Theme.DarkOnLight ? Theme.lightPrimaryColor : Theme.primaryColor
            text: cover.track ? cover.track.title : ""
        }
    }

    CoverActionList {
        enabled: !cover.idle
        iconBackground: art.visible

        CoverAction {
            iconSource: R.Player.playing ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: R.Player.toggle()
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next-song"
            onTriggered: R.Player.next()
        }
    }

    CoverActionList {
        enabled: cover.idle && cover.track !== null
        iconBackground: cover.idleArt.length > 0

        CoverAction {
            iconSource: "image://theme/icon-cover-play"
            onTriggered: R.Player.toggle()
        }
    }

    // In the log: when Lipstick shows and hides the card.
    onStatusChanged: console.log("cover:", status, width + "x" + height)

}
