import QtQuick

// Click the cover to open the album; ▶ (always shown on a phone) plays: the whole album, or
// with a song (recently played) the songs from it. A double-click on an album plays it too.
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
            onClicked: card.song ? Nav.openAlbum(card.song.albumId) : single.restart()
            onDoubleClicked: if (!card.song) { single.stop(); card.playAlbum(); }
        }
        Timer { id: single; interval: 220; onTriggered: Nav.openAlbum(card.album.id) }
        // ▶: sumi ink with a gold ring, as kintsugi; gold fills it under the mouse. It only
        // fades in: the cover already moves.
        Rectangle {
            id: playButton
            readonly property bool shown: card.item !== null && (Nav.phone || area.containsMouse || play.containsMouse) // no hover on a phone
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: Nav.phone ? 42 : 36
            height: width
            radius: width / 2
            color: play.containsMouse ? Theme.gold : Qt.rgba(0, 0, 0, 0.55)
            border.width: 1.5
            border.color: Theme.alpha(Theme.gold, play.containsMouse ? 1 : 0.85)
            objectName: "playAlbum"
            opacity: shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play-fill"; size: Nav.phone ? 18 : 15; color: play.containsMouse ? Theme.goldInk : Theme.gold }
            MouseArea {
                id: play
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.song ? card.playSongs() : card.playAlbum()
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
