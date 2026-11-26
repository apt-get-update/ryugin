import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// Navidrome's playlists.
Page {
    id: page

    property var playlists: []
    property bool loaded

    Component.onCompleted: R.Api.playlists(function (list) {
        page.playlists = list
        page.loaded = true
    })

    SilicaListView {
        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        model: page.playlists

        header: PageHeader {
            title: "Playlists"
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeMedium
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("PlaylistPage.qml"), { playlistId: modelData.id, name: modelData.name })

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
                    text: modelData.songCount + " songs"
                }
            }
        }

        ViewPlaceholder {
            enabled: page.loaded && page.playlists.length === 0
            text: "No playlists"
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: !page.loaded
        }

        VerticalScrollDecorator {}
    }
}
