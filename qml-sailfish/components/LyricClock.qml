import QtQuick 2.0
import "../../qml" as R

// The song's time at each frame (the player reports it now and then), so sung words light
// up smoothly: sung() colours a line's words as far as they are sung.
Item {
    id: clock

    property bool running: true // on screen
    property real ms
    property double _stamp

    // A word goes from dim to lit over the time it is sung (StyledText: the line still
    // wraps and centres as one text), in the line's colours.
    function sung(words, colors) {
        var lit = colors.highlightColor
        var dim = colors.secondaryColor
        return words.map(function (w) {
            var end = w.end > w.time ? w.end : w.time + 500
            var f = Math.max(0, Math.min(1, (clock.ms - w.time) / (end - w.time)))
            var c = Qt.rgba(dim.r + (lit.r - dim.r) * f, dim.g + (lit.g - dim.g) * f, dim.b + (lit.b - dim.b) * f, dim.a + (lit.a - dim.a) * f)
            var text = w.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            return '<font color="' + c + '">' + text + "</font>"
        }).join("")
    }

    Connections {
        target: R.Player

        function onPositionChanged() {
            clock._stamp = Date.now()
            clock.ms = R.Player.position
        }
    }

    Timer {
        // Only for a line lit word by word: nothing else moves between positions.
        running: clock.running && R.Player.playing && Qt.application.active
                 && ((R.Player.lyrics[R.Player.lyricIndex] || {}).words || []).length > 0
        interval: 33
        repeat: true
        onTriggered: clock.ms = R.Player.position + Math.min(1000, Date.now() - clock._stamp)
    }
}
