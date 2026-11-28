import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// One tap to play (50 random songs, the library's radio, the liked songs), then the
// library's sections with their counts, as Jolla's Media player lists them, then the rows
// Settings › Home shows: the songs played lately, the albums added lately (new music, to
// play at once), played lately and the most played.
Page {
    id: page

    property var recent: []
    property var frequent: []
    property var newest: []
    property var counts: ({}) // Library row -> its count, as Navidrome answers

    function load() {
        R.Api.albumList("recent", 20, 0, function (l) { page.recent = l })
        R.Api.albumList("frequent", 20, 0, function (l) { page.frequent = l })
        R.Api.albumList("newest", 20, 0, function (l) { page.newest = l })
        var add = function (more) { page.counts = Object.assign({}, page.counts, more) }
        R.Api.artists(function (l) {
            add({ ArtistsPage: l.length, AlbumsPage: l.reduce(function (n, a) { return n + a.albumCount }, 0) })
        })
        R.Api.playlists(function (l) { add({ PlaylistsPage: l.length }) })
        R.Api.starredSongs(function (l) { add({ FavoritesPage: l.length }) })
    }
    // A row Settings › Home hides.
    function shown(key) {
        return R.Nav.layout.homeHidden.split(" ").indexOf(key) < 0
    }

    Component.onCompleted: load()

    Connections {
        target: R.Api

        function onLibraryChanged() { page.load() }
        function onConfiguredChanged() { page.load() }
        function onPlaylistsChanged() { page.load() }
    }
    Connections {
        target: R.Player

        // Scrobbles change Recent albums and Most played: refresh after a song starts, as
        // the desktop's Home.
        function onIndexChanged() { refresh.restart() }
        // A song liked or unliked: the Favorites count.
        function onLiked() { R.Api.starredSongs(function (l) { page.counts = Object.assign({}, page.counts, { FavoritesPage: l.length }) }) }
    }

    Timer {
        id: refresh

        interval: 4000
        onTriggered: page.load()
    }

    SilicaFlickable {
        anchors.fill: parent
        // With room for the player docked over its end (the pull-down menu owns bottomMargin).
        contentHeight: column.height + Theme.paddingLarge + (R.Player.current ? Theme.itemSizeLarge : 0)

        Pulley {
            MenuItem {
                //% "Settings"
                text: qsTrId("ryugin-me-settings")
                onClicked: R.Nav.open("SettingsPage")
            }
            MenuItem {
                //% "Search"
                text: qsTrId("ryugin-me-search")
                onClicked: R.Nav.open("SearchPage")
            }
        }

        Column {
            id: column

            visible: R.Api.configured // none: the placeholder alone
            width: parent.width

            PageHeader {
                title: "Ryūgin"
            }

            SectionHeader {
                //% "Play"
                text: qsTrId("ryugin-he-play")
            }
            Repeater {
                model: [
                    //% "Roll the dice"
                    { name: qsTrId("ryugin-la-roll_the_dice"),
                      //% "%n random songs"
                      hint: qsTrId("ryugin-de-n_random_songs", 50),
                      icon: R.Icons.silica("dices", Theme.iconSizeMedium, Theme.primaryColor),
                      run: function () { R.Api.randomSongs(50, function (l) { R.Player.play(l, 0) }) } },
                    //% "Library radio"
                    { name: qsTrId("ryugin-la-library_radio"),
                      //% "%n random songs"
                      hint: qsTrId("ryugin-de-n_random_songs", 500),
                      icon: "image://theme/icon-m-media-radio",
                      run: function () { R.Api.randomSongs(500, function (l) { R.Player.play(l, 0) }) } },
                    //% "Heartbeat"
                    { name: qsTrId("ryugin-la-heartbeat"),
                      //% "Your favorites, at random"
                      hint: qsTrId("ryugin-de-favorites_at_random"),
                      icon: R.Icons.silica("heartbeat", Theme.iconSizeMedium, Theme.primaryColor),
                      run: function () { R.Api.starredSongs(function (l) { R.Player.playMixed(l) }) } },
                    //% "Karaoke"
                    { name: qsTrId("ryugin-la-karaoke"),
                      //% "Songs to sing"
                      hint: qsTrId("ryugin-de-songs_to_sing"),
                      icon: "image://theme/icon-m-mic",
                      run: function () { R.Api.allSongs(function (l) { R.Player.playKaraoke(l) }) } }
                ]

                delegate: BackgroundItem {
                    id: action

                    width: column.width
                    height: Theme.itemSizeMedium
                    enabled: R.Api.configured
                    onClicked: modelData.run()

                    Icon {
                        id: actionIcon

                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        source: modelData.icon
                        highlighted: action.highlighted
                    }
                    Column {
                        anchors {
                            left: actionIcon.right
                            leftMargin: Theme.paddingLarge
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }

                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            color: action.highlighted ? palette.highlightColor : palette.primaryColor
                            text: modelData.name
                        }
                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: action.highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
                            text: modelData.hint
                        }
                    }
                }
            }

            SectionHeader {
                //% "Library"
                text: qsTrId("ryugin-he-library")
            }

            Repeater {
                model: [
                    //% "Albums"
                    { name: qsTrId("ryugin-la-albums"), icon: "image://theme/icon-m-media-albums", page: "AlbumsPage" },
                    //% "Artists"
                    { name: qsTrId("ryugin-la-artists"), icon: "image://theme/icon-m-media-artists", page: "ArtistsPage" },
                    //% "Playlists"
                    { name: qsTrId("ryugin-la-playlists"), icon: "image://theme/icon-m-media-playlists", page: "PlaylistsPage" },
                    //% "Favorites"
                    { name: qsTrId("ryugin-la-favorites"), icon: R.Icons.silica("heart", Theme.iconSizeMedium, Theme.primaryColor), page: "FavoritesPage" }
                ]

                delegate: BackgroundItem {
                    id: section

                    width: column.width
                    height: Theme.itemSizeSmall
                    enabled: R.Api.configured
                    onClicked: R.Nav.open(modelData.page)

                    Icon {
                        id: icon

                        anchors {
                            left: parent.left
                            leftMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        source: modelData.icon
                        highlighted: section.highlighted
                    }
                    Label {
                        anchors {
                            left: icon.right
                            leftMargin: Theme.paddingLarge
                            right: count.left
                            rightMargin: Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                        truncationMode: TruncationMode.Fade
                        color: section.highlighted ? palette.highlightColor : palette.primaryColor
                        text: modelData.name
                    }
                    Label {
                        id: count

                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: section.highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
                        text: page.counts[modelData.page] || ""
                    }
                }
            }

            Shelf {
                shown: page.shown("recentSongs")
                //% "Recently played"
                title: qsTrId("ryugin-he-recently_played")
                songs: R.Player.history
            }
            Shelf {
                shown: page.shown("newest")
                //% "Recently added"
                title: qsTrId("ryugin-he-recently_added")
                albums: page.newest
            }
            Shelf {
                shown: page.shown("recent")
                //% "Recent albums"
                title: qsTrId("ryugin-he-recent_albums")
                albums: page.recent
            }
            Shelf {
                shown: page.shown("frequent")
                //% "Most played"
                title: qsTrId("ryugin-he-most_played")
                albums: page.frequent
            }
        }

        ViewPlaceholder {
            enabled: !R.Api.configured
            //% "No Navidrome server"
            text: qsTrId("ryugin-la-no_navidrome_server")
            //% "Pull down for Settings"
            hintText: qsTrId("ryugin-de-pull_down")
        }

        VerticalScrollDecorator {}
    }
}
