import QtQuick
import QtQuick.Controls.Basic as C
import QtTest
import "../../qml"

// Clicks through the real components against the mock Navidrome. TestCase itself is not
// drawn, so the components go into a visible item beside it.
Item {
    id: root
    width: 1280
    height: 820

TestCase {
    id: testCase
    name: "UI"
    when: windowShown

    Mock { id: mock }
    SignalSpy { id: openSpy; target: Nav; signalName: "openAlbum" }
    SignalSpy { id: searchSpy; target: Nav; signalName: "search" }

    function initTestCase() {
        Qt.application.organization = "ryugin-tests";
        Qt.application.domain = "tests";
        mock.connect();
    }
    function init() {
        Player.repeat = "off";
        Player.bridge = null;
        Nav.lyrics = false;
        Nav.queue = false;
        openSpy.clear();
        searchSpy.clear();
    }

    function findChildren(item, name) {
        let out = item.objectName === name ? [item] : [];
        for (const c of item.children)
            out = out.concat(findChildren(c, name));
        return out;
    }
    function create(file, props) {
        const c = Qt.createComponent(Qt.resolvedUrl("../../qml/" + file));
        verify(c.status === Component.Ready, file + ": " + c.errorString());
        const o = createTemporaryObject(c, root, props || {});
        verify(o !== null, file);
        return o;
    }
    function album() {
        return { id: "a", title: "Green", artist: "Hiroshi Yoshimura", artistId: "ar1", cover: "c", year: 1986, songCount: 3, duration: 735 };
    }
    function albumTracks() {
        let got = null;
        Api.getAlbum("a", function (a, t) { got = t; });
        tryVerify(function () { return got !== null; }, 5000);
        return got;
    }

    // ---- Every component builds without errors.
    function test_component_loads_data() {
        return ["HomePage.qml", "AlbumsPage.qml", "AlbumPage.qml", "ArtistsPage.qml", "ArtistPage.qml",
                "PlaylistsPage.qml", "PlaylistPage.qml", "SearchPage.qml", "SettingsPage.qml", "PlayerBar.qml",
                "NowPlaying.qml", "QueuePanel.qml", "Sidebar.qml", "Header.qml", "TrackList.qml", "AlbumCard.qml",
                "Shelf.qml", "Scroller.qml", "AlbumGrid.qml", "Cover.qml", "Card.qml", "Field.qml", "Toggle.qml", "TextButton.qml",
                "IconButton.qml", "Glyph.qml", "GoldSlider.qml", "WhiteSlider.qml", "SectionTitle.qml", "Icon.qml"]
            .map(function (f) { return { tag: f, file: f }; });
    }
    function test_component_loads(d) {
        const o = create(d.file, { width: 1000, height: 700 });
        wait(50);
        verify(o.visible !== undefined);
    }

    // ---- Every icon name in the QML has an SVG in Icons.qml.
    function test_icon_is_drawn_at_its_size() {
        // Qt ignores sourceSize for data: URLs: the SVG must carry its pixel size.
        const icon = create("Icon.qml", { name: "heart-fill", size: 40 }) // Lucide (not in Icons.theme);
        tryCompare(icon.image, "status", Image.Ready);
        compare(icon.image.implicitWidth, 40 * (Screen.devicePixelRatio || 1));
        // A new colour (a new song) tints the same picture: no reload, no blink.
        const src = icon.image.source;
        icon.color = "#ff0000";
        compare(icon.image.source, src);
        compare(icon.image.status, Image.Ready);
    }
    function test_icons_exist() {
        const files = ["AlbumCard", "AlbumPage", "ArtistPage", "ArtistsPage", "Cover", "Header", "HomePage", "Main",
                       "NowPlaying", "PlayerBar", "PlaylistPage", "SearchPage", "SettingsPage", "Sidebar", "TrackList"];
        const missing = [];
        let seen = 0;
        for (const f of files) {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", Qt.resolvedUrl("../../qml/" + f + ".qml"), false);
            xhr.send();
            for (const line of xhr.responseText.split("\n")) {
                const m = line.match(/\b(icon|name)\s*:\s*(.*)$/);
                if (!m)
                    continue;
                for (const lit of m[2].match(/"[a-z0-9-]+"/g) || []) {
                    const n = lit.slice(1, -1);
                    if (/^[a-z]+(-[a-z0-9]+)*$/.test(n) && n.indexOf("ryugin-") !== 0 && ["home", "albums", "favorites", "starred", "artists", "playlists", "settings", "search", "lyrics", "queue", "navidrome", "look", "cache", "about"].indexOf(n) < 0) {
                        seen++;
                        if (!Icons.svg[n])
                            missing.push(f + ": " + n);
                    }
                }
            }
        }
        verify(seen > 20, "found only " + seen + " icon names");
        compare(missing, []);
    }

    function test_icon_colour_and_alpha() {
        // The SVG is white; the colour (alpha too) goes to the tint shader.
        const icon = create("Icon.qml", { name: "dices", color: Qt.rgba(1, 0, 0, 0.5) }) // Lucide;
        const svg = decodeURIComponent(icon.image.source.toString());
        verify(svg.indexOf("#ffffff") > 0, svg);
        verify(!/#[0-9a-f]{8}/.test(svg), "8-digit colours break the SVG renderer");
        tryCompare(icon.image, "status", Image.Ready);
        compare(create("Icon.qml", { name: "no-such-icon" }).image.source.toString(), "");
    }

    // ---- Album cards: click opens, double-click and ▶ play the whole album.
    function test_album_card_click_opens_album() {
        const card = create("AlbumCard.qml", { album: album() });
        mouseClick(card, 60, 60);
        openSpy.wait(1000);
        compare(openSpy.signalArguments[0][0], "a");
    }
    function test_album_card_double_click_plays_album() {
        Player.play([], 0);
        const card = create("AlbumCard.qml", { album: album() });
        mouseDoubleClickSequence(card, 60, 60);
        tryVerify(function () { return Player.queue.length === 3; }, 5000);
        compare(Player.index, 0);
        compare(Player.current.title, "Blink");
        wait(400);
        compare(openSpy.count, 0, "a double-click must not also open the album");
    }
    function test_album_card_play_button() {
        Player.play([], 0);
        const card = create("AlbumCard.qml", { album: album() });
        mouseMove(card, 60, 60);
        mouseClick(card, card.width - 31, card.width - 31);
        tryVerify(function () { return Player.queue.length === 3; }, 5000);
        wait(400);
        compare(openSpy.count, 0);
    }

    // ---- Song cards (recently played): as every cover, a click opens the album; ▶ plays the
    // songs from it.
    function test_song_card() {
        const tracks = albumTracks();
        const songs = [tracks[2], tracks[0]];
        const card = create("AlbumCard.qml", { song: songs[1], songs: songs });
        compare(card.children[1].text, tracks[0].title);
        const opened = openSpy.count;
        mouseClick(card, 60, 60);
        compare(openSpy.count, opened + 1, "the cover opens the album");
        mouseMove(card, 60, 60);
        mouseClick(card, card.width - 28, card.width - 28);
        compare(Player.queue.length, 2);
        compare(Player.current.id, tracks[0].id, "▶ plays the songs from it");
    }
    function test_home_recent_songs() {
        Player.play(albumTracks(), 1);
        const home = create("HomePage.qml", { width: 1200, height: 800 });
        const shelf = findChild(home, "recentSongs");
        verify(shelf.visible);
        compare(shelf.songs[0].id, Player.current.id);
    }

    // ---- Covers: one the server cannot resize comes at its original size; none, the ♪.
    function test_cover_falls_back_to_the_original() {
        const c = create("Cover.qml", { width: 100, height: 100, coverId: "unresizable" });
        tryCompare(c, "ready", true, 5000);
        verify(c.original);
        c.coverId = "c";
        verify(!c.original);
        tryCompare(c, "ready", true, 5000);
        const none = create("Cover.qml", { width: 100, height: 100 });
        wait(100);
        verify(!none.ready);
        // A wide picture fills the square, cropped: its middle half shows (cover.frag).
        const wide = create("Cover.qml", { width: 100, height: 100, coverId: "wide" });
        tryCompare(wide, "ready", true, 5000);
        const art = findChildren(wide, "").filter(function (o) { return o.crop !== undefined; })[0];
        compare(art.crop, Qt.size(0.5, 1));
    }

    // ---- Scrollbars: shown on the desktop when there is more, never when there is not.
    function test_scrollbars() {
        const page = create("AlbumsPage.qml", { width: 400, height: 200 });
        const bar = findChild(page, "scrollbar");
        tryVerify(function () { return page.albums.length > 2; }, 5000);
        tryCompare(bar, "policy", C.ScrollBar.AlwaysOn);
        Nav.phone = true;
        compare(bar.policy, C.ScrollBar.AsNeeded, "a phone shows it only while scrolling");
        Nav.phone = false;
        const empty = create("Page.qml", { width: 400, height: 600 });
        compare(findChild(empty, "scrollbar").policy, C.ScrollBar.AlwaysOff);
    }

    // ---- Track list: a click plays from that track; the star tells the server.
    function test_track_click_plays_from_there() {
        const list = create("TrackList.qml", { width: 800, tracks: albumTracks() });
        waitForRendering(list);
        mouseClick(list, 300, 76 + 12 + 38); // second card
        compare(Player.index, 1);
        compare(Player.current.title, "Creek");
        compare(Player.queue.length, 3);
    }
    function test_track_star() {
        mock.calls(true);
        const tracks = albumTracks();
        const list = create("TrackList.qml", { width: 800, tracks: tracks });
        waitForRendering(list);
        mouseClick(list, 800 - 25, 38);
        tryVerify(function () { return mock.called("star", "id=s0"); }, 5000);
        verify(list.tracks[0].starred, "the list keeps the new state");
        mouseClick(list, 800 - 25, 38);
        verify(!list.tracks[0].starred);
        tryVerify(function () { return mock.called("unstar", "id=s0"); }, 5000);
    }

    // ---- Player bar
    function test_repeat_button_cycles() {
        const bar = create("PlayerBar.qml", { width: 1280 });
        const repeat = findChild(bar, "repeat");
        verify(repeat);
        mouseClick(repeat);
        compare(Player.repeat, "all");
        mouseClick(repeat);
        compare(Player.repeat, "one");
        mouseClick(repeat);
        compare(Player.repeat, "off");
    }

    // ---- Layout: the song left, the controls in the middle, the progress under all;
    // the wheel anywhere over the song opens Now Playing and closes it.
    function test_bar_song_left_wheel() {
        Player.play(albumTracks(), 0);
        const bar = create("PlayerBar.qml", { width: 1280 });
        const song = findChild(bar, "song"), controls = findChild(bar, "controls"), progress = findChild(bar, "progress");
        compare(song.x, 18);
        fuzzyCompare(controls.x + controls.width / 2, 640, 1);
        verify(song.x + song.width < controls.x, "the title stops before the controls");
        verify(progress.width > 1200, "the progress runs the bar's width");
        Nav.lyrics = false;
        mouseWheel(song, song.width - 10, song.height / 2, 0, 120);
        verify(Nav.lyrics, "wheel up over the title opens");
        mouseWheel(song, 10, song.height / 2, 0, -120);
        verify(!Nav.lyrics, "wheel down over the cover closes");
    }

    // ---- Fullscreen: lyrics only when there are some; the queue takes their place.
    function test_now_playing_states() {
        Player.play(albumTracks(), 2); // s2: no lyrics
        const np = create("NowPlaying.qml", { width: 1280, height: 820 });
        tryVerify(function () { return Player.lyrics.length === 0; }, 5000);
        verify(!np.hasLyrics);
        verify(!np.lyricVisible);
        verify(np.centered, "without lyrics the cover sits in the middle");
        Player.lyrics = [{ time: 0, text: "a" }, { time: 1000, text: "b" }];
        Player.lyricsSynced = true;
        verify(np.lyricVisible);
        verify(!np.centered);
        np.showQueue = true;
        verify(!np.lyricVisible);
        verify(!np.centered);
        np.showQueue = false;
        np.showLyrics = false;
        verify(np.centered);
    }

    // ---- Word-timed lyrics: the line being sung lights up word by word, the others stay plain.
    function test_lyrics_word_highlight() {
        const np = create("NowPlaying.qml", { width: 1280, height: 820 });
        Player.lyrics = Api.lrc("[00:00.00]<00:00.00>布<00:01.00>団 & <00:02.00>\n[00:05.00]<00:05.00>next<00:06.00>");
        Player.lyricsSynced = true;
        compare(Player.lyricIndex, 0);
        const lines = findChild(np, "lyricLines");
        lines.ms = 500; // half way through the first word, before the second
        const line = lines.itemAtIndex(0);
        compare(line.textFormat, Text.StyledText);
        const alpha = function (html) {
            return html.match(/color="#(..)/g).map(function (c) { return parseInt(c.slice(-2), 16); });
        };
        const a = alpha(line.text);
        compare(a.length, 2);
        verify(a[0] > a[1], "the word being sung is brighter than the next: " + a);
        verify(line.text.indexOf("&amp;") > 0, "text is escaped");
        lines.ms = 2500;
        const b = alpha(lines.itemAtIndex(0).text);
        compare(b[0], b[1]);
        compare(b[0], Math.round(np.ink.a * 255), "sung words are full ink");
        tryVerify(function () { return lines.itemAtIndex(1); });
        compare(lines.itemAtIndex(1).textFormat, Text.PlainText);
        compare(lines.itemAtIndex(1).text, "next");
    }

    // ---- Progress: dragging does not fight the song; the seek happens on release.
    QtObject { id: fakeBridge; objectName: "" }
    function test_progress_seeks_on_release() {
        Player.play(albumTracks(), 0);
        const bar = create("PlayerBar.qml", { width: 1280 });
        const s = findChild(bar, "progress");
        verify(s);
        Player.bridge = fakeBridge;
        fakeBridge.objectName = "";
        mousePress(s, s.width * 0.75, s.height / 2);
        verify(Math.abs(s.value - s.to * 0.75) < s.to * 0.03, "the bar follows the mouse: " + s.value);
        verify(fakeBridge.objectName === "" || !JSON.parse(fakeBridge.objectName).seeked, "no seek while held");
        mouseMove(s, s.width * 0.5, s.height / 2);
        verify(Math.abs(s.value - s.to * 0.5) < s.to * 0.03, "drag: " + s.value);
        mouseRelease(s, s.width * 0.5, s.height / 2);
        verify(JSON.parse(fakeBridge.objectName).seeked, "seek on release");
        Player.bridge = null;
    }

    // ---- Fullscreen: real previous/next icons, not rewind/forward.
    function test_now_playing_skip_icons() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../../qml/NowPlaying.qml"), false);
        xhr.send();
        verify(xhr.responseText.indexOf('"skip-back"') > 0);
        verify(xhr.responseText.indexOf('"skip-forward"') > 0);
        verify(xhr.responseText.indexOf("rewind") < 0 && xhr.responseText.indexOf('"forward-fill"') < 0);
    }

    // ---- Fullscreen: controls show while the mouse moves, and hide when it rests.
    function test_now_playing_hides_controls() {
        Player.play(albumTracks(), 2);
        const np = create("NowPlaying.qml", { width: 1280, height: 820 });
        mouseMove(np, 300, 300);
        mouseMove(np, 320, 310);
        tryCompare(np, "chrome", 1, 1000);
        tryCompare(np, "chrome", 0, 4000);
        verify(np.idle);
        mouseMove(np, 340, 320);
        tryCompare(np, "chrome", 1, 1000);
    }

    // ---- Fullscreen: the four layouts, picked from the switcher and remembered.
    function test_now_playing_layouts() {
        Player.play(albumTracks(), 0);
        const np = create("NowPlaying.qml", { width: 1280, height: 820 });
        const switcher = findChild(np, "switcher");
        verify(switcher);
        mouseMove(np, 600, 400); // the bars show
        mouseMove(np, 610, 410);
        tryCompare(np, "chrome", 1, 1000);
        wait(450);
        mouseClick(findChild(np, "layoutButton"));
        verify(switcher.open);
        for (const id of ["fullCover", "fullLyric", "controls", "classic"]) {
            switcher.open = true;
            wait(200);
            mouseClick(findChild(np, "layout-" + id));
            compare(Player.settings.layout, id);
            compare(np.layout, id);
            verify(!switcher.open, "picking closes the switcher");
            wait(50);
        }
        Player.settings.layout = "fullLyric";
        verify(!np.centered, "the lyric layouts never centre a cover");
        Player.settings.layout = "classic";

        // The background: SPlayer's still blur or its moving flow.
        const blur = findChild(np, "blurBackdrop"), flow = findChild(np, "flowBackdrop");
        switcher.open = true;
        wait(200);
        mouseClick(findChild(np, "backdrop-flow"));
        compare(Player.settings.backdrop, "flow");
        verify(flow.visible && !blur.visible);
        verify(switcher.open, "the background is picked without closing");
        mouseClick(findChild(np, "backdrop-blur"));
        compare(Player.settings.backdrop, "blur");
        verify(blur.visible && !flow.visible);
        switcher.open = false;
    }

    // ---- Home: the three shelves come from Navidrome.
    function test_home_loads_library() {
        const home = create("HomePage.qml", { width: 1200, height: 800 });
        // Before Navidrome answers, the rows already hold their place: no jump as they come.
        const shelves = findChildren(home, "shelf");
        compare(home.recent, null);
        verify(shelves.length === 3 && shelves.every(function (s) { return s.visible && s.loading; }), "the rows wait in place");
        tryVerify(function () { return home.recent && home.recent.length === 4; }, 5000);
        tryVerify(function () { return home.frequent && home.frequent.length === 4; }, 5000);
        tryVerify(function () { return home.newest && home.newest.length === 4; }, 5000);
        verify(shelves.every(function (s) { return !s.loading; }));
    }

    // ---- Library › Favorites: the liked albums; the sidebar's heart plays the liked songs.
    function test_favorites_page() {
        const page = create("AlbumsPage.qml", { width: 1200, height: 800, type: "starred" });
        tryVerify(function () { return page.albums.length === 4; }, 5000);
        const side = create("Sidebar.qml", { height: 800 });
        Player.queue = [];
        mouseClick(findChild(side, "playFavorites"));
        tryVerify(function () { return Player.queue.length > 0 && Player.index === 0; }, 5000, "the heart plays the liked songs");
    }

    // ---- Karaoke from the sidebar: songs mixed, karaoke on, the lyrics full screen.
    function test_sidebar_karaoke() {
        const side = create("Sidebar.qml", { height: 800 });
        Player.queue = [];
        mouseClick(findChild(side, "karaoke"));
        tryVerify(function () { return Player.queue.length > 0 && Player.karaoke && Nav.lyrics; }, 5000);
        Player.settings.karaoke = false;
        Nav.lyrics = false;
    }

    // ---- A playlist: Delete asks again in place, then deletes it and goes back.
    function test_delete_playlist() {
        const page = create("PlaylistPage.qml", { width: 1000, height: 700, playlistId: "p1", name: "Ambient" });
        const back = Qt.createQmlObject("import QtTest; SignalSpy { signalName: 'back' }", root);
        back.target = Nav;
        try {
            findChild(page, "deletePlaylist").clicked();
            verify(page.confirming);
            verify(findChild(page, "confirmDelete").visible);
            findChild(page, "confirmDelete").clicked();
            tryCompare(back, "count", 1);
        } finally {
            back.destroy();
        }
    }

    // ---- Settings › Home: rows hidden and moved, Home follows.
    function test_home_rows() {
        const home = create("HomePage.qml", { width: 1200, height: 800 });
        const page = create("SettingsPage.qml", { width: 800, height: 900, section: "home" });
        try {
            page.showRow("frequent", false);
            compare(findChildren(home, "shelf").length, 2, "most played hidden");
            page.moveRow("newest", -1);
            compare(Nav.layout.homeOrder, "recentSongs recent newest frequent");
            page.moveTo("recentSongs", 9); // dragged past the end: last
            compare(Nav.layout.homeOrder, "recent newest frequent recentSongs");
            page.showRow("frequent", true);
            compare(findChildren(home, "shelf").length, 3);
        } finally {
            Nav.layout.homeOrder = "recentSongs recent frequent newest";
            Nav.layout.homeHidden = "";
        }
    }

    // ---- The sidebar's search: typing searches.
    function test_header_search() {
        const side = create("Sidebar.qml", { height: 800 });
        const field = findChild(side, "sideSearch");
        field.forceActiveFocus();
        keyClick("y");
        keyClick("o");
        tryVerify(function () { return searchSpy.count >= 2; }, 2000);
        compare(searchSpy.signalArguments[searchSpy.count - 1][0], "yo");
        keyClick(Qt.Key_Escape); // leaves the field; open, the sidebar stays
        verify(!field.activeFocus);
        verify(!Nav.layout.folded);
        // Folded, Ctrl+F opens it for the search; Escape folds it again.
        Nav.layout.folded = true;
        try {
            Nav.openSearch();
            tryVerify(function () { return field.activeFocus; }, 2000);
            verify(!Nav.layout.folded);
            keyClick(Qt.Key_Escape);
            verify(!field.activeFocus);
            verify(Nav.layout.folded, "folded again");
            Nav.openSearch(); // left by a click elsewhere: it stays open
            tryVerify(function () { return field.activeFocus; }, 2000);
            field.focus = false;
            verify(!Nav.layout.folded && !Nav.refold);
        } finally {
            Nav.layout.folded = false;
        }
    }

    // ---- The sidebar's Queue: opens and closes the queue, counts its songs; a liked song has a heart, × removes it.
    function test_side_queue() {
        Player.queue = [{ id: "s0", title: "a", artist: "b", album: "c", albumId: "a", cover: "", starred: true }];
        try {
            const side = create("Sidebar.qml", { height: 800 });
            const entry = findChild(side, "sideQueue");
            compare(entry.count, "1");
            mouseClick(entry);
            verify(Nav.queue);
            mouseClick(entry);
            verify(!Nav.queue);
            const panel = create("QueuePanel.qml", { width: 360, height: 600 });
            tryVerify(function () { return findChildren(panel, "").some(function (c) { return c.name === "heart-fill" && c.visible; }); }, 2000);
            compare(findChildren(panel, "queueRemove").length, 0, "no × until a hover");
            // Save as playlist: a name field; × or Escape cancels.
            findChild(panel, "savePlaylist").clicked();
            const name = findChild(panel, "playlistName");
            verify(name.visible);
            keyClick(Qt.Key_Escape);
            verify(!name.visible, "Escape cancels");
            findChild(panel, "savePlaylist").clicked();
            findChild(panel, "cancelPlaylist").clicked();
            verify(!name.visible, "× cancels");
            // Its grip moves a song.
            Player.queue = Player.queue.concat([{ id: "s1", title: "d", artist: "b", album: "c", albumId: "a", cover: "" }]);
            const grips = function () { return findChildren(panel, "queueGrip").filter(function (g) { return g.parent.visible; }); };
            tryVerify(function () { return grips().length === 2; });
            const grip = grips().sort(function (a, b) { return a.mapToItem(panel, 0, 0).y - b.mapToItem(panel, 0, 0).y; })[0];
            mousePress(grip, 10, 10);
            mouseMove(grip, 10, 30);
            mouseMove(grip, 10, 50);
            mouseRelease(grip, 10, 50);
            compare(Player.queue.map(function (t) { return t.id; }).join(" "), "s1 s0", "dragged down by one");
            // × takes the song out; it is made on hover only (a long queue scrolls lighter).
            const remove = function () { return findChildren(panel, "queueRemove"); };
            mouseMove(grips()[0], 20, 10);
            tryVerify(function () { return remove().length === 1; }, 1000, "× on the row under the pointer");
            remove()[0].clicked();
            compare(Player.queue.length, 1);
        } finally {
            Player.queue = [];
        }
    }

    // ---- An album hidden from its page is listed in Settings, where its eye shows it again.
    function test_hide_album() {
        const known = Api.known.albums;
        try {
            mock.calls(true);
            const page = create("AlbumPage.qml", { albumId: "a", width: 1000, height: 800 });
            tryVerify(function () { return page.album !== null; }, 5000);
            const button = findChild(page, "hideAlbum");
            compare(button.text, "Hide album");
            button.clicked();
            tryVerify(function () { return mock.called("setRating", "id=a&rating=1"); }, 5000);
            compare(button.text, "Show album");
            const settings = create("SettingsPage.qml", { width: 800, height: 900 });
            const hidden = findChild(settings, "hiddenAlbums");
            verify(hidden.visible);
            const eye = findChildren(hidden, "").filter(function (c) { return c.icon === "eye"; });
            compare(eye.length, 1);
            eye[0].clicked();
            tryVerify(function () { return mock.called("setRating", "id=a&rating=0"); }, 5000);
            verify(!hidden.visible, "none hidden: no list");
            compare(button.text, "Hide album");
        } finally {
            Api.known.albums = known;
        }
    }

    // ---- The preferences show the version the build set.
    function test_settings_version() {
        Qt.application.version = "9.8.7";
        const about = findChild(create("SettingsPage.qml", { width: 800, height: 900 }), "about");
        verify(about.text.indexOf("Ryūgin 龍吟 9.8.7,") === 0, about.text);
        Qt.application.version = "";
    }

    // ---- The cache: songs off hides their size, not the covers; sizes read in MB, then GB.
    function test_settings_cache() {
        const page = create("SettingsPage.qml", { width: 800, height: 900, section: "cache" });
        const toggle = findChild(page, "cacheToggle");
        const limit = findChild(page, "cacheLimit");
        try {
            verify(toggle.checked && limit.visible);
            mouseClick(toggle);
            verify(!Player.settings.cache);
            verify(!limit.visible, "off: no size");
            page.showUsed({ songs: 5 << 20, covers: 3 * 1024 * 1024 * 1024 });
            compare(findChild(page, "cacheSize").desc, "5 MB used");
            compare(findChild(page, "coverCache").desc, "3.0 GB used · every album's, kept offline");
            verify(findChild(page, "coverCache").visible, "covers: always kept");
        } finally {
            Player.settings.cache = true;
        }
    }

    // ---- The close button: the phone's way out of the settings.
    function test_settings_close() {
        const page = create("SettingsPage.qml", { width: 800, height: 900 });
        let closed = false;
        page.closeRequested.connect(function () { closed = true; });
        const x = findChild(page, "settingsClose");
        verify(x.visible, "a server is set: it can close");
        mouseClick(x);
        verify(closed);
    }

    // ---- The mouse wheel on the volume: 5 % a notch.
    function test_volume_wheel() {
        const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root);
        const v = findChild(w.contentItem, "volume");
        waitForRendering(w.contentItem);
        Player.setVolume(0.5);
        mouseWheel(v, v.width / 2, v.height / 2, 0, 120);
        fuzzyCompare(Player.settings.volume, 0.55, 0.001);
        mouseWheel(v, v.width / 2, v.height / 2, 0, -240);
        fuzzyCompare(Player.settings.volume, 0.45, 0.001);
        Player.setVolume(0.8);
    }

    // ---- Main window: history, search, Go commands, the tray.
    // ---- A new scan in Navidrome: the lists reload in place; the same scan, nothing.
    // ---- Settings › Library › Scan: Navidrome scans, the pages reload at its end.
    function test_settings_scan() {
        Api.lastScan = "before"; // the mark of an older scan
        const page = create("SettingsPage.qml", { width: 800, height: 900 });
        const button = findChild(page, "scanButton");
        verify(findChild(page, "scan").visible);
        let changed = false;
        const mark = function () { changed = true; };
        Api.libraryChanged.connect(mark);
        try {
            mock.calls(true);
            mouseClick(button);
            tryVerify(function () { return mock.called("startScan"); }, 5000);
            tryVerify(function () { return changed && !Api.scanning; }, 5000);
            compare(Api.songTotal, 1234);
        } finally {
            Api.libraryChanged.disconnect(mark);
        }
    }

    function test_library_refresh() {
        const home = create("HomePage.qml", { width: 1200, height: 800 });
        const albums = create("AlbumsPage.qml", { width: 1200, height: 800 });
        const artists = create("ArtistsPage.qml", { width: 1200, height: 800 });
        tryVerify(function () { return home.newest && albums.albums.length > 0 && artists.artists.length > 0; }, 5000);
        Api.lastScan = "";
        Api.checkLibrary(); // the mark
        tryVerify(function () { return Api.lastScan !== ""; }, 5000);
        let scans = 0;
        const count = function () { scans++; };
        Api.scanned.connect(count); // the new songs' lyrics looked at (Player)
        mock.calls(true);
        Api.checkLibrary(); // the same scan
        wait(300);
        verify(!mock.called("getAlbumList2") && !mock.called("getArtists"), "no new scan, no reload");
        compare(scans, 0);
        mock.scan();
        Api.checkLibrary();
        tryVerify(function () { return mock.called("getAlbumList2", "type=newest") && mock.called("getAlbumList2", "alphabeticalByName") && mock.called("getArtists"); }, 5000);
        compare(scans, 1);
        Api.scanned.disconnect(count);
        verify(home.newest.length > 0 && albums.albums.length > 0, "the old lists stay while the new ones come");
        // A scan still running: asked again on its own until it ends, then the reload.
        mock.scan(true);
        Api.checkLibrary();
        tryVerify(function () { return Api.scanWait.running; }, 5000);
        mock.calls(true);
        Api.scanWait.interval = 100;
        mock.scan();
        tryVerify(function () { return mock.called("getAlbumList2", "alphabeticalByName"); }, 5000);
        verify(!Api.scanWait.running, "the scan ended: no more asking");
        Api.scanWait.interval = 30000;
    }

    // ---- Its menu again: the page is kept (no blink), scrolled to the top; from an album
    // opened there, back to that same page.
    function test_menu_again_keeps_the_page() {
        const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root, { height: 500 });
        w.go("home");
        let greeting = null;
        tryVerify(function () { greeting = findChild(w.contentItem, "home"); return greeting !== null; });
        let page = greeting;
        while (page && page.contentY === undefined)
            page = page.parent;
        tryVerify(function () { return page.contentHeight > page.height; }, 5000);
        page.contentY = 300;
        w.go("home");
        compare(findChild(w.contentItem, "home"), greeting, "the same page, not a new one");
        tryCompare(page, "contentY", page.originY, 2000, "back to the top");
        Nav.openAlbum("a");
        w.go("home");
        tryCompare(findChild(w.contentItem, "home"), "visible", true);
        compare(findChild(w.contentItem, "home"), greeting, "back to the page as it was");
    }

    // ---- The window resized: the closed player stays out of sight (it slid in, following
    // the height); opened, it fills the window at once.
    function test_resize_keeps_the_player_closed() {
        const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root);
        const np = findChild(w.contentItem, "nowPlaying");
        verify(!np.visible);
        let shown = false;
        const seen = function () { shown = shown || np.visible; };
        np.visibleChanged.connect(seen);
        const h = w.contentItem.height;
        w.height += 200;
        tryVerify(function () { return w.contentItem.height > h; }, 2000);
        wait(100);
        np.visibleChanged.disconnect(seen);
        verify(!shown, "closed: nothing slides in");
        Nav.lyrics = true;
        tryCompare(np, "y", 0);
        w.height -= 100;
        compare(np.y, 0, "open: still in place");
        compare(np.height, w.contentItem.height);
        Nav.lyrics = false;
        tryVerify(function () { return !np.visible; }, 2000);
    }

    // ---- The gear opens Navidrome as a popup; a second click closes it.
    function test_settings_popup() {
        const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root);
        w.go("albums");
        w.go("settings");
        tryVerify(function () { return w.settingsOpen; });
        compare(w.section, "albums", "the page under the popup stays");
        w.go("settings");
        tryVerify(function () { return !w.settingsOpen; }, 1000, "the gear closes it again");
        w.go("settings");
        tryVerify(function () { return w.settingsOpen; });
        w.go("home"); // any page closes it
        tryVerify(function () { return !w.settingsOpen; });
        compare(w.section, "home");
    }

    // ---- Global menu (menu.go) commands reach the window.
    function test_menu_commands() {
        const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root);
        let n = 0;
        const send = function (c) { c.n = ++n; w.goCommand = JSON.stringify(c); };
        send({ cmd: "go", page: "artists" });
        compare(w.section, "artists");
        const lyrics = Nav.lyrics, queue = Nav.queue;
        send({ cmd: "nowPlaying" });
        compare(Nav.lyrics, !lyrics);
        send({ cmd: "nowPlaying" });
        send({ cmd: "queue" });
        compare(Nav.queue, !queue);
        send({ cmd: "queue" });
        send({ cmd: "backdrop", value: "flow" });
        compare(Player.settings.backdrop, "flow");
        send({ cmd: "backdrop", value: "blur" });
        compare(Player.settings.backdrop, "blur");
        const repeat = Player.repeat;
        send({ cmd: "repeat" });
        verify(Player.repeat !== repeat);
        Player.repeat = repeat;
        Player.play(albumTracks(), 0);
        const starred = !!Player.current.starred;
        send({ cmd: "like" });
        compare(!!Player.current.starred, !starred);
        send({ cmd: "like" });
        send({ cmd: "lucky" });
        tryVerify(function () { return Player.queue.length > 0 && Player.index === 0; });
    }

    // ---- The layout popup is frosted glass over what lies behind it.
    function test_switcher_frost() {
        const np = create("NowPlaying.qml", { width: 1280, height: 820 });
        const frost = findChild(np, "frost");
        verify(frost);
        verify(frost.blurEnabled && frost.blur > 0);
        verify(frost.source);
    }

    // ---- Phone (Sailfish OS): tabs at the bottom, no rail, compact bar, one column, and the
    // fullscreen player as the cover over its controls with lyrics in its place.
    function test_phone() {
        Nav.phone = true;
        try {
            const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root, { width: 432, height: 900 });
            const tabs = findChild(w.contentItem, "tabs");
            compare(w.topInset, 36, "upright: room for the notch");
            const search = findChild(w.contentItem, "search");
            verify(search.mapToItem(null, 0, 0).y >= 36, "the search field is under the notch's band");
            verify(search.mapToItem(null, 0, 0).x + search.width <= 432, "the search field fits the screen");
            verify(tabs.visible && tabs.height > 0);
            waitForRendering(w.contentItem); // its own window: clicks wait until it is shown
            mouseClick(findChild(tabs, "tab-albums"));
            compare(w.section, "albums");
            let albums = null;
            tryVerify(function () { albums = findChild(w.contentItem, "albumGrid"); return albums !== null && albums.width > 0; });
            compare(albums.columns, 2, "two columns of albums, not one and half the width empty");
            w.width = 354; // the Jolla Phone's width
            compare(albums.columns, 2, "two columns on the narrowest phone too");
            compare(albums.cellHeight - albums.card - albums.titles, albums.cellWidth - albums.card, "the same gap between rows as between cards");
            // On its side: the pages move to a rail at the left.
            w.width = 900;
            w.height = 432;
            const rail = findChild(w.contentItem, "sidebar");
            tryVerify(function () { return !tabs.visible && rail.visible && rail.width > 0; }, 1000, "a rail, no tabs");
            tryVerify(function () { return albums.columns >= 4; }, 1000, "more columns on its side");
            w.width = 432;
            w.height = 900;
            tryVerify(function () { return tabs.visible && !rail.visible; }, 1000, "upright: tabs again");
            mouseClick(findChild(tabs, "tab-settings"));
            tryVerify(function () { return w.settingsOpen; });
            w.go("home");

            const np = create("NowPlaying.qml", { width: 432, height: 900, topInset: 36 });
            verify(findChild(np, "lyricLines").mapToItem(np, 0, 0).y >= 36, "nothing under the notch");
            compare(np.layout, "controls");
            verify(!np.showLyrics, "a phone opens on the cover");
            compare(np.chrome, 1, "no hover on a phone: the buttons stay");
            verify(!findChild(np, "layoutButton").visible);
            Player.lyrics = [{ time: 0, text: "a" }];
            Player.lyricsSynced = true;
            np.showLyrics = true;
            verify(np.lyricVisible);
            const lines = findChild(np, "lyricLines");
            const p = lines.mapToItem(np, 0, 0);
            verify(p.x >= 0 && p.x + lines.width <= np.width, "lyrics fit the screen");
            verify(findChild(np, "lyricsToggle").visible, "a button shows the lyrics");
            // The playlist takes the cover's place: one fades out, then the other in.
            np.showLyrics = false;
            const ctl = findChild(np, "controlsGrid").parent, list = findChild(np, "queuePanel");
            tryCompare(ctl, "opacity", 1);
            for (const open of [true, false]) {
                np.showQueue = open;
                for (let t = 0; t < 600; t += 20) {
                    verify(ctl.opacity === 0 || list.opacity === 0, "cover and playlist both shown: " + open + " " + t + " " + ctl.opacity + " " + list.opacity);
                    wait(20);
                }
                compare(list.opacity, open ? 1 : 0);
                compare(ctl.opacity, open ? 0 : 1);
            }

            // On its side: the cover beside its controls, inside the screen; the queue has room.
            w.width = 900; w.height = 400; // the phone turns
            tryCompare(w, "topInset", 0); // on its side the system keeps the notch's band
            const side = create("NowPlaying.qml", { width: 900, height: 400 });
            verify(side.wide);
            const box = findChild(side, "controlsCoverBox"), grid = findChild(side, "controlsGrid");
            const b = box.mapToItem(side, 0, 0), gp = grid.mapToItem(side, 0, 0);
            verify(b.y >= 0 && b.y + box.height <= side.height, "the cover fits the height");
            verify(gp.x >= 0 && gp.x + grid.width <= side.width, "cover and controls fit the width");
            const q = findChild(side, "queuePanel");
            verify(q.height >= side.height - 40, "the queue takes the screen's height");
        } finally {
            Nav.phone = false;
        }
    }

    // A double tap on the cover opens the playlist; pulling down from above the cover closes.
    function test_now_playing_gestures() {
        Nav.phone = true;
        try {
            Player.queue = [{ id: "s0", title: "a", artist: "b", album: "c", albumId: "a", artistId: "ar1", cover: "" }];
            const np = create("NowPlaying.qml", { width: 432, height: 900, topInset: 36 });
            Nav.lyrics = true;
            waitForRendering(np);
            const cb = findChild(np, "controlsCoverBox");
            mouseClick(cb);
            verify(!np.showQueue, "one tap is not enough");
            mouseClick(cb);
            tryVerify(function () { return np.showQueue; }, 2000, "a double tap opens the playlist");
            np.showQueue = false;
            const zone = findChild(np, "pullZone");
            verify(zone.height > 100, "the space above the cover pulls");
            // A slow pull: 60 px over 0.6 s.
            const x = np.width / 2, y = zone.height - 20;
            mousePress(zone, x, y);
            for (let d = 4; d <= 60; d += 4) {
                mouseMove(zone, x, y + d, 40);
                verify(np.pull <= d - 4, "no jump by the drag threshold: " + np.pull + " at " + d);
            }
            verify(np.pull > 0 && np.pull <= 60, "follows the finger: " + np.pull);
            mouseRelease(zone, x, y + 60);
            verify(Nav.lyrics, "a short slow pull springs back");
            tryCompare(np, "pull", 0);
            mouseDrag(zone, x, y, 0, 300);
            verify(!Nav.lyrics, "a long pull closes");
            Nav.lyrics = true;
            tryCompare(np, "y", 0);
            mouseDrag(zone, x, y, 0, 80); // fast
            verify(!Nav.lyrics, "a flick down closes");
        } finally {
            Nav.phone = false;
            Nav.lyrics = false;
            Player.queue = [];
        }
    }

    // Sailfish's ways on a phone: swipe right to go back, remorse.
    function test_phone_sailfish_ways() {
        Nav.phone = true;
        try {
            const w = createTemporaryObject(Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml")), root, { width: 432, height: 900 });
            const stack = findChild(w.contentItem, "stack");
            waitForRendering(w.contentItem);

            // Swipe right: back; a short swipe springs back.
            w.open("AlbumPage.qml", { albumId: "a" });
            compare(stack.depth, 2);
            tryCompare(stack, "busy", false);
            const swipe = function (dx) {
                mousePress(stack, 40, 500);
                for (let d = 10; d <= dx; d += 10)
                    mouseMove(stack, 40 + d, 500, 15);
                mouseRelease(stack, 40 + dx, 500);
            };
            swipe(60);
            compare(stack.depth, 2);
            tryCompare(stack.currentItem, "x", 0);
            swipe(250);
            tryCompare(stack, "depth", 1);

            // The bin clears after a few seconds; a tap on its bar cancels.
            Player.queue = [{ id: "s1", title: "A", artist: "B", album: "C", albumId: "c", artistId: "b", cover: "", duration: 100 },
                            { id: "s2", title: "D", artist: "B", album: "C", albumId: "c", artistId: "b", cover: "", duration: 100 }];
            const np = create("NowPlaying.qml", { width: 432, height: 900 });
            np.showQueue = true;
            const bar = findChild(np, "remorse");
            tryCompare(findChild(np, "queuePanel"), "opacity", 1);
            mouseClick(findChild(np, "clearQueue"));
            verify(bar.visible);
            compare(Player.queue.length, 2, "not at once");
            mouseClick(bar);
            verify(!bar.visible);
            wait(4500);
            compare(Player.queue.length, 2, "cancelled");
            mouseClick(findChild(np, "clearQueue"));
            tryVerify(function () { return Player.queue.length === 0; }, 6000, "cleared after the remorse");
        } finally {
            Nav.phone = false;
            Player.queue = [];
        }
    }

    function test_main_window() {
        const c = Qt.createComponent(Qt.resolvedUrl("../../qml/Main.qml"));
        verify(c.status === Component.Ready, c.errorString());
        const w = createTemporaryObject(c, root);
        verify(w);
        const stack = findChild(w.contentItem, "stack");
        verify(stack);

        w.go("albums");
        compare(w.section, "albums");
        compare(stack.depth, 1);
        w.open("AlbumPage.qml", { albumId: "a" });
        compare(stack.depth, 2);
        w.back();
        compare(stack.depth, 1);
        compare(w.ahead.length, 1);
        w.forward();
        compare(stack.depth, 2);
        compare(w.ahead.length, 0);
        w.back();
        w.back(); // nothing left: stays
        compare(stack.depth, 1);

        // The queue: docked beside the page, over the whole middle when the window is narrow.
        const queue = findChild(w.contentItem, "queueDock"), side = findChild(w.contentItem, "sidebar");
        Nav.queue = true;
        w.width = 1400;
        tryVerify(function () { return !queue.over && queue.width === Nav.layout.queueWidth; }, 2000);
        w.width = 900;
        tryVerify(function () { return queue.over && queue.width === w.contentItem.width - side.width; }, 2000);
        Nav.queue = false;

        Nav.search("yoshi");
        compare(stack.currentItem.objectName, "search");
        compare(stack.currentItem.query, "yoshi");
        const depth = stack.depth;
        Nav.search("hiro"); // same page, new query
        compare(stack.depth, depth);
        compare(stack.currentItem.query, "hiro");
        Nav.search(""); // cleared: back to the page before
        compare(stack.depth, depth - 1);
        verify(stack.currentItem.objectName !== "search");
        Nav.search(""); // not on the search page: nothing happens
        compare(stack.depth, depth - 1);

        Player.play(albumTracks(), 0);
        w.goCommand = JSON.stringify({ cmd: "next", n: 1 });
        compare(Player.index, 1);
        w.goCommand = JSON.stringify({ cmd: "coverColor", color: "#3060c0", url: "http://elsewhere", n: 2 });
        verify(Theme.seed !== Qt.color("#3060c0"), "a colour for another cover is ignored");
        w.goCommand = JSON.stringify({ cmd: "coverColor", color: "#3060c0", url: Api.cover(Player.current.cover, 128), n: 3 });
        compare(Theme.seed, Qt.color("#3060c0"));
        w.goCommand = JSON.stringify({ cmd: "coverColor", color: "#3060c0", wash: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGMUUDBgYGBgYmBgYGBgAAAEigBkY8dNNAAAAABJRU5ErkJggg==", url: Api.cover(Player.current.cover, 128), n: 6 });
        verify(Theme.wash.startsWith("data:image/png"));

        w.hasTray = true;
        w.close();
        verify(!w.visible, "with a tray, closing hides");
        w.goCommand = JSON.stringify({ cmd: "toggleWindow", n: 4 });
        verify(w.visible);
        w.goCommand = JSON.stringify({ cmd: "toggleWindow", n: 5 });
        verify(!w.visible);
    }
}
}
