import QtQuick

Column {
    property alias title: t.text
    property alias subtitle: s.text
    spacing: 3
    Text { id: t; color: Theme.text; font.pixelSize: 19; font.weight: Font.DemiBold }
    Text { id: s; color: Theme.faint; font.pixelSize: 12; visible: text !== "" }
}
