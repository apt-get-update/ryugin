pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Search (Ctrl+F), one-tap plays (tool buttons), a line, then the pages as KDE apps list their
// places (icons with names and counts). Drag its edge to resize it; it folds to an icon rail (F9, its fold button,
// dragged narrow, or a narrow window), names then on hover.
Rectangle {
    id: side
    property var pages: []
    property string current: ""
    signal selected(string key)
    readonly property bool wide: !Nav.layout.folded && !Nav.phone && (Window.width || 1280) >= 900
    property var counts: ({}) // page key -> its count, as Navidrome answers
    function load() {
        if (!Api.configured)
            return;
        const add = function (more) { if (side) side.counts = Object.assign({}, side.counts, more); }; // not closed meanwhile
        Api.playlists(function (l) { add({ playlists: l.length }); });
        Api.artists(function (l) { add({ artists: l.length, albums: l.reduce(function (n, a) { return n + a.albumCount; }, 0) }); });
        Api.albumList("starred", 500, 0, function (l) { add({ favorites: l.length }); });
    }
    Component.onCompleted: load()
    Connections {
        target: Api
        function onLibraryChanged() { side.load(); }
        function onPlaylistsChanged() { side.load(); }
        function onConfiguredChanged() { side.load(); }
    }
    width: !Nav.rail ? 0 : wide ? Nav.layout.sideWidth : 52 // a phone upright has tabs at the bottom instead
    visible: width > 0
    clip: true
    color: Theme.panel
    Behavior on width { enabled: !edge.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

    // One place: an icon, its name (wide) or a tooltip (rail), a count.
    component Entry: Rectangle {
        id: e
        property string icon
        property string label
        property string count: ""
        property bool active: false
        signal clicked()
        x: 6
        width: side.width - 12
        height: 30
        radius: 4
        color: Theme.lit(active, area.containsMouse)
        Icon {
            x: side.wide ? 8 : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            name: e.icon
            size: 16
            color: e.active ? Theme.gold : Theme.dim
            visible: e.icon !== ""
        }
        Text {
            visible: side.wide
            x: e.icon !== "" ? 34 : 34
            width: parent.width - x - countText.width - 12
            anchors.verticalCenter: parent.verticalCenter
            text: e.label
            color: e.active ? Theme.text : Theme.dim
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Text {
            id: countText
            visible: side.wide && e.count !== ""
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: e.count
            color: Theme.faint
            font.pixelSize: 10
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: e.clicked() }
        ToolTip.visible: !side.wide && area.containsMouse
        ToolTip.text: e.label
        ToolTip.delay: 300
    }
    component Section: Text {
        visible: side.wide
        x: 14
        height: visible ? 30 : 0
        verticalAlignment: Text.AlignBottom
        bottomPadding: 4
        color: Theme.faint
        font.pixelSize: 10
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
    }

    Field {
        id: search
        objectName: "sideSearch"
        visible: side.wide
        x: 10
        y: 8
        width: side.width - 20
        height: visible ? implicitHeight : 0
        icon: "search"
        placeholderText: /*% "Search" */ qsTrId("ryugin-he-search")
        onTextEdited: Nav.search(text.trim()) // empty: back to the page before
        onAccepted: if (text.trim() !== "") Nav.search(text.trim())
        Connections { target: Nav; function onFocusSearch() { if (search.visible) search.forceActiveFocus(); } }
    }

    Flickable {
        anchors.top: search.bottom
        anchors.topMargin: 4
        anchors.bottom: footer.top
        width: parent.width
        clip: true
        contentHeight: places.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: places
            width: parent.width
            spacing: 2
            Entry { visible: !side.wide; icon: "search"; label: /*% "Search (Ctrl+F)" */ qsTrId("ryugin-la-search_ctrl_f"); onClicked: { Nav.layout.folded = false; Qt.callLater(Nav.focusSearch); } }
            // What plays at once: tool buttons, apart from the places below (which open a page).
            // A button group (a toolbar well), apart from the list of places.
            // It ends with its last button (open), or spans the rail (folded).
            Rectangle {
                x: 6
                width: side.wide ? actions.width : side.width - 12
                height: actions.height + 6
                radius: 6
                color: Theme.alpha(Theme.text, 0.06)
                Grid {
                    id: actions
                    // Its icons on the places' icons' line: 16 px, centred at 22 px (open) or
                    // in the middle (folded), as theirs.
                    x: side.wide ? 0 : (parent.width - width) / 2
                    y: 3
                    columns: side.wide ? 4 : 1
                    spacing: 2
                    IconButton { objectName: "lucky"; icon: "dices"; iconSize: 16; tip: /*% "Roll the dice" */ qsTrId("ryugin-la-roll_the_dice"); onClicked: Api.randomSongs(50, function (l) { Player.play(l, 0); }) }
                    IconButton { objectName: "radio"; icon: "radio"; iconSize: 16; tip: /*% "Library radio" */ qsTrId("ryugin-la-library_radio"); onClicked: Api.randomSongs(500, function (l) { Player.play(l, 0); }) }
                    IconButton { objectName: "playFavorites"; icon: "favorite"; iconSize: 16; tip: /*% "Play favorites, mixed" */ qsTrId("ryugin-la-play_favorites_mixed"); onClicked: Api.starredSongs(function (l) { Player.playMixed(l); }) }
                    IconButton { objectName: "karaoke"; icon: "mic-vocal"; iconSize: 16; tip: /*% "Karaoke: songs with synced lyrics" */ qsTrId("ryugin-la-karaoke_tip"); onClicked: Api.allSongs(function (l) { Player.playKaraoke(l); Nav.lyrics = true; }) }
                }
            }
            // A line between what plays and the places (folded too, where no title says it).
            Rectangle { x: 10; width: side.width - 20; height: 1; color: Theme.border }
            Section { text: /*% "Library" */ qsTrId("ryugin-la-library") }
            Repeater {
                model: side.pages.filter(function (p) { return !p.bottom; })
                delegate: Entry {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    count: side.counts[modelData.key] || ""
                    active: side.current === modelData.key
                    onClicked: side.selected(modelData.key)
                }
            }
        }
    }

    Column {
        id: footer
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: parent.width
        spacing: 2
        Entry {
            objectName: "sideQueue"
            icon: "list-ordered"
            label: /*% "Queue" */ qsTrId("ryugin-me-queue")
            count: Player.queue.length || ""
            active: Nav.queue
            onClicked: Nav.queue = !Nav.queue
        }
        Repeater {
            model: side.pages.filter(function (p) { return p.bottom; })
            delegate: Entry {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                active: side.current === modelData.key
                onClicked: side.selected(modelData.key)
            }
        }
        Entry {
            visible: !Nav.phone
            objectName: "sidebarFold"
            icon: "panel-left"
            label: side.wide ? /*% "Fold sidebar" */ qsTrId("ryugin-la-fold_sidebar") : /*% "Unfold sidebar (F9)" */ qsTrId("ryugin-la-unfold_sidebar_f9")
            onClicked: Nav.layout.folded = !Nav.layout.folded
        }
    }

    // Its edge: drag to resize; narrower than 120 px, it folds to the rail.
    MouseArea {
        id: edge
        visible: !Nav.phone
        anchors.right: parent.right
        width: 6
        height: parent.height
        cursorShape: Qt.SizeHorCursor
        onPositionChanged: function (mouse) {
            const w = mapToItem(side, mouse.x, 0).x;
            Nav.layout.folded = w < 120;
            if (!Nav.layout.folded)
                Nav.layout.sideWidth = Math.max(160, Math.min(360, w));
        }
    }
}
