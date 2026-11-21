pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

// A titled row of albums, or of songs.
Column {
    id: shelf
    property alias title: head.title
    property alias subtitle: head.subtitle
    property var albums: [] // null: still loading, empty cards hold the place
    property var songs: []
    readonly property bool loading: albums === null
    spacing: 14
    visible: loading || albums.length + songs.length > 0
    SectionTitle { id: head }
    ListView {
        width: parent.width
        height: 168 + 60
        orientation: ListView.Horizontal
        spacing: 18
        clip: true
        model: shelf.songs.length ? shelf.songs : shelf.loading ? 8 : shelf.albums
        delegate: AlbumCard {
            required property var modelData
            album: shelf.songs.length || shelf.loading ? null : modelData
            song: shelf.songs.length ? modelData : null
            songs: shelf.songs
        }
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.horizontal: Scroller {}
    }
}
