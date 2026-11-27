import QtQuick

// An on/off switch, in the song's colour (Theme.gold): drawn here, as a widget style
// (Kvantum) paints its own colours.
Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool checked)
    width: 42
    height: 24
    radius: 12
    color: checked ? Theme.gold : Theme.bright
    Behavior on color { ColorAnimation { duration: 150 } }
    Rectangle {
        x: t.checked ? t.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: t.checked ? Theme.goldInk : Theme.text
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
}
