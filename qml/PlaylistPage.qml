import QtQuick

Page {
    id: page
    property string playlistId
    property string name
    property var tracks: []
    property bool confirming: false // Delete asked: it asks again, in place
    title: name
    Component.onCompleted: Api.getPlaylist(playlistId, function (l) { if (!page) return; page.tracks = l; })
    Row {
        spacing: 10
        TextButton { icon: "play"; text: /*% "Play" */ qsTrId("ryugin-me-play"); primary: true; onClicked: Player.play(page.tracks, 0) }
        TextButton { objectName: "deletePlaylist"; visible: !page.confirming; icon: "trash-2"; text: /*% "Delete" */ qsTrId("ryugin-me-delete"); onClicked: page.confirming = true }
        Text { visible: page.confirming; anchors.verticalCenter: parent.verticalCenter; text: /*% "Delete this playlist from Navidrome?" */ qsTrId("ryugin-la-delete_playlist"); color: Theme.text; font.pixelSize: 13 }
        TextButton {
            objectName: "confirmDelete"
            visible: page.confirming
            icon: "trash-2"
            text: /*% "Delete" */ qsTrId("ryugin-me-delete")
            onClicked: Api.deletePlaylist(page.playlistId, function (err) { if (!err) Nav.back(); })
        }
        TextButton { visible: page.confirming; text: /*% "Cancel" */ qsTrId("ryugin-la-cancel"); onClicked: page.confirming = false }
    }
    TrackList { width: parent.width; view: page; tracks: page.tracks }
}
