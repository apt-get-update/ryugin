import QtQuick

// An icon that acts as a button; round when it has a background.
Rectangle {
    id: b
    property string icon
    property int iconSize: 20
    property bool active: false
    property bool filled: false
    property color iconColor: active ? Theme.gold : (area.containsMouse ? Theme.text : Theme.dim)
    signal clicked()
    implicitWidth: iconSize + 16
    implicitHeight: iconSize + 16
    radius: width / 2
    color: filled ? (area.containsMouse ? Theme.bright : Theme.field) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    Icon { anchors.centerIn: parent; name: b.icon; size: b.iconSize; color: b.iconColor }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
