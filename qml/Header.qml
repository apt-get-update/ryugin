import QtQuick

// A phone's top bar: back and forward, search. A desktop has none: search and the one-tap
// plays live in the sidebar, a page opened from another has its own back arrow.
Item {
    id: header
    property bool canBack: false
    property bool canForward: false
    signal back()
    signal forward()
    implicitHeight: 56

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

    Row {
        id: tools
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton { icon: "chevron-left"; iconSize: 16; enabled: header.canBack; opacity: enabled ? 1 : 0.4; onClicked: header.back() }
        IconButton { icon: "chevron-right"; iconSize: 16; enabled: header.canForward; opacity: enabled ? 1 : 0.4; onClicked: header.forward() }
    }
    Field {
        id: search
        objectName: "search"
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: header.width - tools.width - 26 // a phone: the rest of the bar
        icon: "search"
        placeholderText: /*% "Search" */ qsTrId("ryugin-he-search")
        onTextEdited: Nav.search(text.trim()) // empty: back to the page before
        onAccepted: if (text.trim() !== "") Nav.search(text.trim())
        Connections { target: Nav; function onFocusSearch() { if (header.visible) search.forceActiveFocus(); } }
    }
}
