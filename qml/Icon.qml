import QtQuick

// A Lucide icon in any colour. The SVG is drawn once, in white, at exactly its size in
// screen pixels (it states its size: Qt ignores sourceSize for a data: URL), and
// icon.frag tints it: a new colour (a new song) never reloads it, so nothing blinks.
Item {
    id: icon
    property string name
    property color color: Theme.dim
    property int size: 20
    readonly property int px: Math.round(size * (Screen.devicePixelRatio || 1))
    readonly property alias image: img
    width: size
    height: size
    // Keep the old picture while a new one loads: no blink (Qt 6.8+; older Qt, as on
    // Sailfish OS, just skips it).
    Binding { target: img; property: "retainWhileLoading"; value: true; when: "retainWhileLoading" in img }
    Image {
        id: img
        anchors.fill: parent
        visible: false
        smooth: true // nearest sampling breaks strokes when the icon sits on a half pixel
        source: Icons.svg[icon.name] ? "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="' + icon.px + '" height="' + icon.px + '" viewBox="0 0 24 24">'
            + Icons.svg[icon.name].replace(/COLOR/g, "#ffffff") + '</svg>') : ""
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: img
        property color tint: icon.color
        fragmentShader: "icon.frag.qsb"
    }
}
