pragma ComponentBehavior: Bound
import QtQuick

// Narrow icon rail, like SPlayer-Next's collapsed sidebar. Hover shows the name.
Rectangle {
    id: side
    property var pages: []
    property string current: ""
    signal selected(string key)
    width: Nav.rail ? 68 : 0 // a phone upright has tabs at the bottom instead
    visible: width > 0
    color: Theme.panel

    Image {
        id: logo
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: 40
        height: 40
        source: "icon.png"
        sourceSize: Qt.size(80, 80)
        smooth: true
        mipmap: true
        visible: !Nav.phone // on its side, a phone's height is for the pages
    }

    Column {
        anchors.top: logo.visible ? logo.bottom : parent.top
        anchors.topMargin: logo.visible ? 22 : 14
        width: parent.width
        spacing: 6
        Repeater {
            model: side.pages.filter(function (p) { return !p.bottom; })
            delegate: item
        }
    }
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: parent.width
        spacing: 6
        Repeater {
            model: side.pages.filter(function (p) { return p.bottom; })
            delegate: item
        }
    }

    Component {
        id: item
        Item {
            id: entry
            required property var modelData
            width: side.width
            height: 44
            readonly property bool active: side.current === entry.modelData.key
            Rectangle {
                anchors.centerIn: parent
                width: 44
                height: 44
                radius: Theme.radius
                color: parent.active ? Theme.card : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                border.color: parent.active ? Theme.border : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; name: entry.modelData.icon; size: 21; color: entry.active ? Theme.gold : (area.containsMouse ? Theme.text : Theme.dim) }
            }
            Rectangle {
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: parent.active ? 18 : 0
                radius: 2
                color: Theme.gold
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            // Name on hover.
            Rectangle {
                x: side.width - 2
                anchors.verticalCenter: parent.verticalCenter
                width: tip.implicitWidth + 20
                height: 30
                radius: 8
                color: Theme.bright
                border.color: Theme.border
                visible: area.containsMouse
                z: 10
                Text { id: tip; anchors.centerIn: parent; text: entry.modelData.label; color: Theme.text; font.pixelSize: 12 }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: side.selected(entry.modelData.key)
            }
        }
    }
}
