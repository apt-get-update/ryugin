import QtQuick

// Bottom bar, as in SPlayer-Next: controls left, the track in the middle with its
// progress, then time, volume, lyrics and queue. Click the cover for the lyrics.
Rectangle {
    id: bar
    height: Nav.phone ? 64 : 80
    color: Theme.panel
    readonly property var t: Player.current

    Rectangle { width: parent.width; height: 1; color: Theme.border }

    Row {
        id: controls
        x: 18
        visible: !Nav.phone // a phone keeps play and next, on the right
        width: visible ? implicitWidth : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        IconButton { icon: "shuffle"; iconSize: 17; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.shuffleRest() }
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
        anchors.left: controls.right
        anchors.leftMargin: Nav.phone ? 0 : 22
        anchors.right: tools.left
        anchors.rightMargin: 22
        height: parent.height

        Cover {
            id: art
            width: 46
            height: 46
            size: 120
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            coverId: bar.t ? bar.t.cover : ""
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Nav.lyrics = !Nav.lyrics }
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
                IconButton { icon: "star"; iconSize: 15; active: bar.t !== null && bar.t.starred; visible: bar.t !== null; onClicked: Player.toggleStar(); anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                width: parent.width
                text: bar.t ? bar.t.artist : ""
                color: Theme.dim
                font.pixelSize: 12
                elide: Text.ElideRight
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (bar.t) Nav.openArtist(bar.t.artistId, bar.t.artist) }
            }
            GoldSlider {
                id: progress
                objectName: "progress"
                width: parent.width
                from: 0
                to: Math.max(1, Player.duration)
                // Follow the song, except while dragged; seek on release.
                Binding on value { value: Player.shownPosition; when: !progress.pressed; restoreMode: Binding.RestoreNone }
                onPressedChanged: if (!pressed) Player.seek(value)
            }
        }
    }

    Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: Nav.phone ? 8 : 18
        anchors.verticalCenter: parent.verticalCenter
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
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: function (e) { Player.wheelVolume(e); } }
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
        IconButton { visible: !Nav.phone; icon: "mic-vocal"; iconSize: 18; active: Nav.lyrics; anchors.verticalCenter: parent.verticalCenter; onClicked: Nav.lyrics = !Nav.lyrics }
        IconButton { icon: "list-music"; iconSize: 18; active: Nav.queue; anchors.verticalCenter: parent.verticalCenter; onClicked: Nav.queue = !Nav.queue }
    }
}
