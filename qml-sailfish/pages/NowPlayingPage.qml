import QtQuick 2.6
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The song playing, as Jolla's Media player shows one: the cover edge to edge at the top,
// its synced lyrics under it, and the song with its controls docked at the bottom
// (PlayerPanel: swipe them up for shuffle, repeat and the heart). Swipe left for the queue
// (its own page, attached, as SubMusic has its playlist); tap the lyrics, or pull down, for
// them whole; pull down for the album too. In landscape the cover takes the left side.
Page {
    id: page

    readonly property var track: R.Player.current

    objectName: "nowPlaying"
    allowedOrientations: Orientation.All
    // While the finger seeks on the bar, no page swipe either way, as Jolla's busy pages
    // hold theirs.
    backNavigation: !panel.seeking
    forwardNavigation: !panel.seeking

    onStatusChanged: {
        // Once: attached again on the way back (a quick swipe left then right), it replaced
        // the queue mid-animation and left both pages drawn over each other.
        if (status === PageStatus.Active && pageStack.nextPage(page) === null) {
            pageStack.pushAttached(Qt.resolvedUrl("QueuePage.qml"))
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: height

        Pulley {
            MenuItem {
                visible: page.track !== null && page.track.albumId !== ""
                //% "Go to album"
                text: qsTrId("ryugin-me-go_to_album")
                onClicked: R.Nav.openAlbum(page.track.albumId)
            }
            MenuItem {
                visible: R.Player.lyrics.length > 0 // plain lyrics too, which the page does not show
                //% "Lyrics"
                text: qsTrId("ryugin-me-lyrics")
                onClicked: R.Nav.open("LyricsPage")
            }
        }

        // Edge to edge: the page's width (its height in landscape, at the left), smaller only
        // when the lyrics would have no room.
        Image {
            id: cover

            readonly property real room: page.isLandscape ? page.height : page.height - panel.height - Theme.itemSizeHuge

            width: Math.min(page.isLandscape ? page.height : page.width, room)
            height: width
            x: page.isLandscape ? 0 : (page.width - width) / 2
            sourceSize {
                width: width
                height: height
            }
            fillMode: Image.PreserveAspectCrop
            source: page.track ? R.Api.cover(page.track.cover, 720) : ""
        }

        // Synced lyrics between the cover and the controls (at its right in landscape): three
        // lines in full, wrapped as long as they are, the one sung (larger, lit word by word)
        // in the middle; the first three before the singing. A tap opens them whole.
        Column {
            id: lines

            readonly property real roomTop: page.isLandscape ? 0 : cover.height
            readonly property real room: page.height - panel.height - roomTop
            readonly property int at: R.Player.lyricIndex

            objectName: "nowLyrics"
            x: page.isLandscape ? cover.width : 0
            y: roomTop + Math.max(0, (room - height) / 2)
            width: page.width - x
            spacing: Theme.paddingMedium
            visible: R.Player.lyricsSynced && R.Player.lyrics.length > 0

            LyricClock {
                id: clock

                running: page.status === PageStatus.Active
            }

            Repeater {
                model: 3

                Label {
                    readonly property int i: (lines.at < 0 ? 0 : lines.at - 1) + index
                    readonly property var line: i >= 0 && i < R.Player.lyrics.length ? R.Player.lyrics[i] : null
                    readonly property bool now: i === lines.at
                    readonly property bool byWord: now && line !== null && !!line.words && line.words.length > 0

                    x: Theme.horizontalPageMargin
                    width: lines.width - 2 * x
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: now ? Theme.fontSizeLarge : Theme.fontSizeMedium
                    textFormat: byWord ? Text.StyledText : Text.PlainText
                    color: now ? palette.highlightColor : palette.secondaryColor
                    text: line === null ? "" : byWord ? clock.sung(line.words, palette) : line.text
                }
            }
        }
        MouseArea {
            anchors.fill: lines
            enabled: lines.visible
            onClicked: R.Nav.open("LyricsPage")
        }
    }

    PlayerPanel {
        id: panel
    }
}
