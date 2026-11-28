pragma ComponentBehavior: Bound
import QtQuick

// Home, fed by Navidrome: recently played, most played and recently added
// (the one-tap plays sit in the toolbar, the library's counts in the sidebar).
Page {
    id: home
    objectName: "home"
    // null until Navidrome answers: the rows keep their place (no jump as they arrive).
    property var recent: null
    property var frequent: null
    property var newest: null

    function load() {
        Api.albumList("recent", 20, 0, function (l) { if (!home) return; home.recent = l; });
        Api.albumList("frequent", 20, 0, function (l) { if (!home) return; home.frequent = l; });
        Api.albumList("newest", 20, 0, function (l) { if (!home) return; home.newest = l; });
    }
    Component.onCompleted: load()
    Connections {
        target: Player
        // Scrobbles change "recently played": refresh after a track starts.
        function onIndexChanged() { refresh.restart(); }
    }
    Timer { id: refresh; interval: 4000; onTriggered: home.load() }
    Connections { target: Api; function onLibraryChanged() { home.load(); } }

    // The rows Settings › Home keeps, in its order.
    readonly property var hints: ({ recentSongs: /*% "Tap a song to play it, the disc for its album" */ qsTrId("ryugin-de-recently_played"), recent: /*% "Albums you played lately" */ qsTrId("ryugin-de-recent_albums"),
                                    frequent: /*% "Your most played albums" */ qsTrId("ryugin-de-most_played"), newest: /*% "New in your library" */ qsTrId("ryugin-de-recently_added") })
    Repeater {
        model: Nav.layout.homeOrder.split(" ").filter(function (k) { return Nav.homeRows[k] && Nav.layout.homeHidden.split(" ").indexOf(k) < 0; })
        delegate: Shelf {
            required property string modelData
            objectName: modelData === "recentSongs" ? "recentSongs" : "shelf"
            width: home.width - 56
            title: Nav.homeRows[modelData]
            subtitle: home.hints[modelData]
            songs: modelData === "recentSongs" ? Player.history : []
            albums: modelData === "recentSongs" ? [] : home[modelData]
        }
    }
}
