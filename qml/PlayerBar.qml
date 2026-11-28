import QtQuick
import QtQuick.Controls

// Bottom bar: the song left (its cover the way to Now Playing, by click or wheel),
// the controls in the middle, time and volume right; the progress runs under them all.
Rectangle {
    id: bar
    height: Nav.phone ? 64 : 80
    color: Theme.panel
    readonly property var t: Player.current

    Rectangle { width: parent.width; height: 1; color: Theme.border }

    // The row above the progress.
    Item { id: line; width: parent.width; height: parent.height - 14 }

    Row {
        id: controls
        objectName: "controls"
        visible: !Nav.phone // a phone keeps play and next, on the right
        // In the middle, unless the window is too narrow for it.
        x: Math.min((parent.width - width) / 2, tools.x - 22 - width)
        anchors.verticalCenter: line.verticalCenter
        spacing: 6
        IconButton { objectName: "shuffle"; icon: Player.settings.shuffle ? "shuffle" : "play-order"; active: Player.settings.shuffle; iconSize: 17; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.toggleShuffle() }
        IconButton { icon: "skip-back"; iconSize: 19; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.previous() }
        Rectangle {
            width: 44
            height: 44
            radius: 22
            anchors.verticalCenter: parent.verticalCenter
            color: playArea.containsMouse ? Theme.bright : Theme.field
            border.color: Theme.border
            Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: Player.playing ? 0 : 1; name: Player.playing ? "pause" : "play"; size: 20; color: Theme.text }
            MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Player.toggle() }
        }
        IconButton { icon: "skip-forward"; iconSize: 19; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.next() }
        IconButton {
            objectName: "repeat"
            icon: "repeat"
            iconSize: 17
            anchors.verticalCenter: parent.verticalCenter
            active: Player.repeat !== "off"
            onClicked: Player.cycleRepeat()
            Text { visible: Player.repeat === "one"; text: "1"; color: Theme.gold; font.pixelSize: 9; anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: 3 }
        }
    }

    Item {
        id: middle
        objectName: "song"
        x: 18
        width: (Nav.phone ? tools.x : controls.x) - 22 - x
        height: line.height

        // The wheel over the song: up opens Now Playing, down closes it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (e) { if (e.angleDelta.y !== 0 && bar.t) Nav.lyrics = e.angleDelta.y > 0; }
        }

        Cover {
            id: art
            width: Nav.phone ? 40 : 46
            height: width
            size: 120
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            coverId: bar.t ? bar.t.cover : ""
            // An invitation to Now Playing: the way up, over the cover.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.45)
                opacity: artArea.containsMouse && bar.t ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Icon { anchors.centerIn: parent; name: "chevron-up"; size: 22; color: "#ffffff" }
            }
            MouseArea {
                id: artArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Nav.lyrics = !Nav.lyrics
                ToolTip.visible: containsMouse && !!bar.t
                ToolTip.text: /*% "Now playing (Ctrl+L)" */ qsTrId("ryugin-la-now_playing_ctrl_l")
                ToolTip.delay: 500
            }
        }
        Column {
            anchors.left: art.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Row {
                width: parent.width
                spacing: 6
                Text { text: bar.t ? bar.t.title : ""; color: Theme.text; font.pixelSize: 14; elide: Text.ElideRight; width: Math.min(implicitWidth, parent.width - 40); anchors.verticalCenter: parent.verticalCenter }
                IconButton { icon: bar.t && bar.t.starred ? "heart-fill" : "heart"; iconSize: 15; active: bar.t !== null && bar.t.starred; visible: bar.t !== null; onClicked: Player.toggleStar(); anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                width: parent.width
                text: bar.t ? bar.t.artist : ""
                color: Theme.dim
                font.pixelSize: 12
                elide: Text.ElideRight
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (bar.t) Nav.openArtist(bar.t.artistId, bar.t.artist) }
            }
        }
    }

    GoldSlider {
        id: progress
        objectName: "progress"
        x: 12
        width: parent.width - 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        from: 0
        to: Math.max(1, Player.duration)
        // Follow the song, except while dragged; seek on release.
        Binding on value { value: Player.shownPosition; when: !progress.pressed; restoreMode: Binding.RestoreNone }
        onPressedChanged: if (!pressed) Player.seek(value)
    }

    Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: Nav.phone ? 8 : 18
        anchors.verticalCenter: line.verticalCenter
        spacing: 6
        IconButton { visible: Nav.phone; icon: Player.playing ? "pause" : "play"; iconSize: 22; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.toggle() }
        IconButton { visible: Nav.phone; icon: "skip-forward"; iconSize: 20; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.next() }
        Text {
            visible: !Nav.phone
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 8
            text: Theme.time(progress.value / 1000) + " / " + Theme.time(Player.duration / 1000)
            color: Theme.dim
            font.pixelSize: 12
        }
        IconButton {
            id: mute
            visible: !Nav.phone
            property real before: 0.8
            anchors.verticalCenter: parent.verticalCenter
            icon: Player.settings.volume > 0 ? "volume-2" : "volume-x"
            iconSize: 18
            onClicked: {
                if (Player.settings.volume > 0) { before = Player.settings.volume; Player.setVolume(0); }
                else Player.setVolume(before);
            }
            // Wheel: volume; middle click: mute, as a left click.
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.MiddleButton; onClicked: mute.clicked(); onWheel: function (e) { Player.wheelVolume(e); } }
        }
        GoldSlider {
            objectName: "volume"
            visible: !Nav.phone // a phone has its volume keys
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 1
            value: Player.settings.volume
            onMoved: Player.setVolume(value)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: function (e) { Player.wheelVolume(e); } }
        }
        // The queue: the sidebar opens it on a desktop.
        IconButton { visible: Nav.phone; icon: "list-ordered"; iconSize: 18; active: Nav.queue; anchors.verticalCenter: parent.verticalCenter; onClicked: Nav.queue = !Nav.queue }
    }
}
