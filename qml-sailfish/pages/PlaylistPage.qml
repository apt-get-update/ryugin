import QtQuick 2.0
import "../../qml" as R

// One playlist's songs.
TracksPage {
    id: page

    property string playlistId
    property string name

    title: name
    //% "Empty playlist"
    empty: qsTrId("ryugin-la-empty_playlist")
    Component.onCompleted: R.Api.getPlaylist(playlistId, function (list) {
        page.tracks = list
        page.loaded = true
    })
}
