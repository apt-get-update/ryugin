import QtQuick

// Top bar: back and forward, a search pill (settings live in the sidebar).
Item {
    id: header
    property bool canBack: false
    property bool canForward: false
    signal back()
    signal forward()
    height: 64

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        IconButton { icon: "chevron-left"; filled: true; iconSize: 18; opacity: header.canBack ? 1 : 0.4; onClicked: if (header.canBack) header.back() }
        IconButton { icon: "chevron-right"; filled: true; iconSize: 18; opacity: header.canForward ? 1 : 0.4; onClicked: if (header.canForward) header.forward() }
        Field {
            id: search
            objectName: "search"
            width: Nav.phone ? header.width - 16 - x - 16 : 260 // a phone: the rest of the bar
            implicitHeight: 34
            icon: "search"
            placeholderText: "Search"
            radius: 17
            onTextEdited: Nav.search(text.trim()) // empty: back to the page before
            onAccepted: if (text.trim() !== "") Nav.search(text.trim())
            Connections { target: Nav; function onFocusSearch() { search.forceActiveFocus(); } }
        }
    }
}
