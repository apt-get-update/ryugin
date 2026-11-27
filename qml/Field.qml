import QtQuick
import QtQuick.Controls

// A text field with an icon: the desktop's (Kvantum's) look, an underline, drawn here so it
// takes the song's colour (a widget style paints its own).
TextField {
    id: f
    property string icon: ""
    leftPadding: icon !== "" ? 30 : 6
    passwordCharacter: "•"
    selectionColor: Theme.gold
    selectedTextColor: Theme.goldInk
    background: Item {
        implicitWidth: 120
        implicitHeight: 30
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: f.activeFocus ? 2 : 1
            color: f.activeFocus ? Theme.gold : Theme.border
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    Icon { x: 6; anchors.verticalCenter: parent.verticalCenter; name: f.icon; size: 16; color: f.activeFocus ? Theme.gold : Theme.faint; visible: f.icon !== "" }
}
