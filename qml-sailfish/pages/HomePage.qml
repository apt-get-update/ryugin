import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// One tap to play (50 random songs, the library's radio), then the library's
// sections, as Jolla's Media player lists them, the songs played lately, the albums added
// lately (new music, to play at once), played lately and the most played.
Page {
    id: page

    property var recent: []
    property var frequent: []
    property var newest: []

    function load() {
        R.Api.albumList("recent", 20, 0, function (l) { page.recent = l })
        R.Api.albumList("frequent", 20, 0, function (l) { page.frequent = l })
        R.Api.albumList("newest", 20, 0, function (l) { page.newest = l })
    }

    Component.onCompleted: load()

    Connections {
        target: R.Api

        function onLibraryChanged() { page.load() }
        function onConfiguredChanged() { page.load() }
    }

    SilicaFlickable {
        anchors.fill: parent
        // With room for the player docked over its end (the pull-down menu owns bottomMargin).
        contentHeight: column.height + Theme.paddingLarge + (R.Player.current ? Theme.itemSizeLarge : 0)

        Pulley {
            MenuItem {
                text: "Settings"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Search"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("SearchPage.qml"))
            }
        }

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: "Ryūgin"
            }

            SectionHeader {
                text: "Play"
            }
            Repeater {
                model: [
                    { name: "Feeling lucky", hint: "50 random songs", icon: "image://theme/icon-m-shuffle",
                      run: function () { R.Api.randomSongs(50, function (l) { R.Player.play(l, 0) }) } },
                    { name: "Library radio", hint: "500 random songs", icon: "image://theme/icon-m-media-radio",
                      run: function () { R.Api.randomSongs(500, function (l) { R.Player.play(l, 0) }) } }
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
                text: "Library"
            }

            Repeater {
                model: [
                    { name: "Albums", icon: "image://theme/icon-m-media-albums", page: "AlbumsPage.qml" },
                    { name: "Artists", icon: "image://theme/icon-m-media-artists", page: "ArtistsPage.qml" },
                    { name: "Playlists", icon: "image://theme/icon-m-media-playlists", page: "PlaylistsPage.qml" },
                    { name: "Favorites", icon: "image://theme/icon-m-favorite", page: "FavoritesPage.qml" }
                ]

                delegate: BackgroundItem {
                    id: section

                    width: column.width
                    height: Theme.itemSizeSmall
                    enabled: R.Api.configured
                    onClicked: pageStack.animatorPush(Qt.resolvedUrl(modelData.page))

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
                            verticalCenter: parent.verticalCenter
                        }
                        color: section.highlighted ? palette.highlightColor : palette.primaryColor
                        text: modelData.name
                    }
                }
            }

            Shelf {
                title: "Recently played"
                songs: R.Player.history
            }
            Shelf {
                title: "Recently added"
                albums: page.newest
            }
            Shelf {
                title: "Recent albums"
                albums: page.recent
            }
            Shelf {
                title: "Most played"
                albums: page.frequent
            }
        }

        ViewPlaceholder {
            enabled: !R.Api.configured
            text: "No Navidrome server"
            hintText: "Pull down for Settings"
        }

        VerticalScrollDecorator {}
    }
}
