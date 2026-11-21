import QtQuick

Page {
    id: page
    property string playlistId
    property string name
    property var tracks: []
    title: name
    Component.onCompleted: Api.getPlaylist(playlistId, function (l) { if (!page) return; page.tracks = l; })
    Row {
        spacing: 10
        TextButton { icon: "play"; text: "Play"; primary: true; onClicked: Player.play(page.tracks, 0) }
        TextButton { icon: "shuffle"; text: "Shuffle"; onClicked: Player.shuffle(page.tracks) }
    }
    TrackList { width: parent.width; tracks: page.tracks }
}
