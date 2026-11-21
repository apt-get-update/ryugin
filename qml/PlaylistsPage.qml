pragma ComponentBehavior: Bound
import QtQuick

Page {
    id: page
    title: "Playlists"
    property var playlists: []
    Component.onCompleted: Api.playlists(function (l) { if (!page) return; page.playlists = l; })
    Flow {
        width: parent.width
        spacing: 22
        Repeater {
            model: page.playlists
            delegate: Column {
                id: playlist
                required property var modelData
                spacing: 8
                Cover {
                    width: 168
                    height: 168
                    size: 360
                    coverId: playlist.modelData.cover
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Nav.openPlaylist(playlist.modelData.id, playlist.modelData.name)
                    }
                }
                Text { width: 168; text: playlist.modelData.name; color: Theme.text; font.pixelSize: 14; elide: Text.ElideRight }
                Text { text: playlist.modelData.songCount + " tracks"; color: Theme.dim; font.pixelSize: 12 }
            }
        }
    }
}
