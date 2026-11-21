import QtQuick
import QtQuick.Effects

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

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: Theme.card
        visible: art.opacity < 1
        Icon { anchors.centerIn: parent; name: "music"; size: Math.max(16, parent.height / 3); color: Theme.faint }
    }
    // Keep the old picture while a new one loads: no blink (Qt 6.8+; older Qt, as on
    // Sailfish OS, just skips it).
    Binding { target: img; property: "retainWhileLoading"; value: true; when: "retainWhileLoading" in img }
    Image {
        id: img
        anchors.fill: parent
        source: Api.cover(cover.coverId, cover.original ? 0 : cover.size)
        sourceSize: Qt.size(cover.size, cover.size)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        onStatusChanged: {
            const bad = status === Image.Error || (status === Image.Ready && implicitWidth * implicitHeight === 0);
            if (bad && !cover.original)
                cover.original = true;
            else if (status !== Image.Loading)
                cover.ready = status === Image.Ready && !bad;
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: cover.radius
        layer.enabled: true
        visible: false
    }
    // Fades in once loaded: covers arriving one by one do not pop.
    MultiEffect {
        id: art
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        opacity: cover.ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
