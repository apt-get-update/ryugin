pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

// The play queue; click a track to jump to it.
Card {
    radius: Theme.radiusXl
    SectionTitle {
        id: head
        x: 18
        y: 16
        title: "Queue"
        subtitle: Player.queue.length + " tracks"
    }
    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: 66
        anchors.margins: 8
        clip: true
        spacing: 2
        model: Player.queue
        C.ScrollBar.vertical: Scroller {}
        Component.onCompleted: positionViewAtIndex(Player.index, ListView.Center)
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 52
            radius: Theme.radius
            color: row.index === Player.index ? Theme.cardHover : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
            MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Player.jump(row.index) }
            Cover { id: c; x: 8; width: 36; height: 36; size: 80; radius: 6; anchors.verticalCenter: parent.verticalCenter; coverId: row.modelData.cover }
            Column {
                anchors.left: c.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; text: row.modelData.title; color: row.index === Player.index ? Theme.gold : Theme.text; font.pixelSize: 13; elide: Text.ElideRight }
                Text { width: parent.width; text: row.modelData.artist; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight }
            }
        }
    }
}
