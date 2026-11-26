import QtQuick 2.0
import Sailfish.Silica 1.0

// Silica's PullDownMenu, with a fix for Keel: a drag that may not open the menu (it began
// away from the top, as on a shelf, or went into the page) is kept from it until released.
// Silica's own C++ does that; Keel's does not, so such a drag at the page's top or end
// flipped between bounce and stop each frame (the page shook).
PullDownMenu {
    id: menu

    // A page at its top stays there when what is above its first row grows (a header
    // filled once loaded): Silica's C++ does it, Keel's lists stayed where they were, a line
    // down.
    property real _rest: NaN

    on_InactivePositionChanged: {
        var f = flickable
        if (f && !f.moving && !active && Math.abs(f.contentY - _rest) < 1) {
            f.contentY = _inactivePosition
        }
        _rest = _inactivePosition
    }

    property Connections _keelFix: Connections {
        target: menu.flickable

        function onDraggingChanged() {
            if (menu.flickable.dragging) {
                menu._activationInhibited = !menu._activationPermitted
            }
        }

        function onContentYChanged() {
            var f = menu.flickable
            if (f.dragging && !menu.active && f.contentY > menu._inactivePosition + 1) {
                menu._activationInhibited = true
                // A page that fits (Now playing) stays still: back before it is drawn.
                if (f.contentHeight <= f.height) {
                    f.contentY = menu._inactivePosition
                }
            }
        }
    }
}
