pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// A titled row of albums, or of songs.
Column {
    id: shelf
    property alias title: head.title
    property alias subtitle: head.subtitle
    property var albums: [] // null: still loading, empty cards hold the place
    property var songs: []
    readonly property bool loading: albums === null
    readonly property int card: Nav.phone ? 168 : 124 // a desktop: smaller, more to see
    spacing: 14
    visible: loading || albums.length + songs.length > 0
    SectionTitle { id: head }
    ListView {
        width: parent.width
        height: shelf.card + 60
        orientation: ListView.Horizontal
        spacing: Nav.phone ? 18 : 14
        clip: true
        model: shelf.songs.length ? shelf.songs : shelf.loading ? 8 : shelf.albums
        delegate: AlbumCard {
            required property var modelData
            width: shelf.card
            album: shelf.songs.length || shelf.loading ? null : modelData
            song: shelf.songs.length ? modelData : null
            songs: shelf.songs
        }
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.horizontal: Scroller { policy: more ? C.ScrollBar.AsNeeded : C.ScrollBar.AlwaysOff } // only while scrolled: no line under each row
    }
}
