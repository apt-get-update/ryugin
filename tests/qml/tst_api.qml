import QtQuick
import QtTest
import "../../qml"

TestCase {
    name: "Api"

    function initTestCase() {
        Qt.application.organization = "ryugin-tests";
        Qt.application.domain = "tests";
    }
    Mock { id: mock }

    function init() { mock.connect(); }

    // Waits for an Api callback and returns its arguments.
    function result(start) {
        let got = null;
        start(function () { got = Array.prototype.slice.call(arguments); });
        tryVerify(function () { return got !== null; }, 5000);
        return got;
    }

    function test_url() {
        const u = Api.url("getAlbum", { id: "a b&c", none: undefined });
        verify(u.startsWith(mock.url + "/rest/getAlbum?"), u);
        verify(u.indexOf("u=u&t=t&s=s&v=1.16.1&c=ryugin&f=json") > 0, u);
        verify(u.indexOf("id=a%20b%26c") > 0, u);
        verify(u.indexOf("none") < 0, u);
    }

    function test_prefetch_covers() {
        mock.calls(true);
        try {
            Api.streamProxy = mock.url + "/?u=";
            Api.prefetchCovers();
            tryVerify(function () { return mock.called("prefetch", "getCoverArt"); }, 5000, "every album's cover, to Go");
            verify(mock.called("prefetch", "size=" + Api.albumCover), "at AlbumCard's size");
        } finally {
            Api.streamProxy = "";
        }
    }

    function test_cover_and_stream() {
        compare(Api.cover("", 100), "");
        verify(Api.cover("c", 100).indexOf("getCoverArt?") > 0);
        verify(Api.cover("c", 100).indexOf("size=100") > 0);
        verify(Api.stream("s0").indexOf("stream?") > 0);
        // Streams and covers go through Go's relay (the cache; https on Sailfish OS).
        const url = Api.settings.url;
        try {
            Api.streamProxy = "http://127.0.0.1:9/?u=";
            compare(Api.stream("s0").indexOf("http://127.0.0.1:9/?u=http%3A%2F%2F127.0.0.1"), 0, "plain http too");
            Api.settings.url = "https://music.example";
            verify(Api.cover("c", 100).indexOf("http://127.0.0.1:9/?u=") === 0, "covers too");
            const s = Api.stream("s0");
            compare(s.indexOf("http://127.0.0.1:9/?u=https%3A%2F%2Fmusic.example%2Frest%2Fstream%3F"), 0, s);
        } finally {
            Api.streamProxy = "";
            Api.settings.url = url;
        }
    }

    function test_login_stores_token_not_password() {
        const r = result(function (cb) { Api.login("  " + mock.url + "/ ", " u ", "secret", cb); });
        compare(r[0], null);
        compare(Api.settings.url, mock.url);
        compare(Api.settings.user, "u");
        compare(Api.settings.salt.length, 16);
        compare(Api.settings.token, Qt.md5("secret" + Api.settings.salt));
        verify(Api.online);
    }

    function test_server_error() {
        const r = result(function (cb) { Api.get("fail", {}, cb); });
        compare(r[0], "Wrong username or password");
        compare(r[1], null);
    }

    function test_unreachable() {
        Api.settings.url = "http://127.0.0.1:1";
        const r = result(function (cb) { Api.get("ping", {}, cb); });
        verify(r[0] !== null);
        verify(!Api.online);
    }

    function test_album_shelves() {
        for (const type of ["recent", "frequent", "starred", "newest"]) {
            const l = result(function (cb) { Api.albumList(type, 20, 0, cb); })[0];
            compare(l.length, 4, type);
            compare(l[0].id, type + "-0");
            compare(l[0].title, "Green");
            compare(l[0].artist, "Hiroshi Yoshimura");
            compare(l[0].cover, "c");
            verify(mock.called("getAlbumList2", "type=" + type));
        }
    }

    function test_get_album() {
        const r = result(function (cb) { Api.getAlbum("a", cb); });
        compare(r[0].title, "Green");
        compare(r[1].length, 3);
        compare(r[1][1].title, "Creek");
        compare(r[1][1].starred, true);
        compare(r[1][0].starred, false);
        compare(r[1][2].number, 3);
        compare(r[1][0].duration, 245);
    }

    function test_library_lists() {
        compare(result(function (cb) { Api.artists(cb); })[0][0].name, "Hiroshi Yoshimura");
        const ar = result(function (cb) { Api.getArtist("ar1", cb); });
        compare(ar[0], "Hiroshi Yoshimura");
        compare(ar[1].length, 4);
        compare(result(function (cb) { Api.playlists(cb); })[0][0].name, "Ambient");
        compare(result(function (cb) { Api.getPlaylist("p1", cb); })[0].length, 3);
        compare(result(function (cb) { Api.randomSongs(5, cb); })[0].length, 3);
        compare(result(function (cb) { Api.starredSongs(cb); })[0][0].title, "Creek");
        compare(result(function (cb) { Api.songCount(cb); })[0], 1234);
        const s = result(function (cb) { Api.search("yoshi", cb); })[0];
        compare(s.artists.length, 1);
        compare(s.albums.length, 4);
        compare(s.songs.length, 3);
    }

    function test_all_albums() {
        Api.known.albums = "";
        compare(result(function (cb) { Api.allAlbums(cb); })[0].length, 4);
    }
    // The list known comes at once (no wait, no jump), and stays when Navidrome is gone.
    function test_all_albums_known_first() {
        Api.known.albums = "";
        result(function (cb) { Api.allAlbums(cb); });
        let got = null;
        Api.allAlbums(function (l) { got = l; });
        verify(got !== null && got.length === 4, "at once");
        const url = Api.settings.url;
        try {
            Api.settings.url = "http://127.0.0.1:9";
            got = null;
            Api.allAlbums(function (l) { got = l; });
            compare(got.length, 4);
            wait(300);
            compare(got.length, 4, "offline: the last list stays");
        } finally {
            Api.settings.url = url;
        }
    }

    function test_lyrics_synced() {
        const r = result(function (cb) { Api.lyrics({ id: "s0", artist: "x", title: "Blink" }, cb); });
        compare(r[1], true);
        compare(r[0].length, 3);
        compare(r[0][1].time, 4000);
        compare(r[0][1].text, "the moss remembers");
        // Navidrome's word times (enhanced): the main voice's cues, each word with its space
        const w = r[0][0].words;
        compare(w.map(function (x) { return x.text; }).join("|"), "Water |over |stone");
        compare(w.map(function (x) { return x.time + "-" + x.end; }).join(), "0-800,800-1600,1600-3000");
        compare(r[0][1].words.length, 0);
    }

    // Cue byte offsets are UTF-8: Japanese words cut right; a Navidrome offset moves them.
    function test_cue_words_utf8() {
        const w = Api.cueWords({ value: "布団 夢", end: 2000, cue: [
            { value: "布団", start: 1000, byteStart: 0, byteEnd: 5 },
            { value: "夢", start: 1500, byteStart: 7, byteEnd: 9 }] }, 500);
        compare(w.map(function (x) { return x.text; }).join("|"), "布団 |夢");
        compare(w.map(function (x) { return x.time + "-" + x.end; }).join(), "500-1000,1000-1500");
        compare(Api.cueWords({ value: "布", cue: [{ value: "x", byteStart: 1, byteEnd: 1 }] }, 0)[0].text, "x"); // a cut inside a character: the cue's own text
    }

    function test_lyrics_plain_fallback() {
        const r = result(function (cb) { Api.lyrics({ id: "s1", artist: "Hiroshi Yoshimura", title: "Creek" }, cb); });
        compare(r[1], false);
        compare(r[0].length, 2);
        compare(r[0][0].time, -1);
        compare(r[0][1].text, "second line");
    }

    // Navidrome's getLyrics gives the tag as is: synced LRC is used as synced, never shown raw.
    function test_lyrics_navidrome_tag_lrc() {
        const r = result(function (cb) { Api.lyrics({ id: "s3", artist: "x", title: "Sleet" }, cb); });
        compare(r[1], true);
        compare(r[0].length, 2);
        compare(r[0][0].text, "ice falls");
        compare(r[0][0].words.length, 2);
        compare(r[0][1].time, 3000);
    }

    function test_plain_lines_drop_timers() {
        const l = Api.plainLines("[ar:x]\n[00:01.00]<00:01.00>ice <00:01.50>falls\n[00:02.00][00:09.00] quiet");
        compare(l.length, 2);
        compare(l[0].text, "ice falls");
        compare(l[1].text, "quiet");
        compare(l[0].time, -1);
        compare(Api.plainLines("[ar:x]\n\n").length, 0);
    }

    function test_lrc_repeated_stamps() {
        const l = Api.lrc("[00:12.00][01:30.00] chorus\n[00:20.00] verse");
        compare(l.map(function (x) { return x.time; }).join(), "12000,20000,90000");
        compare(l[2].text, "chorus");
    }

    function test_lyrics_none() {
        const r = result(function (cb) { Api.lyrics({ id: "s2", artist: "x", title: "Feel" }, cb); });
        compare(r[0].length, 0);
        compare(r[1], false);
    }

    function test_lyrics_lrclib_get() {
        mock.calls(true);
        const r = result(function (cb) { Api.lyrics({ id: "x1", artist: "a", title: "Snow", album: "b", duration: 200 }, cb); });
        compare(r[1], true);
        compare(r[0].length, 3);
        compare(r[0][1].time, 2500);
        compare(r[0][1].text, "rain");
        compare(r[0][2].text, "");
        verify(!mock.called("lrclibsearch"), "get found it, no search");
    }

    function test_lyrics_lrclib_search_prefers_synced() {
        const r = result(function (cb) { Api.lyrics({ id: "x2", artist: "a", title: "Rain", album: "b", duration: 200 }, cb); });
        compare(r[1], true);
        compare(r[0][0].time, 1000);
        compare(r[0][0].text, "wind");
    }

    function test_lyrics_navidrome_plain_kept_when_lrclib_has_none() {
        mock.calls(true);
        const r = result(function (cb) { Api.lyrics({ id: "s1", artist: "Hiroshi Yoshimura", title: "Creek", album: "Green", duration: 245 }, cb); });
        compare(r[0][0].text, "first line");
        verify(mock.called("lrclibget", "track_name=Creek"), "LRCLIB asked for synced lyrics");
    }

    function test_lyrics_other_version_is_not_synced() {
        // Only a 230 s recording on LRCLIB for a 200 s song: its timing would be 30 s off.
        const r = result(function (cb) { Api.lyrics({ id: "x9", artist: "a", title: "Hail", album: "", duration: 200 }, cb); });
        compare(r[1], false, "not synced");
        compare(r[0][0].text, "hail");
    }
    function test_lyrics_lrclib_title_only_same_length() {
        mock.calls(true);
        const r = result(function (cb) { Api.lyrics({ id: "x3", artist: "Fuji (with Shimon)", title: "Moss", album: "", duration: 201 }, cb); });
        compare(r[1], true);
        compare(r[0][0].text, "moss");
        verify(mock.called("lrclibget", "artist_name=Fuji&"), "artist cleaned of its brackets");
    }

    function test_album_lyrics_by_exact_length() {
        let r = result(function (cb) { Api.albumLyrics({ title: "Blink", album: "Green" }, 245080, cb); });
        compare(r[0][0].text, "みどり", "closest song with words, the instrumental skipped");
        compare(r[1], false);
        r = result(function (cb) { Api.albumLyrics({ title: "Blink", album: "Green" }, 245600, cb); });
        compare(r[0][0].text, "other");
        compare(r[1], true);
        r = result(function (cb) { Api.albumLyrics({ title: "Blink", album: "Green" }, 250000, cb); });
        compare(r[0].length, 0, "nothing within 0.15 s");
        r = result(function (cb) { Api.albumLyrics({ title: "Blink", album: "" }, 245080, cb); });
        compare(r[0].length, 0);
    }

    function test_lyrics_by_original_title() {
        mock.calls(true);
        Api.releases = {};
        const t = { id: "x9", title: "Blink [Remaster]", artist: "Hiroshi Yoshimura", album: "Green", number: 1, disc: 1, duration: 245 };
        let r = result(function (cb) { Api.lyrics(t, cb); });
        compare(r[1], true);
        compare(r[0][0].text, "まばたき", "the original title, found on LRCLIB, about as long");
        verify(mock.called("lrclibget", "track_name=Blink&album"), "title searched without its [..]");
        verify(mock.called("mbrelease/", "ua=ryugin"), "MusicBrainz gets a user agent");
        mock.calls(true);
        r = result(function (cb) { Api.lyrics(t, cb); });
        compare(r[0][0].text, "まばたき");
        verify(!mock.called("mbrelease/", ""), "the release is asked for once per album");
        r = result(function (cb) { Api.lyrics({ id: "x8", title: "Blink", artist: "a", album: "Green", number: 1, disc: 1, duration: 200 }, cb); });
        compare(r[0].length, 0, "a track of another length is another song");
    }

    function test_quality_tag() {
        compare(Api.quality({ suffix: "flac", bitDepth: 16, samplingRate: 44100 }), "Lossless");
        compare(Api.quality({ suffix: "FLAC", bitDepth: 24, samplingRate: 96000 }), "Hi-Res");
        compare(Api.quality({ suffix: "mp3", bitRate: 320 }), "320K");
        compare(Api.quality({ suffix: "ogg" }), "OGG");
    }

    function test_lrc_parse() {
        const l = Api.lrc("[ti:x]\n[01:02.50] hello\n\n[00:00.00]\nno tag");
        compare(l.length, 2); // in time order
        compare(l[1].time, 62500);
        compare(l[1].text, "hello");
        compare(l[0].text, "");
    }

    function test_lrc_word_times() {
        const l = Api.lrc("[00:13.99]<00:13.99>布<00:14.16>団<00:14.48>\n[00:15.00]<00:15.00>a <00:15.50>b & <00:16.00>c\n[00:17.00]plain");
        compare(l[0].text, "布団");
        compare(l[0].words.length, 2);
        compare(l[0].words[0].time, 13990);
        compare(l[0].words[0].end, 14160);
        compare(l[0].words[1].end, 14480); // the empty last tag ends the word
        compare(l[1].text, "a b & c");
        compare(l[1].words[2].end, -1); // not said: the view gives it half a second
        compare(l[2].words.length, 0);
        compare(l[2].text, "plain");
        // text before the first time starts with the line; a Navidrome offset moves the words
        const n = Api.lyricLine(1000, "x<00:02.00>y", 500);
        compare(n.words[0].time, 1000);
        compare(n.words[0].end, 1500);
        compare(n.words[1].time, 1500);
    }

    function test_stream_is_raw_for_seeking() {
        verify(Api.stream("s0").indexOf("format=raw") > 0);
    }

    function test_scrobble_and_star() {
        mock.calls(true);
        Api.scrobble("s0", true);
        Api.star("s1", true);
        Api.star("s1", false);
        tryVerify(function () { return mock.called("scrobble", "submission=true") && mock.called("star", "id=s1") && mock.called("unstar", "id=s1"); }, 5000);
    }
}
