import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The song's lyrics, whole: synced ones follow the song, the line sung lit and kept in the
// middle, word by word when the lyrics have word times (1.2's); a tap on a line goes there.
SilicaListView {
    id: list

    property alias running: clock.running

    model: R.Player.lyrics
    currentIndex: R.Player.lyricsSynced ? R.Player.lyricIndex : -1
    highlightRangeMode: ListView.ApplyRange
    preferredHighlightBegin: height / 2 - Theme.itemSizeSmall
    preferredHighlightEnd: height / 2
    highlightMoveDuration: 400

    LyricClock {
        id: clock
    }

    delegate: BackgroundItem {
        width: list.width
        height: line.height + 2 * Theme.paddingMedium
        enabled: R.Player.lyricsSynced && modelData.time >= 0
        onClicked: R.Player.seek(modelData.time)

        Label {
            id: line

            readonly property bool now: model.index === list.currentIndex
            readonly property bool byWord: now && !!modelData.words && modelData.words.length > 0

            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: now ? Theme.fontSizeLarge : Theme.fontSizeMedium
            textFormat: byWord ? Text.StyledText : Text.PlainText
            color: now ? palette.highlightColor : palette.secondaryColor
            text: modelData.text === "" ? "• • •" : byWord ? clock.sung(modelData.words, palette) : modelData.text
        }
    }
}
