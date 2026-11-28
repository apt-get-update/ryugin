import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The song's lyrics, whole (LyricLines: the line sung lit, word by word; a tap seeks).
Page {
    id: page

    objectName: "lyrics"

    LyricLines {
        id: list

        anchors.fill: parent
        running: page.status === PageStatus.Active

        // Named as Sailfish's pages are (it opens from Now playing's lyrics and pulley), the song under.
        header: PageHeader {
            //% "Lyrics"
            title: qsTrId("ryugin-he-lyrics")
            description: R.Player.current ? R.Player.current.title + "  ·  " + R.Player.current.artist : ""
        }

        ViewPlaceholder {
            enabled: list.count === 0
            //% "No lyrics"
            text: qsTrId("ryugin-la-no_lyrics")
        }

        VerticalScrollDecorator {}
    }
}
