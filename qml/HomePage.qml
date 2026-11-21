pragma ComponentBehavior: Bound
import QtQuick

// SPlayer-Next's home, fed by Navidrome: greeting and stats, quick plays, then
// recently played, most played, favorites and recently added (like Castafiore).
Page {
    id: home
    // null until Navidrome answers: the rows keep their place (no jump as they arrive).
    property var recent: null
    property var frequent: null
    property var starred: null
    property var newest: null
    property int songs: 0
    property int favorites: 0

    function load() {
        Api.albumList("recent", 20, 0, function (l) { if (!home) return; home.recent = l; });
        Api.albumList("frequent", 20, 0, function (l) { if (!home) return; home.frequent = l; });
        Api.albumList("starred", 20, 0, function (l) { if (!home) return; home.starred = l; });
        Api.albumList("newest", 20, 0, function (l) { if (!home) return; home.newest = l; });
        Api.songCount(function (n) { if (!home) return; home.songs = n; });
        Api.starredSongs(function (l) { if (!home) return; home.favorites = l.length; });
    }
    Component.onCompleted: load()
    Connections {
        target: Player
        // Scrobbles change "recently played": refresh after a track starts.
        function onIndexChanged() { refresh.restart(); }
    }
    Timer { id: refresh; interval: 4000; onTriggered: home.load() }
    Connections { target: Api; function onLibraryChanged() { home.load(); } }

    // Greeting and stats (under it on a phone)
    Item {
        width: parent.width
        height: Nav.phone ? greeting.height + 16 + stats.height : 70
        Column {
            id: greeting
            objectName: "greeting"
            spacing: 8
            Text {
                text: {
                    const h = new Date().getHours();
                    return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
                }
                color: Theme.text
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Text {
                text: Player.history.length ? "What to play today? Pick up your " + Player.history.length + " recently played" : "Your Navidrome library"
                color: Theme.dim
                opacity: 0.8
                font.pixelSize: 13
            }
        }
        Row {
            id: stats
            objectName: "stats"
            x: Nav.phone ? 0 : parent.width - width
            y: Nav.phone ? greeting.height + 16 : 0
            spacing: 28
            Repeater {
                model: [
                    { value: home.songs, unit: "songs", label: "library" },
                    { value: home.favorites, unit: "songs", label: "favorites" },
                    { value: home.newest ? home.newest.length : 0, unit: "albums", label: "recently added" }
                ]
                delegate: Column {
                    id: stat
                    required property var modelData
                    spacing: 2
                    Row {
                        anchors.right: parent.right
                        spacing: 3
                        Text { text: stat.modelData.value; color: Theme.text; font.pixelSize: 24; font.weight: Font.Bold }
                        Text { text: stat.modelData.unit; color: Theme.dim; font.pixelSize: 12; anchors.baseline: parent.children[0].baseline }
                    }
                    Text { anchors.right: parent.right; text: stat.modelData.label; color: Theme.faint; font.pixelSize: 11 }
                }
            }
        }
    }

    // Quick plays
    Grid {
        id: quick
        width: parent.width
        columns: Nav.phone ? 2 : 4
        spacing: 12
        readonly property real cell: (width - (columns - 1) * spacing) / columns
        Repeater {
            model: [
                { icon: "dices", title: "Feeling lucky", desc: "50 random songs", run: function () { Api.randomSongs(50, function (l) { Player.play(l, 0); }); } },
                { icon: "star", title: "Favorites", desc: "Your starred songs", run: function () { Api.starredSongs(function (l) { Player.shuffle(l); }); } },
                { icon: "radio", title: "Library radio", desc: "Shuffle 500 songs", run: function () { Api.randomSongs(500, function (l) { Player.play(l, 0); }); } },
                { icon: "mic-vocal", title: "Lyrics", desc: "Sing along", run: function () { Nav.lyrics = true; } }
            ]
            delegate: Card {
                id: quickCard
                required property var modelData
                width: quick.cell
                height: 64
                hoverable: true
                onClicked: quickCard.modelData.run()
                Rectangle {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: Theme.radius
                    color: Theme.goldSoft
                    Icon { anchors.centerIn: parent; name: quickCard.modelData.icon; size: 19; color: Theme.gold }
                }
                Column {
                    x: 64
                    width: parent.width - 76
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { width: parent.width; text: quickCard.modelData.title; color: Theme.text; font.pixelSize: 14; elide: Text.ElideRight }
                    Text { width: parent.width; text: quickCard.modelData.desc; color: Theme.faint; font.pixelSize: 12; elide: Text.ElideRight }
                }
            }
        }
    }

    Shelf { objectName: "recentSongs"; width: parent.width; title: "Recently played"; subtitle: "Tap a song to play it, the disc for its album"; songs: Player.history }
    Shelf { objectName: "shelf"; width: parent.width; title: "Recent albums"; subtitle: "Albums you played lately"; albums: home.recent }
    Shelf { objectName: "shelf"; width: parent.width; title: "Most played"; subtitle: "Your most played albums"; albums: home.frequent }
    Shelf { objectName: "shelf"; width: parent.width; title: "Favorites"; subtitle: "Albums you starred"; albums: home.starred }
    Shelf { objectName: "shelf"; width: parent.width; title: "Recently added"; subtitle: "New in your library"; albums: home.newest }
}
