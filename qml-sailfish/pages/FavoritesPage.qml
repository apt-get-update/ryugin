import QtQuick 2.0
import "../../qml" as R

// The songs liked (starred on Navidrome).
TracksPage {
    id: page

    //% "Favorites"
    title: qsTrId("ryugin-he-favorites")
    //% "No liked songs yet"
    empty: qsTrId("ryugin-la-no_liked_songs_yet")
    Component.onCompleted: R.Api.starredSongs(function (list) {
        if (!page)
            return // gone before Navidrome answered
        page.tracks = list
        page.loaded = true
    })
}
