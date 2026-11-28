pragma ComponentBehavior: Bound
import QtQuick

// Tracks as SPlayer's cards (number, cover, title over artist); click one to play the
// list from there. The playing track is lit.
ListView {
    id: list
    property var tracks: []
    property bool showArtist: true
    property bool showNumber: true
    // On an album's page: each disc of a multi-disc album opens with its name and cover.
    property var album: null
    model: tracks
    interactive: false
    height: contentHeight
    spacing: 12
    // In a page that scrolls (view: Page.qml, the list in its column), only the rows in
    // sight are made, with a page's height more on each side: all 500 rows of a long
    // playlist took 0.7 s to open. seen: the page's top in the list.
    property Flickable view: null
    readonly property real seen: view ? view.contentY - y - parent.y : 0
    displayMarginBeginning: view ? -Math.max(0, seen - view.height) : 0
    displayMarginEnd: view ? -Math.max(0, height - seen - 2 * view.height) : 0
    delegate: Column {
        id: entry
        required property var modelData
        required property int index
        width: list.width
        spacing: 8
        Item {
            visible: list.album !== null && Api.discStart(list.tracks, entry.index)
            width: parent.width
            height: 40
            Cover {
                id: disc
                x: 10
                anchors.bottom: parent.bottom
                width: 28
                height: 28
                radius: 4
                size: 96
                coverId: parent.visible ? entry.modelData.cover : ""
            }
            Text {
                anchors.left: disc.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: disc.verticalCenter
                text: Api.discName(list.album, entry.modelData.disc)
                color: Theme.dim
                font.pixelSize: 13
                font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
            }
        }
        Rectangle {
            id: row
            readonly property var modelData: entry.modelData
            readonly property int index: entry.index
            readonly property bool isCurrent: Player.current !== null && Player.current.id === modelData.id
            property bool starred: modelData.starred
            width: list.width
            height: 76
            radius: 8
            color: area.containsMouse ? Theme.card : Theme.panel
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Player.play(list.tracks, row.index)
            }
            Item {
                id: num
                x: 10
                width: 34
                height: parent.height
                Text {
                    anchors.centerIn: parent
                    visible: !row.isCurrent && !area.containsMouse
                    text: list.showNumber && row.modelData.number ? row.modelData.number : row.index + 1
                    color: Theme.faint
                    font.pixelSize: 13
                }
                Loader {
                    anchors.centerIn: parent
                    active: row.isCurrent || area.containsMouse
                    sourceComponent: Icon { name: row.isCurrent && Player.playing ? "volume-2" : "play"; size: 15; color: row.isCurrent ? Theme.gold : Theme.text }
                }
            }
            Cover {
                id: thumb
                anchors.left: num.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                radius: 6
                size: 96
                coverId: row.modelData.cover
            }
            Column {
                anchors.left: thumb.right
                anchors.leftMargin: 14
                anchors.right: dur.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { width: parent.width; text: row.modelData.title; color: row.isCurrent ? Theme.gold : Theme.text; font.pixelSize: 14; elide: Text.ElideRight }
                Text { width: parent.width; visible: list.showArtist; text: row.modelData.artist; color: Theme.dim; font.pixelSize: 12; elide: Text.ElideRight }
            }
            Text {
                id: dur
                anchors.right: star.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.time(row.modelData.duration)
                color: Theme.dim
                font.pixelSize: 12
            }
            IconButton {
                id: star
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                icon: row.starred ? "heart-fill" : "heart"
                iconSize: 16
                active: row.starred
                onClicked: {
                    // Rows get a copy of the track: change the list's own object too.
                    const t = list.tracks[row.index];
                    t.starred = !row.starred;
                    Player.setStarred(t.id, t.starred);
                }
            }
            Connections {
                target: Player
                function onLiked(songId, on) { if (songId === row.modelData.id) row.starred = on; }
            }
        }
    }
}
