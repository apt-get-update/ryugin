import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// One album: its cover and tracks. Pull down to play, shuffle or queue it.
Page {
    id: page

    property string albumId
    property var album: null
    property var tracks: []

    Component.onCompleted: R.Api.getAlbum(albumId, function (a, t) {
        page.album = a
        page.tracks = t
    })

    SilicaListView {
        id: list

        anchors.fill: parent
        // Room for the player docked over its end (the pull-down menu owns bottomMargin).
        footer: Item {
            width: 1
            height: R.Player.current ? Theme.itemSizeLarge : 0
        }
        model: page.tracks

        Pulley {
            MenuItem {
                visible: page.album !== null && page.album.artistId !== ""
                text: "Go to artist"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("ArtistPage.qml"), { artistId: page.album.artistId, name: page.album.artist })
            }
            MenuItem {
                text: "Add to queue"
                onClicked: R.Player.enqueue(page.tracks)
            }
            MenuItem {
                text: "Shuffle"
                onClicked: R.Player.shuffle(page.tracks)
            }
            MenuItem {
                text: "Play"
                onClicked: R.Player.play(page.tracks, 0)
            }
        }

        header: Column {
            width: list.width

            PageHeader {
                title: page.album ? page.album.title : ""
                description: page.album ? page.album.artist : ""
            }
            Image {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: width
                sourceSize {
                    width: width
                    height: height
                }
                fillMode: Image.PreserveAspectCrop
                source: page.album ? R.Api.cover(page.album.cover, 720) : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                topPadding: Theme.paddingMedium
                bottomPadding: Theme.paddingMedium
                font.pixelSize: Theme.fontSizeExtraSmall
                color: palette.secondaryHighlightColor
                text: page.album ? [page.album.year || "", page.tracks.length + " tracks", R.Theme.time(page.album.duration)]
                                   .filter(function (x) { return x !== "" }).join("  ·  ") : ""
            }
        }

        delegate: TrackItem {
            tracks: page.tracks
            index: model.index
            showNumber: true
            showArtist: page.album !== null && modelData.artist !== page.album.artist
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.album === null
        }

        VerticalScrollDecorator {}
    }
}
