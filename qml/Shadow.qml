import QtQuick
import QtQuick.Effects

// A soft shadow under a rounded rectangle, by MultiEffect (Qt 6.5): RectangularShadow
// needs Qt 6.9, and the app runs on 6.7.
Item {
    id: shadow
    property real radius: 0
    property real blur: 20
    property real spread: 0
    property color color: Qt.rgba(0, 0, 0, 0.3)
    property point offset: Qt.point(0, 0)
    Rectangle {
        id: shape
        x: shadow.offset.x - shadow.spread
        y: shadow.offset.y - shadow.spread
        width: shadow.width + 2 * shadow.spread
        height: shadow.height + 2 * shadow.spread
        radius: shadow.radius + shadow.spread
        color: shadow.color
        visible: false
    }
    MultiEffect {
        source: shape
        x: shape.x
        y: shape.y
        width: shape.width
        height: shape.height
        autoPaddingEnabled: true
        blurEnabled: true
        blur: 1
        blurMax: Math.max(1, Math.round(shadow.blur))
    }
}
