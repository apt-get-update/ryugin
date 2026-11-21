import QtQuick
import QtQuick.Controls.Basic

// A thin scrollbar for every scrolling view: always there on the desktop when there is
// more to see, only while scrolling on a phone (as Sailfish does).
ScrollBar {
    id: bar
    objectName: "scrollbar"
    readonly property bool more: size < 1
    policy: !more ? ScrollBar.AlwaysOff : Nav.phone ? ScrollBar.AsNeeded : ScrollBar.AlwaysOn
    padding: 2
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 8 : 5
        implicitHeight: implicitWidth
        radius: width / 2
        color: bar.pressed ? Theme.gold : Theme.faint
        opacity: bar.policy === ScrollBar.AlwaysOn || bar.active ? (bar.hovered || bar.pressed ? 0.9 : 0.5) : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }
}
