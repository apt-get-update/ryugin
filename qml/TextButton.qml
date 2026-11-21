import QtQuick

// A pill button with an optional icon.
Rectangle {
    id: b
    property alias text: label.text
    property string icon: ""
    property bool primary: false
    signal clicked()
    implicitWidth: row.implicitWidth + 32
    implicitHeight: 36
    radius: height / 2
    color: primary ? (area.containsMouse ? Theme.cardHover : Theme.bright)
                   : (area.containsMouse ? Theme.bright : Theme.card)
    border.color: primary ? "transparent" : Theme.border
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon { name: b.icon; size: 16; color: Theme.text; visible: b.icon !== ""; anchors.verticalCenter: parent.verticalCenter }
        Text { id: label; color: Theme.text; font.pixelSize: 14; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
