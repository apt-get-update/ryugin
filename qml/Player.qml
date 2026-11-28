pragma Singleton
import QtQuick
import QtCore
import QtMultimedia

// The queue and playback. Scrobbles to Navidrome (so "recently played" and "most played"
// fill up), loads lyrics, and reports its state to Go for MPRIS.
QtObject {
    id: p

    // A song was liked or unliked (track lists follow it).
    signal liked(string songId, bool on)

    property var bridge: null
    property var queue: []
    property int index: -1
    readonly property var current: index >= 0 && index < queue.length ? queue[index] : null
    readonly property bool playing: media.playbackState === MediaPlayer.PlayingState
    // Restored (the last run's song, not played yet): its saved position.
    readonly property int position: restored ? settings.position : media.position
    // The position in whole seconds: what a progress bar shows on a phone. Qt moves position
    // every ~100 ms, and each change redrew the whole window (10 frames a second).
    readonly property int seconds: Math.floor(position / 1000) * 1000
    readonly property int shownPosition: Nav.phone ? seconds : position
    readonly property int duration: media.duration > 0 ? media.duration : (current ? current.duration * 1000 : 0)

    property var lyrics: []
    property bool lyricsSynced: false
    readonly property int lyricIndex: lineAt(position)

    // The synced lyric line sung at ms (a line lights up 200 ms early), or -1.
    function lineAt(ms) {
        if (!lyricsSynced)
            return -1;
        let i = -1;
        for (let k = 0; k < lyrics.length && lyrics[k].time <= ms + 200; k++)
            i = k;
        return i;
    }

    property string repeat: settings.repeat // off, all, one
    onRepeatChanged: {
        settings.repeat = repeat;
        report(false, false);
    }
    // The last run's queue is back and its song shows, paused, but is not loaded (nothing
    // downloads) nor told to MPRIS: Sailfish OS's cover keeps its album split, and play
    // resumes that song where it stopped (SPlayer-Next restores the same).
    property bool restored: false
    property int resumeAt: 0 // ms: where the restored song starts once loaded
    // Shuffle on: the queue as it was before, to put back when it goes off (SPlayer-Next).
    property var original: null
    property bool scrobbled: false
    // A song is meant to play: between two songs the player is stopped for a moment, which
    // is no stop for MPRIS (Sailfish OS's cover then flashed its idle album grid).
    property bool going: false
    property int lastReport: 0

    // Typed (an inline component), so qmllint knows its properties.
    component Prefs: Settings {
        category: "player"
        property real volume: 0.8
        property string layout: "classic" // fullscreen: classic, fullCover, fullLyric, controls
        property string backdrop: "blur" // fullscreen background: blur (static) or flow (moving)
        property bool tags: false // fullscreen: the song's tags (Streaming, Lossless, Lrc)
        property string history: "[]" // the last songs played, newest first (JSON)
        property bool shuffle: false // shuffle mode, as SPlayer-Next: kept between runs
        property bool cache: true // songs played whole are kept on disk (stream.go)
        property real cacheLimit: 2 // GB of songs; covers have no limit
        // The queue, for the next run (JSON), its order before shuffle ("": none), the
        // song in it, where it was (ms, saved every 10 s and on pause), and its server.
        property string queue: "[]"
        property string original: ""
        property int index: -1
        property int position: 0
        property string server: ""
        property string repeat: "off"
        property bool karaoke: false // only songs with synced lyrics play
        property string sung: "{}" // song id -> synced lyrics found (true) or not (false), JSON
    }
    readonly property Prefs settings: Prefs {}
    // The last 20 songs played, newest first: Navidrome only keeps recent albums.
    property var history: {
        try { return JSON.parse(settings.history); } catch (e) { return []; }
    }
    function remember(song) {
        const l = [song].concat(history.filter(function (s) { return s.id !== song.id; })).slice(0, 20);
        settings.history = JSON.stringify(l);
        history = l;
    }

    // Karaoke: only songs with synced lyrics play. What each song has is learnt as it plays,
    // and the next ones are looked up while one plays, so a song without is passed over at once.
    readonly property bool karaoke: settings.karaoke
    property var sung: {
        try { return JSON.parse(settings.sung); } catch (e) { return {}; }
    }
    property string scouting: "" // the song being looked up
    property var early: null // its synced lyrics { id, lines }, for when it plays
    function learn(id, synced) {
        if (sung[id] === synced)
            return;
        const m = Object.assign({}, sung);
        m[id] = synced;
        settings.sung = JSON.stringify(m);
        sung = m;
    }
    // A song's lyrics as load finds them (the album lookup with the song's tagged length).
    function findLyrics(t, cb) {
        Api.lyrics(t, function (lines, synced) {
            if (lines.length)
                return cb(lines, synced);
            Api.albumLyrics(t, (t.duration || 0) * 1000, cb);
        });
    }
    // The first song from i on not known to have no synced lyrics (karaoke), or i.
    function ahead(i) {
        while (karaoke && i < queue.length && sung[queue[i].id] === false)
            i++;
        return i;
    }
    // Karaoke: look up the next song not known yet; one without synced lyrics, the one after.
    function scout() {
        const i = ahead(index + 1);
        if (!karaoke || i >= queue.length || sung[queue[i].id] === true || scouting === queue[i].id)
            return;
        const t = queue[i];
        scouting = t.id;
        findLyrics(t, function (lines, synced) {
            scouting = "";
            learn(t.id, synced);
            if (synced)
                early = { id: t.id, lines: lines };
            scout();
        });
    }
    function toggleKaraoke() {
        settings.karaoke = !settings.karaoke;
        scout();
    }
    // Karaoke on, list mixed: songs known to have synced lyrics first, those known without
    // left out (500 at most).
    function playKaraoke(list) {
        const l = mixed(list.filter(function (t) { return sung[t.id] !== false; }));
        play(l.filter(function (t) { return sung[t.id]; }).concat(l.filter(function (t) { return !sung[t.id]; })).slice(0, 500), 0);
        settings.karaoke = true; // after play, which ends it
    }
    // The library looked at once a run for songs with synced lyrics on Navidrome (only the
    // songs not known yet: all of them the first time), so karaoke plays them from the start.
    // Only on Wi-Fi: thousands of requests are not for mobile data. On it, the sweep stops
    // and is tried again every 10 minutes.
    property bool swept: false
    property int sweepLeft: 0
    readonly property Timer sweepWait: Timer { interval: 600000; onTriggered: p.sweep() }
    function sweep() {
        if (swept || !Api.configured)
            return;
        swept = true;
        Api.metered(function (paid) {
            if (paid)
                return later();
            Api.allSongs(sweepThrough);
        });
    }
    // The sweep put off: mobile data.
    function later() {
        swept = false;
        sweepLeft = 0;
        sweepWait.restart();
    }
    function sweepThrough(all) {
        const todo = all.filter(function (t) { return sung[t.id] === undefined; });
        const found = {};
        // Saved now and then (not at each song): what the songs played taught wins. Then
        // the network is asked again: on mobile data now, the rest waits.
        const save = function () {
            const m = Object.assign({}, found, sung);
            settings.sung = JSON.stringify(m);
            sung = m;
            Api.metered(function (paid) {
                if (paid && todo.length) {
                    todo.length = 0;
                    later();
                }
            });
        };
        const step = function () {
            const t = todo.shift();
            if (t)
                Api.syncedOnServer(t.id, function (synced) {
                    if (synced !== null)
                        found[t.id] = synced;
                    sweepLeft = Math.max(0, sweepLeft - 1); // 0 at once when put off
                    if (sweepLeft % 100 === 0)
                        save();
                    step();
                });
        };
        sweepLeft = todo.length;
        for (let k = 0; k < 4; k++) // 4 at a time
            step();
    }
    // The current song's lyrics are all found: learnt, and in karaoke one without is passed over.
    function settle(id, synced) {
        learn(id, synced);
        if (karaoke && !synced)
            next();
        else
            scout();
    }

    readonly property AudioOutput output: AudioOutput {
        volume: p.settings.volume
    }
    readonly property MediaPlayer media: MediaPlayer {
        audioOutput: p.output
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                p.ended();
            else if (p.resumeAt > 0 && (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)) {
                setPosition(p.resumeAt);
                p.resumeAt = 0;
            }
        }
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PausedState)
                p.settings.position = position;
            p.report(false, false);
        }
        onPositionChanged: p.tick()
        onDurationChanged: p.albumLyrics()
        // A FLAC's cover is a video stream to FFmpeg: decoding it crashed Sailfish's
        // graphics driver ("invalid handle"). Audio only.
        onErrorOccurred: p.going = false
        onTracksChanged: if (activeVideoTrack !== -1) activeVideoTrack = -1
    }

    // The queue, kept for the next run as it changes.
    onQueueChanged: settings.queue = JSON.stringify(queue)
    onOriginalChanged: settings.original = original ? JSON.stringify(original) : ""
    onIndexChanged: settings.index = index
    Component.onCompleted: restore()
    // The last run's queue and song, when it was on this server.
    function restore() {
        let q = [];
        try {
            q = JSON.parse(settings.queue);
        } catch (e) {}
        if (!Array.isArray(q) || settings.index < 0 || settings.index >= q.length || settings.server !== Api.settings.url)
            return;
        let o = null;
        try {
            o = settings.original ? JSON.parse(settings.original) : null;
        } catch (e) {}
        const at = settings.position;
        queue = q;
        original = o;
        index = settings.index;
        settings.position = at;
        restored = true;
    }

    // Play list from song i. Shuffle on: from i (a random one when none is given) and the
    // rest in a random order, as SPlayer-Next.
    function play(list, i) {
        settings.karaoke = false; // a song chosen plays, lyrics or not (karaoke: playKaraoke)
        original = null;
        queue = list.slice();
        index = i === undefined ? (settings.shuffle ? Math.floor(Math.random() * list.length) : 0) : i;
        if (settings.shuffle)
            mix(index);
        load();
    }
    // A copy of list in a random order (Fisher-Yates).
    function mixed(list) {
        const l = list.slice();
        for (let k = l.length - 1; k > 0; k--) {
            const j = Math.floor(Math.random() * (k + 1));
            [l[k], l[j]] = [l[j], l[k]];
        }
        return l;
    }
    // Plays list mixed, the shuffle button left as it is (Play favorites).
    function playMixed(list) {
        play(mixed(list), 0);
    }
    // Song i first, the others in a random order; the order before is kept to put back.
    function mix(i) {
        if (queue.length === 0)
            return;
        if (!original)
            original = queue.slice();
        queue = [queue[i]].concat(mixed(queue.filter(function (t, k) { return k !== i; })));
        index = 0;
    }
    // The shuffle button: on mixes the queue (the playing song first), off puts its order
    // back, at the playing song.
    function toggleShuffle() {
        settings.shuffle = !settings.shuffle;
        report(false, false);
        if (settings.shuffle) {
            mix(Math.max(index, 0));
        } else if (original) {
            const id = current ? current.id : "";
            queue = original;
            original = null;
            index = Math.max(0, queue.findIndex(function (t) { return t.id === id; }));
        }
    }
    function enqueue(list) {
        queue = queue.concat(list);
        if (original)
            original = original.concat(list);
        if (index < 0)
            play(queue, 0);
    }
    // Take a song out of the queue; taking the playing one plays the next.
    function removeAt(i) {
        if (i < 0 || i >= queue.length)
            return;
        const playing = i === index;
        const q = queue.slice();
        const gone = q.splice(i, 1)[0];
        queue = q;
        if (original)
            original = original.filter(function (t) { return t !== gone; });
        if (i < index)
            index--;
        else if (playing) {
            if (index < queue.length)
                load();
            else { // it was the last: stop
                going = false;
                media.stop();
                media.source = "";
                index = -1;
            }
        }
    }
    // Move a song in the queue; the playing one plays on.
    function move(from, to) {
        to = Math.max(0, Math.min(queue.length - 1, to));
        if (from === to || from < 0 || from >= queue.length)
            return;
        const q = queue.slice();
        q.splice(to, 0, q.splice(from, 1)[0]);
        let i = index;
        if (i === from)
            i = to;
        else if (from < i && to >= i)
            i--;
        else if (from > i && to <= i)
            i++;
        queue = q;
        index = i;
    }
    function clear() {
        going = false;
        media.stop();
        media.source = "";
        restored = false;
        queue = [];
        original = null;
        index = -1;
        lyrics = [];
    }
    function jump(i) {
        index = i;
        load();
    }

    function load() {
        if (!current)
            return;
        restored = false;
        settings.server = Api.settings.url;
        settings.position = resumeAt;
        going = true;
        media.source = Api.stream(current.id);
        media.play();
        remember(current);
        scrobbled = false;
        Api.scrobble(current.id, false); // now playing
        lyrics = [];
        lyricsSynced = false;
        const id = current.id;
        albumLookup = false;
        if (early && early.id === id) { // looked up while the last one played
            lyricsSynced = true;
            lyrics = early.lines;
            early = null;
            settle(id, true);
        } else
            Api.lyrics(current, function (lines, synced) {
                if (current && current.id === id) {
                    lyricsSynced = synced;
                    lyrics = lines;
                    albumLookup = lines.length === 0;
                    if (!albumLookup)
                        settle(id, synced);
                    albumLyrics();
                }
            });
        report(true, false);
        lookCover();
        const i = ahead(index + 1); // the next song, downloaded once this one is there
        const after = i < queue.length ? queue[i] : (repeat === "all" && !settings.shuffle ? queue[0] : null);
        if (after && after.id !== id)
            Api.ahead(after.id);
    }

    // Ask Go for the cover's colour and the fullscreen backdrop (made for its size).
    property real backdropSide: 1000
    onBackdropSideChanged: lookCover()
    function lookCover() {
        if (bridge && current)
            bridge.objectName = JSON.stringify({ coverUrl: Api.cover(current.cover, 128), side: backdropSide, nonce: Math.random() });
    }

    // No lyrics found by name: try the album on LRCLIB by exact length, once the player
    // knows it.
    property bool albumLookup: false
    function albumLyrics() {
        if (!albumLookup || media.duration <= 0 || !current)
            return;
        albumLookup = false;
        const id = current.id;
        Api.albumLyrics(current, media.duration, function (lines, synced) {
            if (!current || current.id !== id)
                return;
            if (lines.length) {
                lyricsSynced = synced;
                lyrics = lines;
            }
            settle(id, synced);
        });
    }

    function ended() {
        if (!scrobbled && current)
            Api.scrobble(current.id, true);
        if (repeat === "one") { // the same source again does not reload: back to its start
            scrobbled = false;
            media.setPosition(0);
            media.play();
        } else {
            next();
        }
    }
    function next() {
        const i = ahead(index + 1);
        if (i < queue.length) {
            index = i;
            load();
        } else if (repeat === "all" && queue.length > 0) {
            index = 0;
            if (settings.shuffle && queue.length > 1) { // a new order; the last song not again at once
                mix(queue.length - 1);
                index = 1;
            }
            load();
        } else {
            going = false;
            media.stop();
        }
    }
    function cycleRepeat() {
        repeat = repeat === "off" ? "all" : repeat === "all" ? "one" : "off";
    }
    function previous() {
        if (position > 3000 || index <= 0)
            seek(0);
        else {
            index--;
            load();
        }
    }
    function toggle() {
        if (playing)
            media.pause();
        else if (media.source.toString() === "") {
            if (restored) // where it stopped last time
                resumeAt = settings.position;
            load();
        }
        else
            media.play();
    }
    function seek(ms) {
        if (restored) { // not loaded: where it will start
            settings.position = Math.max(0, Math.min(ms, duration));
            return;
        }
        media.position = Math.max(0, Math.min(ms, duration));
        report(false, true);
    }
    function setVolume(v) {
        settings.volume = Math.max(0, Math.min(1, v));
        report(false, false);
    }
    // The mouse wheel on a volume control: 5 % a notch (a touchpad, by its smaller steps).
    function wheelVolume(e) {
        setVolume(settings.volume + e.angleDelta.y / 120 * 0.05);
    }
    function toggleStar() {
        if (current)
            setStarred(current.id, !current.starred);
    }
    // Star or unstar a song everywhere it is queued, and on the server.
    function setStarred(id, on) {
        // New objects: a binding on current (the heart) sees the change.
        // A track list may have changed the shared object already: check the id only.
        const mark = function (t) { return t.id === id ? Object.assign({}, t, { starred: on }) : t; };
        if (queue.some(function (t) { return t.id === id; }))
            queue = queue.map(mark);
        if (original)
            original = original.map(mark);
        Api.star(id, on);
        liked(id, on);
    }

    function tick() {
        if (current && !scrobbled && duration > 0 && (position > duration / 2 || position > 240000)) {
            Api.scrobble(current.id, true);
            scrobbled = true;
        }
        if (Math.abs(position - lastReport) >= 1000)
            report(false, false);
        if (playing && Math.abs(position - settings.position) >= 10000)
            settings.position = position;
    }

    // State for MPRIS, through Go (times in microseconds).
    function report(withTrack, seeked) {
        lastReport = position;
        if (!bridge)
            return;
        const state = {
            // From the player itself: in onPlaybackStateChanged, playing is not updated yet
            // (a pause said "Playing", and MPRIS, the lock screen, kept showing ||).
            status: media.playbackState === MediaPlayer.StoppedState && going ? "Playing" : ["Stopped", "Playing", "Paused"][media.playbackState],
            canPlay: Api.configured, // not connected yet: nothing to play
            shuffle: settings.shuffle,
            loop: ({ off: "None", all: "Playlist", one: "Track" })[repeat],
            position: position * 1000,
            volume: settings.volume,
            seeked: seeked,
            nonce: Math.random()
        };
        if (withTrack && current && !restored) // restored: not played yet in this run
            state.track = {
                id: current.id, title: current.title, artist: current.artist, album: current.album,
                art: Api.cover(current.cover, 512), length: current.duration * 1000000
            };
        bridge.objectName = JSON.stringify(state);
    }

    // The covers of the last 3 albums played, for the Sailfish home screen's card while
    // nothing plays (as the media player's); the server's newest albums fill in until 3
    // were played.
    property var serverCovers: []
    function recentArt() {
        // One per album: its songs can each have their own cover id.
        const keys = [], art = [];
        const all = history.map(function (s) { return [s.albumId || s.cover, s.cover]; })
            .concat(serverCovers.map(function (c) { return [c, c]; }));
        for (let i = 0; i < all.length && art.length < 3; i++)
            if (all[i][1] && keys.indexOf(all[i][0]) < 0) {
                keys.push(all[i][0]);
                art.push(Api.cover(all[i][1], 512));
            }
        return art;
    }
    function lookServerCovers() {
        if (Api.configured)
            Api.albumList("newest", 3, 0, function (l) {
                serverCovers = l.map(function (a) { return a.cover; });
            });
    }
    onBridgeChanged: {
        lookServerCovers();
        sweep();
    }
    readonly property Connections apiConfigured: Connections {
        target: Api
        function onConfiguredChanged() {
            p.lookServerCovers();
            p.sweep();
        }
    }

    // Commands from MPRIS.
    function command(c) {
        switch (c.cmd) {
        case "play": // nothing queued nor restored (a headset, the lock screen): 50 random songs
        case "playPause":
            if (!current)
                Api.randomSongs(50, function (l) { p.play(l, 0); });
            else if (c.cmd === "playPause" || !playing)
                toggle();
            break;
        case "pause": media.pause(); break;
        case "stop": going = false; media.stop(); break;
        case "next": next(); break;
        case "previous": previous(); break;
        case "seek": seek(position + c.offset / 1000); break;
        case "setPosition": seek(c.position / 1000); break;
        case "volume": setVolume(c.value); break;
        case "like": toggleStar(); break;
        case "repeat": cycleRepeat(); break;
        case "shuffle": toggleShuffle(); break;
        // From MPRIS: shell widgets, playerctl.
        case "setShuffle": if (c.value !== settings.shuffle) toggleShuffle(); break;
        case "setLoop": repeat = ({ None: "off", Playlist: "all", Track: "one" })[c.value] || repeat; break;
        case "lucky": Api.randomSongs(50, function (l) { play(l, 0); }); break;
        case "karaoke": toggleKaraoke(); break;
        }
    }
}
