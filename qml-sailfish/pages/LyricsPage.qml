import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The song's lyrics: synced ones follow the song, the line sung lit and kept in the middle,
// word by word when the lyrics have word times (1.2's); a tap on a line goes there.
Page {
    id: page

    // The song's time at each frame (the player reports it now and then), so sung words
    // light up smoothly.
    property real ms
    property double _stamp

    objectName: "lyrics"
    // A word goes from dim to lit over the time it is sung (StyledText: the line still
    // wraps and centres as one text).
    function sung(words) {
        var lit = page.palette.highlightColor
        var dim = page.palette.secondaryColor
        return words.map(function (w) {
            var end = w.end > w.time ? w.end : w.time + 500
            var f = Math.max(0, Math.min(1, (page.ms - w.time) / (end - w.time)))
            var c = Qt.rgba(dim.r + (lit.r - dim.r) * f, dim.g + (lit.g - dim.g) * f, dim.b + (lit.b - dim.b) * f, dim.a + (lit.a - dim.a) * f)
            var text = w.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            return '<font color="' + c + '">' + text + "</font>"
        }).join("")
    }

    Connections {
        target: R.Player

        function onPositionChanged() {
            page._stamp = Date.now()
            page.ms = R.Player.position
        }
    }

    Timer {
        running: page.status === PageStatus.Active && R.Player.playing && Qt.application.active
        interval: 33
        repeat: true
        onTriggered: page.ms = R.Player.position + Math.min(1000, Date.now() - page._stamp)
    }

    SilicaListView {
        id: list

        anchors.fill: parent
        model: R.Player.lyrics
        currentIndex: R.Player.lyricsSynced ? R.Player.lyricIndex : -1
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height / 2 - Theme.itemSizeSmall
        preferredHighlightEnd: height / 2
        highlightMoveDuration: 400

        // Named as Sailfish's pages are (it opens from Now playing's title too), the song under.
        header: PageHeader {
            title: "Lyrics"
            description: R.Player.current ? R.Player.current.title + "  ·  " + R.Player.current.artist : ""
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
                text: modelData.text === "" ? "• • •" : byWord ? page.sung(modelData.words) : modelData.text
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: "No lyrics"
        }

        VerticalScrollDecorator {}
    }
}
