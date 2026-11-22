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
    readonly property int position: media.position
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

    property string repeat: "off" // off, all, one
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
        property real cacheLimit: 10 // GB, as SPlayer
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
    readonly property AudioOutput output: AudioOutput {
        volume: p.settings.volume
    }
    readonly property MediaPlayer media: MediaPlayer {
        audioOutput: p.output
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) p.ended()
        onPlaybackStateChanged: p.report(false, false)
        onPositionChanged: p.tick()
        onDurationChanged: p.albumLyrics()
        // A FLAC's cover is a video stream to FFmpeg: decoding it crashed Sailfish's
        // graphics driver ("invalid handle"). Audio only.
        onErrorOccurred: p.going = false
        onTracksChanged: if (activeVideoTrack !== -1) activeVideoTrack = -1
    }

    // Play list from song i. Shuffle on: from i (a random one when none is given) and the
    // rest in a random order, as SPlayer-Next.
    function play(list, i) {
        original = null;
        queue = list.slice();
        index = i === undefined ? (settings.shuffle ? Math.floor(Math.random() * list.length) : 0) : i;
        if (settings.shuffle)
            mix(index);
        load();
    }
    // The Shuffle buttons (album, playlist, artist): shuffle on, then play.
    function shuffle(list) {
        settings.shuffle = true;
        play(list);
    }
    // Song i first, the others in a random order; the order before is kept to put back.
    function mix(i) {
        if (queue.length === 0)
            return;
        if (!original)
            original = queue.slice();
        const rest = queue.filter(function (t, k) { return k !== i; });
        for (let k = rest.length - 1; k > 0; k--) {
            const j = Math.floor(Math.random() * (k + 1));
            [rest[k], rest[j]] = [rest[j], rest[k]];
        }
        queue = [queue[i]].concat(rest);
        index = 0;
    }
    // The shuffle button: on mixes the queue (the playing song first), off puts its order
    // back, at the playing song.
    function toggleShuffle() {
        settings.shuffle = !settings.shuffle;
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
    function clear() {
        going = false;
        media.stop();
        media.source = "";
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
        Api.lyrics(current, function (lines, synced) {
            if (current && current.id === id) {
                lyricsSynced = synced;
                lyrics = lines;
                albumLookup = lines.length === 0;
                albumLyrics();
            }
        });
        report(true, false);
        lookCover();
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
            if (current && current.id === id && lines.length) {
                lyricsSynced = synced;
                lyrics = lines;
            }
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
        if (index + 1 < queue.length) {
            index++;
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
        else if (media.source.toString() === "")
            load();
        else
            media.play();
    }
    function seek(ms) {
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
            position: position * 1000,
            volume: settings.volume,
            seeked: seeked,
            nonce: Math.random()
        };
        if (withTrack)
            state.recentArt = recentArt();
        if (withTrack && current)
            state.track = {
                id: current.id, title: current.title, artist: current.artist, album: current.album,
                art: Api.cover(current.cover, 512), length: current.duration * 1000000
            };
        bridge.objectName = JSON.stringify(state);
    }

    // The covers of the last 3 albums played, for MPRIS (qt-runner's cover on Sailfish OS
    // shows them while nothing plays, as the media player does); the server's newest
    // albums fill in until 3 were played.
    property var serverCovers: []
    function recentArt() {
        const seen = [];
        const covers = history.map(function (s) { return s.cover; }).concat(serverCovers);
        for (let i = 0; i < covers.length && seen.length < 3; i++)
            if (covers[i] && seen.indexOf(covers[i]) < 0)
                seen.push(covers[i]);
        return seen.map(function (c) { return Api.cover(c, 512); });
    }
    function lookServerCovers() {
        if (Api.configured)
            Api.albumList("newest", 3, 0, function (l) {
                serverCovers = l.map(function (a) { return a.cover; });
                report(true, false);
            });
        report(true, false);
    }
    onBridgeChanged: lookServerCovers()
    readonly property Connections apiConfigured: Connections {
        target: Api
        function onConfiguredChanged() { p.lookServerCovers(); }
    }

    // Commands from MPRIS.
    function command(c) {
        switch (c.cmd) {
        case "play": // nothing queued (a headset, the lock screen): 50 random songs
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
        case "lucky": Api.randomSongs(50, function (l) { play(l, 0); }); break;
        }
    }
}
