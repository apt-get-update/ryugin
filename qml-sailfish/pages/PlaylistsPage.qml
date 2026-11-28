import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// Navidrome's playlists; a long press deletes one (with time to undo).
Page {
    id: page

    property var playlists: []
    property bool loaded

    function load() {
        R.Api.playlists(function (list) {
            if (!page)
                return // gone before Navidrome answered
            page.playlists = list
            page.loaded = true
        })
    }

    Component.onCompleted: load()

    Connections {
        target: R.Api

        function onPlaylistsChanged() { page.load() }
    }

    SilicaListView {
        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        model: page.playlists

        header: PageHeader {
            //% "Playlists"
            title: qsTrId("ryugin-he-playlists")
        }

        delegate: ListItem {
            id: item

            contentHeight: Theme.itemSizeMedium
            onClicked: R.Nav.openPlaylist(modelData.id, modelData.name)

            menu: Component {
                ContextMenu {
                    MenuItem {
                        text: qsTrId("ryugin-me-play")
                        onClicked: R.Api.getPlaylist(modelData.id, function (list) { R.Player.play(list, 0) })
                    }
                    MenuItem {
                        //% "Delete"
                        text: qsTrId("ryugin-me-delete")
                        onClicked: {
                            var id = modelData.id
                            item.remorseDelete(function () { R.Api.deletePlaylist(id) })
                        }
                    }
                }
            }

            Image {
                id: art

                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                width: Theme.itemSizeMedium - 2 * Theme.paddingSmall
                height: width
                sourceSize {
                    width: width
                    height: height
                }
                fillMode: Image.PreserveAspectCrop
                source: R.Api.cover(modelData.cover, 128)
            }
            Column {
                anchors {
                    left: art.right
                    leftMargin: Theme.paddingLarge
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    color: highlighted ? palette.highlightColor : palette.primaryColor
                    text: modelData.name
                }
                Label {
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: palette.secondaryColor
                    //% "%n songs"
                    text: qsTrId("ryugin-la-n_songs", modelData.songCount)
                }
            }
        }

        ViewPlaceholder {
            enabled: page.loaded && page.playlists.length === 0
            //% "No playlists"
            text: qsTrId("ryugin-la-no_playlists")
        }

        PageBusyIndicator {
            running: !page.loaded
        }

        VerticalScrollDecorator {}
    }
}
