import QtQuick
import QtTest
import "../../qml"

TestCase {
    name: "Player"

    function initTestCase() {
        Qt.application.organization = "ryugin-tests";
        Qt.application.domain = "tests";
    }
    Mock { id: mock }
    QtObject { id: fakeBridge; objectName: "" }
    QtObject { id: heart; property bool liked: Player.current !== null && Player.current.starred }

    function tracks(n) {
        const l = [];
        for (let i = 0; i < n; i++)
            l.push({ id: "s" + i, title: "T" + i, artist: "A", album: "Green", albumId: "a", artistId: "ar1", cover: "c", duration: 200, starred: false, number: i + 1 });
        return l;
    }
    function init() {
        mock.connect();
        Player.repeat = "off";
        Player.bridge = null;
        Player.play(tracks(3), 0);
    }

    // ---- History: each song played goes first, once, at most 20, kept in the settings.
    function test_history() {
        Player.settings.history = "[]";
        Player.history = [];
        const l = tracks(25);
        Player.play(l, 0);
        Player.jump(1);
        Player.jump(0);
        compare(Player.history.map(function (s) { return s.id; }), ["s0", "s1"]);
        compare(JSON.parse(Player.settings.history).length, 2);
        for (let i = 0; i < 25; i++)
            Player.jump(i);
        compare(Player.history.length, 20);
        compare(Player.history[0].id, "s24");
    }

    function test_play_copies_the_list() {
        const l = tracks(3);
        Player.play(l, 1);
        compare(Player.index, 1);
        compare(Player.current.id, "s1");
        l.push({ id: "x" });
        compare(Player.queue.length, 3);
    }

    function test_remove_from_queue() {
        Player.play(tracks(4), 2);
        Player.removeAt(0); // before the playing one
        compare(Player.queue.length, 3);
        compare(Player.current.id, "s2");
        Player.removeAt(1); // the playing one: the next plays
        compare(Player.current.id, "s3");
        Player.removeAt(1); // the last, playing: it stops
        compare(Player.queue.length, 1);
        compare(Player.index, -1);
        Player.removeAt(5); // out of range: nothing
        compare(Player.queue.length, 1);
    }

    function test_clear_queue() {
        Player.clear();
        compare(Player.queue.length, 0);
        compare(Player.index, -1);
        compare(Player.current, null);
    }

    function test_next_and_end() {
        Player.next();
        compare(Player.index, 1);
        Player.next();
        compare(Player.index, 2);
        Player.next(); // end, repeat off: stays
        compare(Player.index, 2);
    }

    function test_repeat_all_wraps() {
        Player.repeat = "all";
        Player.jump(2);
        Player.next();
        compare(Player.index, 0);
    }

    function test_repeat_one_replays_on_end() {
        Player.repeat = "one";
        Player.jump(1);
        Player.ended();
        compare(Player.index, 1);
    }

    function test_cycle_repeat() {
        compare(Player.repeat, "off");
        Player.cycleRepeat();
        compare(Player.repeat, "all");
        Player.cycleRepeat();
        compare(Player.repeat, "one");
        Player.cycleRepeat();
        compare(Player.repeat, "off");
    }

    function test_previous() {
        Player.jump(2);
        Player.previous(); // at the start of a song: the one before
        compare(Player.index, 1);
        Player.jump(0);
        Player.previous(); // first song: stays
        compare(Player.index, 0);
    }

    function test_shuffle_keeps_every_track() {
        Player.shuffle(tracks(20));
        compare(Player.queue.length, 20);
        compare(Player.queue.map(function (t) { return t.id; }).sort().join(), tracks(20).map(function (t) { return t.id; }).sort().join());
    }

    function test_shuffle_rest_keeps_the_head() {
        Player.play(tracks(20), 4);
        Player.shuffleRest();
        compare(Player.index, 4);
        for (let i = 0; i <= 4; i++)
            compare(Player.queue[i].id, "s" + i);
        compare(Player.queue.length, 20);
    }

    function test_enqueue() {
        Player.enqueue(tracks(2));
        compare(Player.queue.length, 5);
        compare(Player.index, 0);
        Player.play([], 0);
        Player.index = -1;
        Player.enqueue(tracks(2));
        compare(Player.index, 0);
    }

    function test_volume_is_clamped() {
        Player.setVolume(1.5);
        compare(Player.settings.volume, 1);
        Player.setVolume(-1);
        compare(Player.settings.volume, 0);
        Player.setVolume(0.8);
    }

    function test_mpris_commands() {
        Player.command({ cmd: "next" });
        compare(Player.index, 1);
        Player.command({ cmd: "previous" });
        compare(Player.index, 0);
        Player.command({ cmd: "volume", value: 0.3 });
        compare(Player.settings.volume, 0.3);
        Player.setVolume(0.8);
        Player.command({ cmd: "unknown" }); // ignored
    }

    function test_star_toggles_and_tells_the_server() {
        mock.calls(true);
        Player.toggleStar();
        verify(Player.current.starred);
        tryVerify(function () { return mock.called("star", "id=s0"); }, 5000);
        Player.toggleStar();
        verify(!Player.current.starred);
        tryVerify(function () { return mock.called("unstar", "id=s0"); }, 5000);
    }

    function test_now_playing_is_scrobbled() {
        mock.calls(true);
        Player.jump(1);
        tryVerify(function () { return mock.called("scrobble", "id=s1&submission=false"); }, 5000);
    }

    function test_ended_scrobbles_the_play() {
        mock.calls(true);
        Player.ended();
        tryVerify(function () { return mock.called("scrobble", "id=s0&submission=true"); }, 5000);
        compare(Player.index, 1);
    }

    function test_lyrics_load_with_the_track() {
        Player.jump(0); // s0 has synced lyrics on the mock
        tryCompare(Player, "lyricsSynced", true, 5000);
        compare(Player.lyrics.length, 3);
        Player.jump(2); // s2 has none
        tryVerify(function () { return Player.lyrics.length === 0; }, 5000);
        compare(Player.lyricsSynced, false);
    }

    function test_line_at() {
        Player.lyrics = [{ time: 0, text: "a" }, { time: 4000, text: "b" }, { time: 8000, text: "c" }];
        Player.lyricsSynced = true;
        compare(Player.lineAt(0), 0);
        compare(Player.lineAt(3700), 0);
        compare(Player.lineAt(3800), 1); // 200 ms early
        compare(Player.lineAt(100000), 2);
        Player.lyrics = [{ time: 1000, text: "a" }];
        compare(Player.lineAt(0), -1);
        Player.lyricsSynced = false;
        compare(Player.lineAt(5000), -1);
    }

    function test_recent_art() {
        const history = Player.history;
        Player.history = [{ id: "1", cover: "a" }, { id: "2", cover: "a" }, { id: "3", cover: "b" }, { id: "4" }, { id: "5", cover: "c" }, { id: "6", cover: "d" }];
        const art = Player.recentArt();
        compare(art.length, 3, "3 albums, each once");
        verify(art[0].indexOf("id=a") > 0 && art[1].indexOf("id=b") > 0 && art[2].indexOf("id=c") > 0, art);
        // First songs: the server's newest albums fill in.
        Player.history = [{ id: "1", cover: "a" }];
        Player.serverCovers = ["a", "n1", "n2", "n3"];
        const filled = Player.recentArt();
        compare(filled.length, 3);
        verify(filled[0].indexOf("id=a") > 0 && filled[1].indexOf("id=n1") > 0 && filled[2].indexOf("id=n2") > 0, filled);
        Player.serverCovers = [];
        Player.history = history;
    }

    function test_reports_state_and_asks_for_the_cover_colour() {
        Player.bridge = fakeBridge;
        Player.going = false; // stopped for good
        Player.report(true, true);
        const s = JSON.parse(fakeBridge.objectName);
        compare(s.status, "Stopped");
        compare(s.seeked, true);
        Player.going = true; // between two songs: still playing for MPRIS
        Player.report(false, false);
        compare(JSON.parse(fakeBridge.objectName).status, "Playing");
        Player.going = false;
        verify(Array.isArray(s.recentArt), "the last albums' covers come with the track");
        compare(s.track.id, "s0");
        compare(s.track.length, 200000000);
        verify(s.track.art.indexOf("getCoverArt") > 0);
        Player.jump(1); // a new track: the last message asks Go for its colour
        const c = JSON.parse(fakeBridge.objectName);
        verify(c.coverUrl.indexOf("getCoverArt") > 0);
        verify(c.coverUrl.indexOf("size=128") > 0);
        compare(c.side, Player.backdropSide, "the backdrop is made for the window size");
    }

    function test_heart_follows_the_star() {
        Player.play(tracks(2), 0);
        verify(!heart.liked);
        Player.toggleStar();
        verify(heart.liked, "the heart fills");
        Player.toggleStar();
        verify(!heart.liked);
    }
    function test_set_starred_updates_every_copy() {
        const l = tracks(3).concat(tracks(1)); // s0 twice
        Player.play(l, 0);
        Player.setStarred("s0", true);
        verify(Player.queue[0].starred);
        verify(Player.queue[3].starred);
        verify(!Player.queue[1].starred);
        verify(Player.current.starred);
    }
}
