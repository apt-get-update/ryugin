import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// One album, as the Media player shows one: its cover edge to edge, its name, its tracks.
// Pull down to play or queue it (shuffle: the player's push-up menu).
Page {
    id: page

    property string albumId
    property var album: null
    property var tracks: []
    readonly property bool hidden: album !== null && R.Api.hidden[album.id] !== undefined

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
                visible: page.album !== null
                text: page.hidden
                      //% "Show album"
                      ? qsTrId("ryugin-me-show_album")
                      //% "Hide album"
                      : qsTrId("ryugin-me-hide_album")
                onClicked: R.Api.hide(page.album, !page.hidden)
            }
            MenuItem {
                visible: page.album !== null && page.album.artistId !== ""
                //% "Go to artist"
                text: qsTrId("ryugin-me-go_to_artist")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("ArtistPage.qml"), { artistId: page.album.artistId, name: page.album.artist })
            }
            MenuItem {
                //% "Add to queue"
                text: qsTrId("ryugin-me-add_to_queue")
                onClicked: R.Player.enqueue(page.tracks)
            }
            MenuItem {
                //% "Play"
                text: qsTrId("ryugin-me-play")
                onClicked: R.Player.play(page.tracks, 0)
            }
        }

        header: Column {
            width: list.width

            Image {
                width: parent.width
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
                topPadding: Theme.paddingLarge
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: palette.highlightColor
                text: page.album ? page.album.title : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                truncationMode: TruncationMode.Fade
                color: palette.secondaryHighlightColor
                text: page.album ? page.album.artist : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                topPadding: Theme.paddingMedium
                bottomPadding: Theme.paddingMedium
                font.pixelSize: Theme.fontSizeExtraSmall
                color: palette.secondaryHighlightColor
                //% "%n songs"
                text: page.album ? [page.album.year || "", qsTrId("ryugin-la-n_songs", page.tracks.length), R.Theme.time(page.album.duration)]
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
