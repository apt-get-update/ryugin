pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

// Every album, by name, in a grid that loads covers as you scroll.
Item {
    id: page
    property var albums: []
    function load() { Api.allAlbums(function (l) { if (!page) return; page.albums = l; }); }
    Component.onCompleted: load()
    Connections { target: Api; function onLibraryChanged() { page.load(); } }
    Text {
        x: 28
        y: 8
        text: "Albums"
        color: Theme.text
        font.pixelSize: 30
        font.weight: Font.Bold
    }
    GridView {
        id: grid
        objectName: "albumGrid"
        anchors.fill: parent
        anchors.topMargin: 64
        anchors.leftMargin: 28
        // A phone: cards of 150 px or more, at least two (upright, the Jolla Phone's 354 px
        // gave one with half the width empty); four on its side.
        readonly property int columns: Nav.phone ? Math.max(2, Math.floor((width - 28) / 150)) : Math.max(1, Math.floor((width - 28) / 190))
        cellWidth: (width - 28) / columns
        // The gap between rows is the one between cards: a card, its two title lines (as
        // AlbumCard draws them, in this system's font), a gap.
        readonly property real card: Math.min(168, cellWidth - (Nav.phone ? 14 : 22))
        readonly property real titles: 10 + titleLine.height + 3 + artistLine.height
        cellHeight: card + titles + (cellWidth - card)
        Text { id: titleLine; visible: false; text: "Ag"; font.pixelSize: 14 }
        Text { id: artistLine; visible: false; text: "Ag"; font.pixelSize: 12 }
        clip: true
        model: page.albums
        delegate: AlbumCard { required property var modelData; album: modelData; width: grid.card }
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Scroller {}
    }
}
