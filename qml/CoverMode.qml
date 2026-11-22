import QtQuick

// Sailfish OS: the home screen shows a minimized app as a live, scaled-down card of its
// window (qt-runner gives it no cover of its own). While minimized the window shows this:
// sized to the part the card shows (the window's top, as wide as it, 0.62 wide for 1 high),
// over the blurred cover darkened as in the fullscreen player.
Rectangle {
    id: cover
    objectName: "coverMode"
    color: Theme.bg
    // Nothing playing: the last song played, else the app's icon.
    readonly property var t: Player.current || (Player.history.length ? Player.history[0] : null)
    readonly property bool idle: !Player.current || Player.restored
    readonly property var next: Player.index + 1 < Player.queue.length ? Player.queue[Player.index + 1] : null
    readonly property real box: Math.min(height, width / 0.62) // what the card shows

    Image { anchors.fill: parent; source: Theme.wash; fillMode: Image.PreserveAspectCrop; visible: Theme.wash !== "" }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }

    Column {
        objectName: "coverColumn"
        anchors.horizontalCenter: parent.horizontalCenter
        y: (cover.box - height) / 2
        width: Math.min(cover.width * 0.86, cover.box * 0.62)
        spacing: cover.box * 0.022
        Cover {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!cover.t
            width: cover.box * 0.52
            height: width
            size: 600
            radius: width * 0.05
            coverId: cover.t ? cover.t.cover : ""
        }
        Image {
            objectName: "coverIcon"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !cover.t
            width: cover.box * 0.52
            height: width
            source: "icon.png"
            sourceSize: Qt.size(512, 512)
            mipmap: true
        }
        Text {
            objectName: "coverTitle"
            width: parent.width
            text: cover.t ? cover.t.title : "Ryūgin 龍吟"
            color: Theme.text
            font.pixelSize: cover.box * 0.05
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: !!cover.t
            text: cover.t ? cover.t.artist + (cover.t.album ? " · " + cover.t.album : "") : ""
            color: Theme.dim
            font.pixelSize: cover.box * 0.036
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Rectangle {
            width: parent.width
            height: Math.max(4, cover.box * 0.009)
            radius: height / 2
            visible: !cover.idle
            color: Qt.rgba(1, 1, 1, 0.15)
            Rectangle {
                width: parent.width * Math.min(1, Player.shownPosition / Math.max(1, Player.duration))
                height: parent.height
                radius: height / 2
                color: Player.playing ? Theme.gold : Theme.dim
            }
        }
        Text {
            objectName: "coverNext"
            width: parent.width
            visible: text !== ""
            text: cover.idle ? (cover.t ? "Last played" : "Your Navidrome music") : cover.next ? "Next · " + cover.next.title : ""
            color: Theme.faint
            font.pixelSize: cover.box * 0.032
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
