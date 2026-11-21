pragma ComponentBehavior: Bound
import QtQuick

// Albums in a grid that fills the width.
Flow {
    property var albums: []
    width: parent.width
    spacing: 22
    Repeater {
        model: parent.albums
        delegate: AlbumCard { required property var modelData; album: modelData }
    }
}
