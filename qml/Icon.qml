import QtQuick

// An icon in any colour: from the desktop's icon theme (Icons.theme), else Lucide. The SVG is drawn once, in white, at exactly its size in
// screen pixels (it states its size: Qt ignores sourceSize for a data: URL), and
// icon.frag tints it: a new colour (a new song) never reloads it, so nothing blinks.
Item {
    id: icon
    property string name
    property color color: Theme.dim
    property int size: 20
    readonly property int px: Math.round(size * (Screen.devicePixelRatio || 1))
    readonly property Image image: themed.status === Image.Ready ? themed : img
    width: size
    height: size
    // Keep the old picture while a new one loads: no blink (Qt 6.8+; older Qt, as on
    // Sailfish OS, just skips it).
    Binding { target: img; property: "retainWhileLoading"; value: true; when: "retainWhileLoading" in img }
    // The theme's icon (its shape: icon.frag colours it); not in the theme: Lucide's, in white.
    // Go drew it from the theme's SVG at each size, 10 to 64 px: the picture of exactly
    // this size, nothing to draw or resize.
    Image {
        id: themed
        anchors.fill: parent
        visible: false
        smooth: true
        source: Icons.dir && Icons.have[Icons.theme[icon.name]] ? Icons.dir + Icons.theme[icon.name] + "@" + Math.max(10, Math.min(64, icon.px)) + ".png" : ""
    }
    Image {
        id: img
        anchors.fill: parent
        visible: false
        smooth: true // nearest sampling breaks strokes when the icon sits on a half pixel
        source: themed.status !== Image.Ready ? Icons.url(icon.name, icon.px) : ""
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: themed.status === Image.Ready ? themed : img
        property color tint: icon.color
        fragmentShader: "icon.frag.qsb"
    }
}
