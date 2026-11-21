import QtQuick

// A rounded, bordered card; hoverable cards light up and can be clicked.
Rectangle {
    id: card
    property bool hoverable: false
    readonly property bool hovered: area.containsMouse
    signal clicked()
    radius: Theme.radiusXl
    color: hoverable && area.containsMouse ? Theme.cardHover : Theme.card
    border.color: Theme.border
    border.width: 1
    Behavior on color { ColorAnimation { duration: 150 } }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: card.hoverable
        hoverEnabled: true
        cursorShape: card.hoverable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.clicked()
    }
}
