pragma ComponentBehavior: Bound
import QtQuick

Page {
    id: page
    title: /*% "Artists" */ qsTrId("ryugin-he-artists")
    property var artists: []
    function load() { Api.artists(function (l) { if (!page) return; page.artists = l; }); }
    Component.onCompleted: load()
    Connections { target: Api; function onLibraryChanged() { page.load(); } }
    Flow {
        width: parent.width
        spacing: 10
        Repeater {
            model: page.artists
            delegate: TextButton {
                required property var modelData
                icon: "users"
                text: modelData.name + "  ·  " + modelData.albumCount
                onClicked: Nav.openArtist(modelData.id, modelData.name)
            }
        }
    }
}
