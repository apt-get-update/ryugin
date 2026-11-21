import QtQuick
import QtQuick.Controls.Basic

// A thin bar, white on the cover's colours, thicker while you touch it.
Slider {
    id: s
    implicitHeight: 14
    background: Rectangle {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: s.hovered || s.pressed ? 8 : 5
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.2)
        Behavior on height { NumberAnimation { duration: 150 } }
        Rectangle {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Qt.rgba(1, 0.97, 0.92, s.hovered || s.pressed ? 0.95 : 0.7)
        }
    }
    handle: Item {}
}
