import QtQuick 2.0
import "../../qml" as R

// The songs liked (starred on Navidrome).
TracksPage {
    id: page

    title: "Favorites"
    empty: "No liked songs yet"
    Component.onCompleted: R.Api.starredSongs(function (list) {
        page.tracks = list
        page.loaded = true
    })
}
