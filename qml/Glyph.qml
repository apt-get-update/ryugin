import QtQuick

// A large bare icon button for the fullscreen player (white on the cover's colours).
Item {
    id: g
    property string name
    property int size: 32
    property bool dim: false
    signal clicked()
    width: size
    height: size
    scale: area.pressed ? 0.88 : 1
    Behavior on scale { NumberAnimation { duration: 120 } }
    Icon {
        anchors.centerIn: parent
        name: g.name
        size: g.size
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, area.containsMouse ? 1 : (g.dim ? 0.45 : 0.85))
    }
    MouseArea { id: area; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: g.enabled; onClicked: g.clicked() }
}
