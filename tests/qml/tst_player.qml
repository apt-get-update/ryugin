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
        Player.settings.karaoke = false;
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

    function ids() { return Player.queue.map(function (t) { return t.id; }).join(); }

    // ---- Shuffle, as SPlayer-Next: a mode, off by default.
    function test_shuffle_off_by_default() {
        compare(Player.settings.shuffle, false);
        Player.play(tracks(5), 2);
        compare(ids(), "s0,s1,s2,s3,s4", "off: the list's order");
        compare(Player.index, 2);
    }
    function test_shuffle_on_then_off() {
        Player.play(tracks(20), 4);
        Player.toggleShuffle();
        verify(Player.settings.shuffle);
        compare(Player.index, 0, "the playing song first");
        compare(Player.current.id, "s4");
        compare(Player.queue.map(function (t) { return t.id; }).sort().join(), tracks(20).map(function (t) { return t.id; }).sort().join(), "every song kept");
        Player.next();
        const id = Player.current.id;
        Player.toggleShuffle();
        verify(!Player.settings.shuffle);
        compare(ids(), tracks(20).map(function (t) { return t.id; }).join(), "off: the order back");
        compare(Player.current.id, id, "at the playing song");
    }
    function test_shuffle_on_mixes_a_list() {
        try {
            Player.settings.shuffle = true;
            Player.play(tracks(20));
            compare(Player.queue.length, 20);
            Player.play(tracks(20), 7); // a song picked in a list: it plays first, the rest mixed
            compare(Player.current.id, "s7");
            compare(Player.index, 0);
        } finally {
            Player.toggleShuffle();
        }
    }
    function test_shuffle_new_order_on_repeat() {
        Player.repeat = "all";
        Player.play(tracks(3), 0);
        Player.toggleShuffle();
        try {
            Player.jump(2);
            const last = Player.current.id;
            Player.next(); // the end: again, in a new order
            compare(Player.index, 1);
            compare(Player.queue[0].id, last, "the last song not again at once");
        } finally {
            Player.toggleShuffle();
        }
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

    // The queue edited: a song moved (the playing one plays on), the queue saved as a playlist.
    function test_queue_move_and_save() {
        const ids = function () { return Player.queue.map(function (t) { return t.id; }).join(" "); };
        const before = ids(), playing = Player.current.id;
        Player.move(0, 2);
        compare(Player.current.id, playing, "the playing song plays on");
        Player.move(2, 0);
        compare(ids(), before);
        Player.move(Player.queue.length - 1, 0);
        compare(Player.current.id, playing);
        Player.move(0, Player.queue.length - 1);
        compare(ids(), before);
        Player.move(0, 0); // no move
        compare(ids(), before);
        mock.calls(true);
        const spy = Qt.createQmlObject("import QtTest; SignalSpy { signalName: 'playlistsChanged' }", this);
        spy.target = Api;
        Api.createPlaylist("Night", ["s0", "s1"]);
        tryVerify(function () { return mock.called("createPlaylist", "name=Night&songId=s0&songId=s1"); }, 5000);
        tryCompare(spy, "count", 1);
        Api.deletePlaylist("p1");
        tryVerify(function () { return mock.called("deletePlaylist", "id=p1"); }, 5000);
        tryCompare(spy, "count", 2);
        spy.destroy();
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

    // ---- Karaoke: songs without synced lyrics are learnt and passed over; those looked up
    // ahead play at once with theirs.
    function forget() {
        Player.settings.sung = "{}";
        Player.sung = {};
        Player.early = null;
    }
    function test_karaoke_learns_and_skips() {
        forget();
        Player.play(tracks(3), 0);
        Player.settings.karaoke = true;
        Player.scout();
        tryVerify(function () { return Player.sung.s0 === true && Player.sung.s1 === false && Player.sung.s2 === false; }, 5000);
        compare(JSON.parse(Player.settings.sung).s1, false);
        Player.next(); // nothing after s0 with lyrics
        compare(Player.index, 0);
        Player.playKaraoke(tracks(3));
        compare(Player.queue.map(function (t) { return t.id; }), ["s0"]);
        Player.play(tracks(3), 1);
        verify(!Player.karaoke, "a song chosen plays, lyrics or not");
        Player.command({ cmd: "karaoke" }); // the menu's: the library's songs to sing
        tryVerify(function () { return Player.karaoke && Player.queue.length > 0; }, 5000);
    }
    function test_sweep_finds_the_songs_with_lyrics() {
        forget();
        Player.swept = false;
        Player.sweep();
        Player.sweep(); // once a run
        tryVerify(function () { return Player.sweepLeft === 0 && Player.sung.s0 === true && Player.sung.s1 === false && Player.sung.s2 === false; }, 5000);
        compare(JSON.parse(Player.settings.sung).s0, true);
    }
    // A scan done: the songs it added are looked at, only them; during a sweep, after it.
    function test_sweep_after_a_scan() {
        forget();
        Player.swept = false;
        Player.sweep();
        tryVerify(function () { return Player.sweepLeft === 0 && Player.sung.s2 === false; }, 5000);
        const known = Object.assign({}, Player.sung);
        delete known.s2; // added by the scan
        Player.sung = known;
        mock.calls(true);
        Api.scanned();
        tryVerify(function () { return Player.sung.s2 === false; }, 5000, "the song added is looked at");
        compare(mock.calls(true).filter(function (c) { return c.startsWith("getLyricsBySongId?"); }).length, 1, "only it");
        Player.sweepLeft = 3; // a sweep running: the scan waits for its end
        Api.scanned();
        verify(Player.sweepAgain);
        Player.sweepAgain = false;
        Player.sweepLeft = 0;
    }
    // On mobile data, no sweep: tried again later, on Wi-Fi.
    function test_sweep_waits_for_wifi() {
        forget();
        mock.calls(true);
        try {
            Api.streamProxy = mock.url + "/?u=";
            mock.meter(true);
            Player.swept = false;
            Player.sweep();
            tryVerify(function () { return Player.sweepWait.running; }, 5000);
            verify(!Player.swept);
            verify(Player.sweepPaused);
            verify(!mock.called("getLyricsBySongId"), "nothing asked on mobile data");
            Player.settings.mobileData = true; // allowed: on at once
            tryVerify(function () { return Player.sung.s0 === true; }, 5000);
            verify(!Player.sweepPaused);
        } finally {
            Player.sweepWait.stop();
            Player.settings.mobileData = false;
            mock.meter(false);
            Api.streamProxy = "";
        }
    }
    // Each song played: the next one is downloaded ahead by Go.
    function test_next_downloaded_ahead() {
        try {
            Api.streamProxy = mock.url + "/?u=";
            mock.calls(true);
            mock.meter(true); // mobile data: not ahead
            Player.play(tracks(3), 0);
            wait(300);
            verify(!mock.called("ahead"));
            mock.meter(false);
            Player.play(tracks(3), 0);
            tryVerify(function () { return mock.called("ahead", "id=s1") && mock.called("ahead", "after=s0"); }, 5000);
        } finally {
            mock.meter(false);
            Api.streamProxy = "";
        }
    }
    function test_karaoke_passes_a_song_without() {
        forget();
        const l = tracks(3);
        l[1].title = "Creek"; // plain lyrics only (no lyrics at all waits for the stream's length)
        Player.play(l, 0);
        Player.settings.karaoke = true;
        Player.jump(1);
        tryVerify(function () { return Player.index === 2 && Player.sung.s1 === false; }, 5000);
    }
    // A song chosen (an album's, a search's) plays, lyrics or not: karaoke ends.
    function test_play_ends_karaoke() {
        Player.settings.karaoke = true;
        Player.play(tracks(3), 1);
        verify(!Player.karaoke);
        compare(Player.index, 1);
    }
    function test_karaoke_looks_ahead() {
        forget();
        const l = tracks(2);
        l[1].title = "Creek";
        Player.play([l[1], l[0]], 0);
        tryVerify(function () { return Player.sung.s1 === false; }, 5000);
        Player.settings.karaoke = true;
        Player.scout();
        tryVerify(function () { return Player.early !== null && Player.early.id === "s0"; }, 5000);
        Player.next();
        compare(Player.lyrics.length, 3);
        verify(Player.lyricsSynced);
        compare(Player.early, null);
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
    function test_like_from_a_list_fills_the_heart() {
        // A track list changes the shared object first, then calls setStarred.
        const l = tracks(2);
        Player.play(l, 0);
        let told = null;
        const f = function (id, on) { told = [id, on]; };
        Player.liked.connect(f);
        Player.queue[0].starred = true;
        Player.setStarred("s0", true);
        Player.liked.disconnect(f);
        verify(heart.liked, "the heart fills");
        compare(told, ["s0", true], "the lists are told");
    }

    // ---- The last run's queue: back at start, paused, not told to MPRIS until played.
    function lastRun(at) {
        Player.clear();
        Player.settings.queue = JSON.stringify(tracks(4));
        Player.settings.original = "";
        Player.settings.index = 2;
        Player.settings.position = at;
        Player.settings.server = Api.settings.url;
        Player.restore();
    }
    function test_restore_the_last_run() {
        Player.play(tracks(3), 1);
        compare(JSON.parse(Player.settings.queue).length, 3, "the queue is kept");
        compare(Player.settings.index, 1);
        lastRun(42000);
        verify(Player.restored);
        compare(Player.current.id, "s2");
        compare(Player.position, 42000, "where it stopped");
        verify(!Player.playing);
        compare(Player.media.source.toString(), "", "nothing loaded");
    }
    function test_restored_is_no_song_for_mpris() {
        lastRun(5000);
        Player.bridge = fakeBridge;
        Player.report(true, false);
        const s = JSON.parse(fakeBridge.objectName);
        verify(s.track === undefined, "not played in this run: the home screen's card shows the albums");
        verify(Array.isArray(Player.recentArt()));
        Player.bridge = null;
    }
    function test_play_resumes_the_restored_song() {
        mock.calls(true);
        lastRun(30000);
        Player.command({ cmd: "play" }); // the cover's play button
        verify(!Player.restored);
        compare(Player.current.id, "s2");
        compare(Player.resumeAt, 30000, "from where it stopped");
        verify(Player.media.source.toString().indexOf("id=s2") > 0);
        wait(200);
        verify(!mock.called("getRandomSongs"), "not random songs");
    }
    function test_seek_while_restored() {
        lastRun(30000);
        Player.seek(10000);
        compare(Player.position, 10000);
        verify(Player.restored, "still not loaded");
    }
    function test_no_restore_from_another_server() {
        Player.clear();
        Player.settings.queue = JSON.stringify(tracks(4));
        Player.settings.index = 1;
        Player.settings.server = "https://other.example";
        Player.restore();
        verify(!Player.restored);
        compare(Player.current, null);
    }
    function test_repeat_is_kept() {
        Player.repeat = "one";
        compare(Player.settings.repeat, "one");
        Player.repeat = "off";
    }

    // ---- MPRIS: shuffle and repeat as shell widgets and playerctl see and set them.
    function test_mpris_shuffle_and_loop() {
        Player.bridge = fakeBridge;
        try {
            Player.repeat = "one";
            compare(JSON.parse(fakeBridge.objectName).loop, "Track");
            Player.toggleShuffle();
            compare(JSON.parse(fakeBridge.objectName).shuffle, true);
            Player.command({ cmd: "setShuffle", value: false });
            verify(!Player.settings.shuffle);
            Player.command({ cmd: "setShuffle", value: false }); // already off: no change
            verify(!Player.settings.shuffle);
            Player.command({ cmd: "setLoop", value: "Playlist" });
            compare(Player.repeat, "all");
            Player.command({ cmd: "setLoop", value: "Bogus" });
            compare(Player.repeat, "all", "unknown: left as it was");
            Player.command({ cmd: "setLoop", value: "None" });
            compare(Player.repeat, "off");
            compare(JSON.parse(fakeBridge.objectName).loop, "None");
        } finally {
            Player.bridge = null;
            Player.repeat = "off";
        }
    }
}
