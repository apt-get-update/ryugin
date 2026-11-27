pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// The play queue, docked at the right as in Cantata: one cover per album, its songs under
// it. Click a song to play it (the playing one is lit), an album's head to open it; drag a
// song to move it, × takes it out. A heart: a liked song. Save it as a playlist from its
// head. Drag its left edge to resize it.
Rectangle {
    id: panel
    readonly property bool resizing: edge.pressed
    property bool over: false // over the page (Main.qml): no edge to drag
    // A song dragged by its grip: its place in the queue (-1: none), its title, and the
    // pointer in the list. The rows stay put; a ghost follows the pointer, a line shows
    // where it lands.
    property int dragFrom: -1
    property string dragTitle: ""
    property real dragY: 0
    property real dragStart: 0 // the list's place when the drag began
    readonly property int dragTo: dragFrom < 0 ? -1 : placeAt(list.mapToItem(list.contentItem, 0, dragY).y)
    color: over ? Theme.popup : Theme.panel
    // The queue as rows: an album's head, then its songs (index: the song's place).
    readonly property var rows: {
        const out = [];
        let last = null;
        const q = Player.queue;
        for (let i = 0; i < q.length; i++) {
            const key = q[i].albumId || q[i].album;
            if (key !== last)
                out.push({ head: true, t: q[i], index: i });
            last = key;
            out.push({ head: false, t: q[i], index: i });
        }
        return out;
    }
    readonly property int total: Player.queue.reduce(function (s, t) { return s + (t.duration || 0); }, 0)
    function rowOf(index) {
        return rows.findIndex(function (r) { return !r.head && r.index === index; });
    }
    // The queue's place a song dropped at y (in the list) goes to.
    function placeAt(y) {
        const r = rows[list.indexAt(20, y)];
        return r ? r.index : Player.queue.length - 1;
    }
    // Saves the queue as a new playlist.
    function save(name) {
        if (name.trim() === "")
            return;
        Api.createPlaylist(name.trim(), Player.queue.map(function (t) { return t.id; }));
        naming.visible = false;
    }

    Rectangle { width: 1; height: parent.height; color: Theme.border }
    Item {
        id: head
        width: parent.width
        height: 56
        Column {
            x: 14
            visible: !naming.visible
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { text: /*% "Queue" */ qsTrId("ryugin-me-queue"); color: Theme.text; font.pixelSize: 14; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }
            Text { text: /*% "%n songs" */ qsTrId("ryugin-la-n_songs", Player.queue.length) + " · " + Theme.time(panel.total); color: Theme.faint; font.pixelSize: 11 }
        }
        Field {
            id: naming
            objectName: "playlistName"
            visible: false
            x: 14
            width: parent.width - x - tools.width - 16
            anchors.verticalCenter: parent.verticalCenter
            icon: "list-plus"
            placeholderText: /*% "New playlist's name" */ qsTrId("ryugin-ph-new_playlist_s_name")
            onAccepted: panel.save(text)
            // Escape cancels (before the window's Escape, which closes the queue).
            Keys.onShortcutOverride: function (e) { e.accepted = e.key === Qt.Key_Escape; }
            Keys.onEscapePressed: visible = false
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
        }
        Row {
            id: tools
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            IconButton { objectName: "savePlaylist"; icon: naming.visible ? "check" : "list-plus"; iconSize: 16; tip: naming.visible ? /*% "Save" */ qsTrId("ryugin-bt-save") : /*% "Save as playlist" */ qsTrId("ryugin-me-save_as_playlist"); enabled: Player.queue.length > 0; onClicked: naming.visible ? panel.save(naming.text) : naming.visible = true }
            IconButton { objectName: "cancelPlaylist"; visible: naming.visible; icon: "x"; iconSize: 16; tip: /*% "Cancel (Esc)" */ qsTrId("ryugin-la-cancel_esc"); onClicked: naming.visible = false }
            IconButton { visible: !naming.visible; icon: "locate"; iconSize: 16; tip: /*% "Show the playing song" */ qsTrId("ryugin-la-show_the_playing_song"); onClicked: list.positionViewAtIndex(Math.max(0, panel.rowOf(Player.index)), ListView.Center) }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    }
    ListView {
        id: list
        objectName: "queueList"
        anchors.fill: parent
        anchors.topMargin: head.height + 4
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        clip: true
        // The dragged row is kept while the drag scrolls the list (its grip holds the drag):
        // the buffer grows as far as it scrolls. A buffer for the whole queue made every row
        // at once: a long queue took a second to open.
        cacheBuffer: 1000 + (panel.dragFrom >= 0 ? Math.abs(contentY - panel.dragStart) : 0)
        model: panel.rows
        C.ScrollBar.vertical: Scroller {}
        Component.onCompleted: positionViewAtIndex(Math.max(0, panel.rowOf(Player.index)), ListView.Center)
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool playing: !modelData.head && modelData.index === Player.index
            width: list.width
            height: modelData.head ? 62 : 32
            opacity: panel.dragFrom >= 0 && !modelData.head && modelData.index === panel.dragFrom ? 0.35 : 1
            // An album's head: its cover, name and artist.
            Item {
                visible: row.modelData.head
                anchors.fill: parent
                Cover { id: c; x: 8; y: 10; width: 44; height: 44; size: 120; radius: 4; coverId: row.modelData.t.cover }
                Column {
                    anchors.left: c.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: c.verticalCenter
                    spacing: 2
                    Text { width: parent.width; text: row.modelData.t.album; color: Theme.text; font.pixelSize: 13; elide: Text.ElideRight }
                    Text { width: parent.width; text: row.modelData.t.artist; color: Theme.faint; font.pixelSize: 11; elide: Text.ElideRight }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (row.modelData.t.albumId) Nav.openAlbum(row.modelData.t.albumId) }
            }
            // A song: click plays it, its grip (on hover, at the left) moves it.
            Rectangle {
                visible: !row.modelData.head
                anchors.fill: parent
                radius: 4
                color: Theme.lit(row.playing, area.containsMouse)
                HoverHandler { id: hover } // the × too (a button over the row takes its hover)
                MouseArea {
                    id: area
                    objectName: "queueSong"
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Player.jump(row.modelData.index)
                }
                // The grip, as in Elisa: it keeps the drag from the list (which scrolls
                // otherwise).
                MouseArea {
                    id: grip
                    objectName: "queueGrip"
                    readonly property bool dragging: pressed
                    width: 36
                    height: parent.height
                    preventStealing: true
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: function (mouse) {
                        panel.dragTitle = row.modelData.t.title;
                        panel.dragY = mapToItem(list, 0, mouse.y).y;
                        panel.dragStart = list.contentY;
                        panel.dragFrom = row.modelData.index;
                    }
                    onPositionChanged: function (mouse) { if (pressed) panel.dragY = mapToItem(list, 0, mouse.y).y; }
                    onReleased: {
                        const from = panel.dragFrom, to = panel.dragTo;
                        panel.dragFrom = -1;
                        Player.move(from, to);
                    }
                    onCanceled: panel.dragFrom = -1
                }
                Icon {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hover.hovered || grip.dragging
                    name: "grip-vertical"
                    size: 14
                    color: grip.containsMouse || grip.pressed ? Theme.text : Theme.dim
                }
                Text {
                    visible: !hover.hovered && !grip.dragging
                    x: 8
                    width: 22
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: row.playing ? "▶" : (row.modelData.t.number || "")
                    color: row.playing ? Theme.gold : Theme.faint
                    font.pixelSize: 11
                }
                Text {
                    x: 40
                    width: parent.width - x - 64
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.t.title
                    color: row.playing ? Theme.gold : Theme.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Icon {
                    anchors.right: time.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!row.modelData.t.starred
                    name: "heart-fill"
                    size: 12
                    color: Theme.gold
                }
                Text {
                    id: time
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    horizontalAlignment: Text.AlignRight
                    visible: !hover.hovered || grip.dragging
                    text: row.modelData.t.duration ? Theme.time(row.modelData.t.duration) : ""
                    color: Theme.faint
                    font.pixelSize: 11
                }
                // On hover: take it out.
                IconButton {
                    objectName: "queueRemove"
                    visible: hover.hovered && !grip.dragging
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    icon: "x"
                    iconSize: 12
                    tip: /*% "Remove" */ qsTrId("ryugin-me-remove")
                    onClicked: Player.removeAt(row.modelData.index)
                }
            }
        }
    }
    // The drop line: above the song it goes before, below the one it goes after.
    Rectangle {
        readonly property Item at: panel.dragTo >= 0 ? list.itemAtIndex(panel.rowOf(panel.dragTo)) : null
        visible: at !== null
        x: list.x + 4
        width: list.width - 8
        height: 2
        radius: 1
        color: Theme.gold
        y: at ? list.y + at.y - list.contentY + (panel.dragTo > panel.dragFrom ? at.height : 0) - 1 : 0
        z: 5
    }
    // The ghost under the pointer.
    Rectangle {
        visible: panel.dragFrom >= 0
        x: list.x + 24
        width: list.width - 32
        height: 28
        y: list.y + panel.dragY - height / 2
        radius: 4
        color: Theme.popup
        border.color: Theme.border
        z: 6
        Text {
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            text: panel.dragTitle
            color: Theme.text
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }
    // Near the list's top or bottom, the list scrolls along.
    Timer {
        interval: 16
        repeat: true
        running: panel.dragFrom >= 0 && (panel.dragY < 30 || panel.dragY > list.height - 30)
        onTriggered: {
            const top = list.originY, bottom = list.originY + Math.max(0, list.contentHeight - list.height);
            list.contentY = Math.max(top, Math.min(bottom, list.contentY + (panel.dragY < 30 ? -8 : 8)));
        }
    }
    MouseArea {
        id: edge
        visible: !panel.over
        width: 6
        height: parent.height
        cursorShape: Qt.SizeHorCursor
        onPositionChanged: function (mouse) {
            const x = mapToItem(panel.parent, mouse.x, 0).x;
            Nav.layout.queueWidth = Math.max(260, Math.min(640, panel.parent.width - x));
        }
    }
}
