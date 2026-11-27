import QtQuick
import QtQuick.Controls

// An icon that acts as a button: the desktop's tool button (Kvantum draws it), a raised
// button when filled, pressed in while active.
Item {
    id: b
    property string icon
    property int iconSize: 20
    property bool active: false
    property bool filled: false
    property string tip: "" // its name, on hover
    property color iconColor: active ? Theme.gold : (btn.hovered ? Theme.text : Theme.dim)
    signal clicked()
    implicitWidth: iconSize + 16
    implicitHeight: iconSize + 16
    Button {
        id: btn
        anchors.fill: parent
        padding: 0
        flat: !b.filled
        checked: b.active
        contentItem: Item { Icon { anchors.centerIn: parent; name: b.icon; size: b.iconSize; color: b.iconColor } }
        onClicked: b.clicked()
        ToolTip.visible: b.tip !== "" && hovered
        ToolTip.text: b.tip
        ToolTip.delay: 400
    }
}
