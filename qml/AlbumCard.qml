import QtQuick

// Click the cover to open the album; ▶ (always shown on a phone) or a double-click plays
// the whole album. With a song (recently played): a click plays songs from it, the disc
// button plays its album from it.
Item {
    id: card
    property var album
    property var song: null
    property var songs: [song]
    readonly property var item: song || album
    function playSongs() {
        Player.play(songs, Math.max(0, songs.findIndex(function (s) { return s.id === song.id; })));
    }
    // The whole album, in order (from the song).
    function playAlbum() {
        Api.getAlbum(song ? song.albumId : album.id, function (a, tracks) {
            const i = song ? tracks.findIndex(function (t) { return t.id === song.id; }) : 0;
            Player.play(tracks, Math.max(0, i));
        });
    }
    width: 168
    height: width + 52
    enabled: item !== null // an empty card, while its row loads

    Cover {
        id: art
        width: card.width
        height: card.width
        size: Api.albumCover
        coverId: card.item ? card.item.cover : ""
        scale: area.containsMouse || play.containsMouse ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // A single click waits a moment, so a double-click can play instead.
            onClicked: card.song ? card.playSongs() : single.restart()
            onDoubleClicked: if (!card.song) { single.stop(); card.playAlbum(); }
        }
        Timer { id: single; interval: 220; onTriggered: Nav.openAlbum(card.album.id) }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: 42
            height: 42
            radius: 21
            color: play.containsMouse ? Qt.lighter(Theme.gold, 1.1) : Theme.gold
            objectName: "playAlbum"
            opacity: card.item && (Nav.phone || area.containsMouse || play.containsMouse) ? 1 : 0 // no hover on a phone
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: card.song ? "disc-3" : "play"; size: 18; color: Theme.goldInk }
            MouseArea {
                id: play
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.playAlbum()
            }
        }
    }
    Text {
        id: title
        anchors.top: art.bottom
        anchors.topMargin: 10
        width: card.width
        text: card.item ? card.item.title : ""
        color: Theme.text
        font.pixelSize: 14
        elide: Text.ElideRight
    }
    Text {
        anchors.top: title.bottom
        anchors.topMargin: 3
        width: card.width
        text: card.item ? card.item.artist : ""
        color: Theme.dim
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
