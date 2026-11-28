pragma ComponentBehavior: Bound
import QtQuick

// Results for the search pill in the top bar.
Page {
    id: page
    objectName: "search"
    property string query: ""
    property var result: ({ artists: [], albums: [], songs: [] })
    title: query === "" ? "Search" : "“" + query + "”"
    onQueryChanged: wait.restart()
    Component.onCompleted: wait.restart()
    Timer {
        id: wait
        interval: 250
        onTriggered: page.query === "" ? page.result = { artists: [], albums: [], songs: [] }
                                       : Api.search(page.query, function (r) { if (!page) return; page.result = r; })
    }
    Flow {
        width: parent.width
        spacing: 10
        visible: page.result.artists.length > 0
        Repeater {
            model: page.result.artists
            delegate: TextButton { required property var modelData; icon: "users"; text: modelData.name; onClicked: Nav.openArtist(modelData.id, modelData.name) }
        }
    }
    Shelf { width: parent.width; title: /*% "Albums" */ qsTrId("ryugin-he-albums"); albums: page.result.albums }
    SectionTitle { title: /*% "Songs" */ qsTrId("ryugin-he-songs"); visible: page.result.songs.length > 0 }
    TrackList { width: parent.width; view: page; tracks: page.result.songs; showNumber: false }
    Text {
        visible: page.query !== "" && page.result.artists.length + page.result.albums.length + page.result.songs.length === 0
        text: /*% "Nothing found." */ qsTrId("ryugin-la-nothing_found")
        color: Theme.dim
        font.pixelSize: 14
    }
}
