import QtQuick

// One album: play it, queue it, or start from any track (shuffle: the player's play order).
Page {
    id: page
    property string albumId
    property var album: null
    property var tracks: []
    readonly property bool hidden: album !== null && Api.hidden[album.id] !== undefined
    Component.onCompleted: Api.getAlbum(albumId, function (a, t) { if (!page) return; page.album = a; page.tracks = t; })

    Flow { // a phone puts the data under the cover
        width: parent.width
        spacing: 28
        Item {
            width: Nav.phone ? Math.min(parent.width, 300) : 230
            height: width
            Shadow { anchors.fill: art; radius: art.radius; blur: 30; offset.y: 10; color: Qt.rgba(0, 0, 0, 0.45) }
            Cover { id: art; anchors.fill: parent; size: 460; radius: Theme.radiusXl; coverId: page.album ? page.album.cover : "" }
        }
        Item { // the data at the cover's foot (under it on a phone)
            width: info.width
            height: Nav.phone ? info.height : 230
            Column {
                id: info
                anchors.bottom: parent.bottom
                spacing: 10
                Text { text: /*% "Album" */ qsTrId("ryugin-la-album"); color: Theme.faint; font.pixelSize: 12 }
                Text {
                    width: Nav.phone ? page.width - 56 : page.width - 56 - 259
                    text: page.album ? page.album.title : ""
                    color: Theme.text
                    font.pixelSize: 34
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    text: page.album ? page.album.artist : ""
                    color: Theme.gold
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Nav.openArtist(page.album.artistId, page.album.artist) }
                }
                Text {
                    text: page.album ? [page.album.year || "", /*% "%n songs" */ qsTrId("ryugin-la-n_songs", page.tracks.length), Theme.time(page.album.duration)].filter(function (x) { return x !== ""; }).join("  ·  ") : ""
                    color: Theme.dim
                    font.pixelSize: 13
                }
                Flow {
                    width: Nav.phone ? page.width - 56 : page.width - 56 - 259
                    spacing: 10
                    topPadding: 10
                    TextButton { icon: "play"; text: /*% "Play album" */ qsTrId("ryugin-me-play_album"); primary: true; height: 42; onClicked: Player.play(page.tracks, 0) }
                    TextButton { icon: "plus"; text: /*% "Add to queue" */ qsTrId("ryugin-me-add_to_queue"); height: 42; onClicked: Player.enqueue(page.tracks) }
                    TextButton {
                        objectName: "hideAlbum"
                        icon: page.hidden ? "eye" : "eye-off"
                        text: page.hidden ? /*% "Show album" */ qsTrId("ryugin-me-show_album") : /*% "Hide album" */ qsTrId("ryugin-me-hide_album")
                        height: 42
                        onClicked: Api.hide(page.album, !page.hidden)
                    }
                }
            }
        }
    }
    TrackList {
        width: parent.width
        tracks: page.tracks
        showArtist: page.tracks.some(function (t) { return page.album && t.artist !== page.album.artist; })
    }
}
