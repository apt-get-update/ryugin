import QtQuick
import QtQuick.Controls.Basic

// A text field with an icon, in SPlayer's style.
TextField {
    id: f
    property string icon: ""
    property real radius: Theme.radius
    implicitHeight: 42
    leftPadding: icon !== "" ? 40 : 14
    rightPadding: 14
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.gold
    selectedTextColor: Theme.goldInk
    passwordCharacter: "•"
    font.pixelSize: 14
    background: Rectangle {
        radius: f.radius
        color: Theme.field
        border.color: f.activeFocus ? Theme.gold : Theme.border
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Icon { x: 13; anchors.verticalCenter: parent.verticalCenter; name: f.icon; size: 17; color: f.activeFocus ? Theme.gold : Theme.faint; visible: f.icon !== "" }
    }
}
