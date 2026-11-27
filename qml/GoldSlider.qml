import QtQuick
import QtQuick.Controls

// The song's progress and the volume: a thin bar in the song's colour (Theme.gold), thicker
// under the mouse. Its own drawing: a widget style (Kvantum) paints its own colours.
Slider {
    id: s
    implicitHeight: 16
    background: Rectangle {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth
        height: s.hovered || s.pressed ? 5 : 3
        radius: height / 2
        color: Theme.track
        Behavior on height { NumberAnimation { duration: 120 } }
        Rectangle {
            width: s.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.gold
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 12
        height: 12
        radius: 6
        color: Theme.text
        opacity: s.hovered || s.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
