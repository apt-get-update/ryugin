pragma ComponentBehavior: Bound
import QtQuick

// Tracks as SPlayer's cards (number, cover, title over artist); click one to play the
// list from there. The playing track is lit.
ListView {
    id: list
    property var tracks: []
    property bool showArtist: true
    property bool showNumber: true
    model: tracks
    interactive: false
    height: contentHeight
    spacing: 12
    delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
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
            Icon {
                anchors.centerIn: parent
                visible: row.isCurrent || area.containsMouse
                name: row.isCurrent && Player.playing ? "volume-2" : "play"
                size: 15
                color: row.isCurrent ? Theme.gold : Theme.text
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
            Text { width: parent.width; text: row.modelData.artist; color: Theme.dim; font.pixelSize: 12; elide: Text.ElideRight }
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
            icon: "star"
            iconSize: 16
            active: row.starred
            onClicked: {
                // Rows get a copy of the track: change the list's own object too.
                const t = list.tracks[row.index];
                row.starred = t.starred = !row.starred;
                Player.setStarred(t.id, t.starred);
            }
        }
    }
}
