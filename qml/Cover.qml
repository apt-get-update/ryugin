pragma ComponentBehavior: Bound
import QtQuick

// Album art from Navidrome with rounded corners and a quiet placeholder.
Item {
    id: cover
    property string coverId: ""
    property int size: 300
    property real radius: Theme.radius
    // A new cover keeps the old one shown until it is loaded: no blank on a new song.
    property bool ready: false
    // A picture the server failed to resize (an error or an empty image): the original.
    property bool original: false
    onCoverIdChanged: original = false
    // Decoded at the size it is drawn (device pixels, in steps of 64: a resize does not
    // decode it again at each pixel), at most size: a card's 124 px kept the 360 px
    // asked of the server, 8 times the memory. Loaded once it has its size.
    readonly property int px: Math.min(size, Math.ceil(Math.max(width, height) * Screen.devicePixelRatio / 64) * 64)

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: Theme.card
        visible: art.opacity < 1
        Icon { anchors.centerIn: parent; name: "music"; size: Math.max(16, parent.height / 3); color: Theme.faint }
    }
    // Keep the old picture while a new one loads: no blink (Qt 6.8+; Qt 6.7 skips it).
    Binding { target: img; property: "retainWhileLoading"; value: true; when: "retainWhileLoading" in img }
    Image {
        id: img
        anchors.fill: parent
        visible: false // drawn by art
        source: cover.px > 0 ? Api.cover(cover.coverId, cover.original ? 0 : cover.size) : ""
        sourceSize: Qt.size(cover.px, cover.px)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: {
            const bad = status === Image.Error || (status === Image.Ready && implicitWidth * implicitHeight === 0);
            if (bad && !cover.original)
                cover.original = true;
            else if (status !== Image.Loading)
                cover.ready = status === Image.Ready && !bad;
        }
    }
    // The picture cropped to fill, its corners rounded (cover.frag): one pass, where a
    // mask took two pictures of the cover's size, each cover. Fades in once loaded:
    // covers arriving one by one do not pop.
    ShaderEffect {
        id: art
        readonly property real dpr: Screen.devicePixelRatio
        readonly property real shape: (width / Math.max(1, height)) / (img.implicitWidth / Math.max(1, img.implicitHeight)) // the cover's to the picture's
        property var source: img
        property size area: Qt.size(width * dpr, height * dpr)
        property size crop: shape < 1 ? Qt.size(shape, 1) : Qt.size(1, 1 / shape)
        property real corner: Math.min(cover.radius, width / 2, height / 2) * dpr
        anchors.fill: parent
        fragmentShader: "cover.frag.qsb"
        opacity: cover.ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
