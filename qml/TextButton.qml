import QtQuick
import QtQuick.Controls

// The desktop's push button (Kvantum draws it), with an icon from the icon theme, else Lucide.
Item {
    id: b
    property string text
    property string icon: ""
    property bool primary: false
    property bool flat: false // a toolbar's button
    signal clicked()
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight
    Button {
        id: btn
        anchors.fill: parent
        text: b.text
        highlighted: b.primary
        flat: b.flat
        icon.name: Icons.theme[b.icon] || ""
        // Not in the theme: Lucide's, in the button's text colour.
        icon.source: Icons.theme[b.icon] ? "" : Icons.url(b.icon, 16)
        icon.color: Icons.theme[b.icon] ? "transparent" : palette.buttonText
        onClicked: b.clicked()
    }
}
