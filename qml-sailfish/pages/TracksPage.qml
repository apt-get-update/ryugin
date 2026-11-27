import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// A list of songs under a title (a playlist, the favorites). Pull down to play or queue
// them (shuffle: the player's push-up menu). Pages that use it set title and load.
Page {
    id: page

    property string title
    property string empty
    property var tracks: []
    property bool loaded

    SilicaListView {
        anchors.fill: parent
        // Room for the player docked over its end (the pull-down menu owns bottomMargin).
        footer: Item {
            width: 1
            height: R.Player.current ? Theme.itemSizeLarge : 0
        }
        model: page.tracks

        Pulley {
            enabled: page.tracks.length > 0

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

        header: PageHeader {
            title: page.title
            //% "%n songs"
            description: page.loaded ? qsTrId("ryugin-la-n_songs", page.tracks.length) : ""
        }

        delegate: TrackItem {
            tracks: page.tracks
            index: model.index
        }

        ViewPlaceholder {
            enabled: page.loaded && page.tracks.length === 0
            text: page.empty
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: !page.loaded
        }

        VerticalScrollDecorator {}
    }
}
