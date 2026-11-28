import QtQuick
import QtQuick.Controls as C
import QtQuick.Controls

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
        // A page opened from another (an album, an artist): a back arrow before its title.
        Row {
            spacing: 6
            visible: page.title !== "" || back.visible
            IconButton { id: back; visible: !Nav.phone && page.StackView.index > 0; icon: "chevron-left"; iconSize: 18; tip: /*% "Back (Alt+Left)" */ qsTrId("ryugin-la-back_alt_left"); anchors.verticalCenter: parent.verticalCenter; onClicked: Nav.back() }
            Text {
                text: page.title
                color: Theme.text
                font.pixelSize: 28
                font.weight: Font.Bold
                visible: page.title !== ""
            }
        }
    }
}
