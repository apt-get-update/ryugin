import QtQuick
import QtQuick.Controls.Basic as C

// A scrolling page with an optional title.
Flickable {
    id: page
    property string title: ""
    default property alias content: body.data
    contentHeight: body.implicitHeight + 80
    clip: true
    boundsBehavior: Nav.phone ? Flickable.DragOverBounds : Flickable.StopAtBounds
    C.ScrollBar.vertical: Scroller {}

    Column {
        id: body
        x: 28
        y: 8
        width: page.width - 56
        spacing: 26
        Text {
            text: page.title
            color: Theme.text
            font.pixelSize: 28
            font.weight: Font.Bold
            visible: page.title !== ""
        }
    }
}
