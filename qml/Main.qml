pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Layout after SPlayer-Next: icon rail, top bar, pages, player bar; lyrics and the
// queue slide over the pages.
ApplicationWindow {
    id: win
    width: 1280
    height: 820
    minimumWidth: Nav.phone ? 0 : 960
    minimumHeight: Nav.phone ? 0 : 620
    visible: true
    color: Theme.bg
    // The controls' accent (sliders, switches, focus) follows the song's colours too.
    palette.highlight: Theme.gold
    palette.highlightedText: Theme.goldInk
    palette.accent: Theme.gold
    title: Player.current ? Player.current.title + " · " + Player.current.artist : "Ryūgin"

    // With a tray icon (set by Go), closing only hides the window.
    property bool hasTray: false
    onClosing: function (close) {
        console.log("window: close asked, tray", hasTray);
        if (hasTray) {
            close.accepted = false;
            win.hide();
        }
    }

    // Sailfish OS log (~/.cache/dragon/ryugin/ryugin/ryugin.log): what the window does when minimized
    // and back (a blank window then showed only the home screen's wallpaper).
    onVisibilityChanged: console.log("window: visibility", win.visibility)
    onActiveChanged: {
        console.log("window: active", win.active);
        if (win.active)
            Api.checkLibrary(); // back to the app: a scan may have added songs
    }
    // And every 10 minutes while it is shown.
    Timer {
        running: win.visible
        interval: 600000
        repeat: true
        triggeredOnStart: true
        onTriggered: Api.checkLibrary()
    }

    // Commands from Go (MPRIS, tray, global menu).
    property string goCommand: ""
    onGoCommandChanged: {
        const c = JSON.parse(goCommand);
        if (c.cmd === "toggleWindow" && win.visible) {
            win.hide();
        } else if (c.cmd === "raise" || c.cmd === "toggleWindow") {
            win.show();
            win.raise();
            win.requestActivate();
        } else if (c.cmd === "quit") {
            Qt.quit();
        } else if (c.cmd === "coverColor") {
            if (Player.current && c.url === Api.cover(Player.current.cover, 128)) {
                Theme.seed = c.color;
                Theme.wash = c.wash || "";
                Theme.flow = c.flow || "";
            }
        } else if (["go", "nowPlaying", "queue"].indexOf(c.cmd) >= 0) {
            win.show(); // from the global menu: the window may be in the tray
            win.raise();
            if (c.cmd === "go")
                go(c.page);
            else if (c.cmd === "nowPlaying")
                Nav.lyrics = !Nav.lyrics;
            else
                Nav.queue = !Nav.queue;
        } else if (c.cmd === "backdrop") {
            Player.settings.backdrop = c.value;
        } else {
            Player.command(c);
        }
    }

    Component.onCompleted: {
        // Set by Go (main.go) as context properties: unknown to qmllint.
        if (typeof goBridge !== "undefined")
            Player.bridge = goBridge; // qmllint disable unqualified
        if (typeof goIconDir !== "undefined")
            Icons.dir = goIconDir; // qmllint disable unqualified
        if (typeof goIconNames !== "undefined")
            Icons.have = goIconNames.split(" ").reduce(function (m, n) { m[n] = true; return m; }, {}); // qmllint disable unqualified
        if (typeof goStreamProxy !== "undefined")
            Api.streamProxy = goStreamProxy; // qmllint disable unqualified
        Api.cache({ on: Player.settings.cache ? 1 : 0, limit: Player.settings.cacheLimit });
        prefetch.start();
        go("home");
        if (!Api.configured)
            go("settings");
    }

    readonly property var pages: [
        { key: "home", label: /*% "Home" */ qsTrId("ryugin-he-home"), icon: "house", url: "HomePage.qml" },
        { key: "albums", label: /*% "Albums" */ qsTrId("ryugin-he-albums"), icon: "disc-3", url: "AlbumsPage.qml" },
        { key: "favorites", label: /*% "Favorites" */ qsTrId("ryugin-he-favorites"), icon: "favorite", url: "AlbumsPage.qml", props: { type: "starred" } },
        { key: "artists", label: /*% "Artists" */ qsTrId("ryugin-he-artists"), icon: "users", url: "ArtistsPage.qml" },
        { key: "playlists", label: /*% "Playlists" */ qsTrId("ryugin-he-playlists"), icon: "list-music", url: "PlaylistsPage.qml" },
        { key: "settings", label: /*% "Settings" */ qsTrId("ryugin-he-settings"), icon: "settings", url: "SettingsPage.qml", bottom: true }
    ]
    property string section: "home"
    readonly property bool settingsOpen: settingsPopup.opened || settingsWindow.visible

    // History, so the top bar can go back and forward.
    property var history: []
    property var ahead: []

    function go(key) {
        if (key === "settings") { // a dialog (a phone: a popup over the page); the gear opens and closes it
            if (settingsOpen) {
                settingsPopup.close();
                settingsWindow.close();
            } else if (Nav.phone) {
                settingsPopup.open();
            } else {
                settingsWindow.show();
                settingsWindow.raise();
                settingsWindow.requestActivate();
            }
            return;
        }
        settingsPopup.close();
        settingsWindow.close();
        Nav.lyrics = false;
        // Its own page again: no rebuild (it blinked). From an album opened there, back to
        // the list as it was; on the list itself, up to the top.
        if (key === section && stack.depth > 0) {
            history = [];
            ahead = [];
            if (stack.depth > 1)
                stack.pop(null);
            else
                toTop(stack.currentItem);
            return;
        }
        section = key;
        history = [];
        ahead = [];
        stack.clear();
        const p = pages.find(function (p) { return p.key === key; });
        stack.push(p.url, p.props || {});
    }
    // Scrolls a page (or the list in it) to its top.
    function toTop(item) {
        if (!item)
            return false;
        if (item.contentY !== undefined && item.originY !== undefined && item.contentHeight > item.height) {
            scrollTop.target = item;
            scrollTop.to = item.originY;
            scrollTop.restart();
            return true;
        }
        for (const c of item.children)
            if (toTop(c))
                return true;
        return false;
    }
    NumberAnimation { id: scrollTop; property: "contentY"; duration: 300; easing.type: Easing.OutCubic }
    function open(url, props) {
        Nav.lyrics = false;
        history = history.concat([{ url: url, props: props || {} }]);
        ahead = [];
        stack.push(url, props || {});
    }
    function back() {
        if (stack.depth < 2)
            return;
        ahead = ahead.concat([history[history.length - 1]]);
        history = history.slice(0, -1);
        stack.pop();
    }
    function forward() {
        const e = ahead[ahead.length - 1];
        ahead = ahead.slice(0, -1);
        history = history.concat([e]);
        stack.push(e.url, e.props);
    }

    Connections {
        target: Nav
        function onOpenAlbum(id) { win.open("AlbumPage.qml", { albumId: id }); }
        function onOpenArtist(id, name) { win.open("ArtistPage.qml", { artistId: id, name: name }); }
        function onOpenPlaylist(id, name) { win.open("PlaylistPage.qml", { playlistId: id, name: name }); }
        function onHome() { win.go("home"); }
        function onBack() { win.back(); }
        function onGo(key) { win.go(key); }
        function onSettings() { win.go("settings"); }
        function onSearch(query) {
            if (query === "") { // cleared: back to what was there before the search
                if (stack.currentItem && stack.currentItem.objectName === "search")
                    win.back();
                return;
            }
            if (stack.currentItem && stack.currentItem.objectName === "search")
                stack.currentItem.query = query; // qmllint disable missing-property
            else
                win.open("SearchPage.qml", { query: query });
        }
    }

    Shortcut { sequence: "Media Play"; onActivated: Player.toggle() }
    Shortcut { sequence: "Ctrl+Space"; onActivated: Player.toggle() }
    Shortcut { sequence: "Space"; onActivated: Player.toggle() } // a text field keeps its spaces (it takes them first)
    Shortcut { sequence: "Ctrl+Right"; onActivated: Player.next() }
    Shortcut { sequence: "Ctrl+Left"; onActivated: Player.previous() }
    Shortcut { sequence: "Ctrl+L"; onActivated: Nav.lyrics = !Nav.lyrics }
    Shortcut { sequence: "Escape"; onActivated: Nav.lyrics ? Nav.lyrics = false : (Nav.queue ? Nav.queue = false : win.back()) }
    Shortcut { sequences: [StandardKey.Back]; onActivated: win.back() }
    Shortcut { sequence: "F9"; onActivated: Nav.layout.folded = !Nav.layout.folded }
    Shortcut { sequences: [StandardKey.Find]; onActivated: { Nav.layout.folded = false; Qt.callLater(Nav.focusSearch); } }
    Shortcut { sequences: [StandardKey.Forward]; onActivated: if (win.ahead.length) win.forward() }

    // Room for a phone's notch (the Jolla Phone's camera) at the top when upright; on its
    // side the system keeps the notch's band itself.
    readonly property real topInset: Nav.phone && win.height > win.width ? 36 : 0
    Binding { target: Nav; property: "rail"; value: !Nav.phone || win.width > win.height }

    Rectangle {
        id: content
        anchors.fill: parent
        color: "transparent" // the window's colour: one layer, so it stays see-through

        Sidebar {
            id: sidebar
            objectName: "sidebar"
            anchors.top: parent.top
            anchors.bottom: tabs.top
            pages: win.pages
            current: win.settingsOpen ? "settings" : win.section
            onSelected: function (key) { win.go(key); }
            z: 2
        }

        Header {
            id: header
            visible: Nav.phone
            height: visible ? implicitHeight : 0
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: win.topInset
            canBack: stack.depth > 1
            canForward: win.ahead.length > 0
            onBack: win.back()
            onForward: win.forward()
        }

        StackView {
            id: stack
            objectName: "stack"
            anchors.left: sidebar.right
            anchors.right: queue.over ? parent.right : queue.left // docked beside the queue, else under it
            // Under the queue (a small window): faded out, the queue's glass shows the window's blur,
            // not the page's covers.
            opacity: queue.over && Nav.queue ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            anchors.top: header.bottom
            anchors.bottom: tabs.top
            clip: true
            visible: nowPlaying.y > 0 // under the open player: not drawn
            pushEnter: Transition { ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "y"; from: 12; to: 0; duration: 220; easing.type: Easing.OutCubic } } }
            pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
            popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
            popExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
            // A phone: swipe right to go back, the page following the finger (Silica's way).
            // It takes the touch from rows and buttons, not from a row of albums that scrolls
            // sideways (a Flickable keeps its grab once it moves).
            DragHandler {
                id: swipeBack
                enabled: Nav.phone && stack.depth > 1
                target: null
                yAxis.enabled: false
                property real from: NaN
                onTranslationChanged: if (active && stack.currentItem) {
                    if (isNaN(from))
                        from = translation.x;
                    stack.currentItem.x = Math.max(0, translation.x - from);
                }
                onActiveChanged: if (!active && stack.currentItem) {
                    const x = stack.currentItem.x;
                    from = NaN;
                    if (x > stack.width * 0.3 || (x > 24 && centroid.velocity.x > 800))
                        win.back();
                    else
                        springBack.start();
                }
            }
            NumberAnimation { id: springBack; target: stack.currentItem; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }

        // Docked at the right (a phone: over the page).
        QueuePanel {
            id: queue
            objectName: "queueDock"
            // Over the whole middle when the page beside it would be too narrow (a phone, a
            // small window), else docked at its width.
            over: Nav.phone || content.width - sidebar.width - Nav.layout.queueWidth < 480
            width: Nav.queue ? (over ? content.width - sidebar.width : Nav.layout.queueWidth) : 0
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: tabs.top
            visible: width > 0
            clip: true
            Behavior on width { enabled: !queue.resizing; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            z: 3
        }

        // Fullscreen player: slides up over everything, the player bar included.
        NowPlaying {
            id: nowPlaying
            topInset: win.topInset
            width: parent.width
            height: parent.height
            y: (Nav.lyrics ? 0 : parent.height) + pull
            visible: y < parent.height
            Behavior on y { enabled: !nowPlaying.pulling; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            z: 6
        }

        // A phone's tabs, the sidebar's pages along the bottom.
        Rectangle {
            id: tabs
            objectName: "tabs"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: bar.top
            height: Nav.rail ? 0 : 56
            visible: !Nav.rail
            color: Theme.panel
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Row {
                anchors.fill: parent
                Repeater {
                    model: win.pages
                    delegate: Item {
                        id: tab
                        required property var modelData
                        readonly property bool active: (win.settingsOpen ? "settings" : win.section) === tab.modelData.key
                        objectName: "tab-" + tab.modelData.key
                        width: tabs.width / win.pages.length
                        height: tabs.height
                        Icon { anchors.centerIn: parent; name: tab.modelData.icon; size: 22; color: parent.active ? Theme.gold : Theme.dim }
                        MouseArea { anchors.fill: parent; onClicked: win.go(tab.modelData.key) }
                    }
                }
            }
        }

        PlayerBar {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            z: 5
        }
    }

    // Just after start (the first page's covers come first), every album's cover into the cache.
    Timer {
        id: prefetch
        interval: 5000
        onTriggered: if (Player.settings.cache && Api.configured) Api.prefetchCovers()
    }

    // Navidrome (SettingsPage) as a popup: the gear, a click outside or Escape closes it;
    // it stays until a server is set.
    Popup {
        id: settingsPopup
        objectName: "settingsPopup"
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        padding: 0
        closePolicy: Api.configured ? Popup.CloseOnEscape | Popup.CloseOnPressOutside : Popup.NoAutoClose
        background: null
        contentItem: SettingsPage { onCloseRequested: settingsPopup.close() }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 } }
    }

    // Settings, a dialog of its own (a phone: the popup above): the compositor blurs it.
    Window {
        id: settingsWindow
        objectName: "settingsWindow"
        transientParent: win
        title: /*% "Ryūgin settings" */ qsTrId("ryugin-he-settings_window")
        width: 760
        height: 560
        minimumWidth: 560
        minimumHeight: 400
        color: Theme.bg
        palette.highlight: Theme.gold
        palette.highlightedText: Theme.goldInk
        palette.accent: Theme.gold
        SettingsPage { anchors.fill: parent; onCloseRequested: settingsWindow.close() }
    }
}
