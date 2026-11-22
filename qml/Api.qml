pragma Singleton
import QtQuick
import QtCore

// Navidrome through the Subsonic API (JSON). Only the token and salt are stored, never
// the password.
QtObject {
    id: api

    // Typed (an inline component), so qmllint knows its properties.
    component Prefs: Settings {
        category: "server"
        property string url: ""
        property string user: ""
        property string token: ""
        property string salt: ""
    }
    readonly property Prefs settings: Prefs {}
    readonly property bool configured: settings.url !== "" && settings.user !== "" && settings.token !== ""
    property bool online: false
    property string error: ""

    function login(url, user, password, cb) {
        let salt = "";
        for (let i = 0; i < 16; i++)
            salt += Math.floor(Math.random() * 16).toString(16);
        settings.url = url.trim().replace(/\/+$/, "");
        settings.user = user.trim();
        settings.salt = salt;
        settings.token = Qt.md5(password + salt);
        get("ping", {}, cb);
    }

    function url(method, params) {
        let q = "u=" + encodeURIComponent(settings.user) + "&t=" + settings.token + "&s=" + settings.salt
            + "&v=1.16.1&c=ryugin&f=json";
        for (const k in params)
            if (params[k] !== undefined)
                q += "&" + k + "=" + encodeURIComponent(params[k]);
        return settings.url + "/rest/" + method + "?" + q;
    }

    function get(method, params, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = JSON.parse(xhr.responseText)["subsonic-response"];
            } catch (e) {}
            if (!r) {
                api.online = false;
                api.error = xhr.status ? "HTTP " + xhr.status : "No answer from " + settings.url;
            } else if (r.status !== "ok") {
                api.error = r.error ? r.error.message : "Server error";
                r = null;
            } else {
                api.online = true;
                api.error = "";
            }
            if (cb)
                cb(r ? null : api.error, r);
        };
        xhr.open("GET", url(method, params || {}));
        xhr.send();
    }

    function cover(id, size) {
        // size 0: the original picture.
        return id ? url("getCoverArt", { id: id, size: size === 0 ? undefined : size || 300 }) : "";
    }
    // Go's relay (stream.go, set by Main.qml): the song cache, and plain http for Sailfish OS.
    property string streamProxy: ""
    // The song cache (Go, stream.go), when Go's relay runs. params, all optional: on (1 or
    // 0), limit (GB), clear (1). cb(bytes the cache holds).
    function cache(params, cb) {
        if (streamProxy === "")
            return;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (r && cb)
                cb(r.size);
        };
        let q = "";
        for (const k in params)
            q += "&" + k + "=" + encodeURIComponent(params[k]);
        xhr.open("GET", streamProxy.replace("?u=", "cache?") + q.slice(1));
        xhr.send();
    }
    function stream(id) {
        const u = url("stream", { id: id, format: "raw", estimateContentLength: true }); // raw: seekable
        return streamProxy !== "" ? streamProxy + encodeURIComponent(u) : u;
    }

    function track(s) {
        return {
            id: s.id, title: s.title || "", artist: s.artist || "", album: s.album || "",
            albumId: s.albumId || "", artistId: s.artistId || "", cover: s.coverArt || "",
            duration: s.duration || 0, starred: !!s.starred, number: s.track || 0, disc: s.discNumber || 1,
            suffix: s.suffix || "", bitRate: s.bitRate || 0, bitDepth: s.bitDepth || 0, samplingRate: s.samplingRate || 0
        };
    }
    // "Hi-Res", "Lossless" or the bitrate ("320K"), like SPlayer's quality tag.
    function quality(t) {
        if (["flac", "alac", "wav", "ape", "wv", "aiff", "dsf"].indexOf((t.suffix || "").toLowerCase()) >= 0)
            return t.bitDepth > 16 || t.samplingRate > 48000 ? "Hi-Res" : "Lossless";
        return t.bitRate ? t.bitRate + "K" : (t.suffix || "").toUpperCase();
    }
    function album(a) {
        return {
            id: a.id, title: a.name || a.title || "", artist: a.artist || "", artistId: a.artistId || "",
            cover: a.coverArt || "", year: a.year || 0, songCount: a.songCount || 0,
            duration: a.duration || 0, starred: !!a.starred
        };
    }

    // recent, frequent, starred, newest, random, alphabeticalByName...
    function albumList(type, size, offset, cb) {
        get("getAlbumList2", { type: type, size: size, offset: offset || 0 }, function (e, r) {
            cb(((r && r.albumList2 && r.albumList2.album) || []).map(album));
        });
    }

    function allAlbums(cb) {
        const all = [];
        const page = function (offset) {
            albumList("alphabeticalByName", 500, offset, function (list) {
                for (const a of list)
                    all.push(a);
                if (list.length === 500)
                    page(offset + 500);
                else
                    cb(all);
            });
        };
        page(0);
    }

    function getAlbum(id, cb) {
        get("getAlbum", { id: id }, function (e, r) {
            if (!r)
                return cb(null, []);
            cb(album(r.album), (r.album.song || []).map(track));
        });
    }

    function artists(cb) {
        get("getArtists", {}, function (e, r) {
            const out = [];
            for (const index of (r && r.artists && r.artists.index) || [])
                for (const a of index.artist || [])
                    out.push({ id: a.id, name: a.name, albumCount: a.albumCount || 0, cover: a.coverArt || "" });
            cb(out);
        });
    }

    function getArtist(id, cb) {
        get("getArtist", { id: id }, function (e, r) {
            cb(r ? r.artist.name : "", ((r && r.artist.album) || []).map(album));
        });
    }

    function playlists(cb) {
        get("getPlaylists", {}, function (e, r) {
            cb(((r && r.playlists && r.playlists.playlist) || []).map(function (p) {
                return { id: p.id, name: p.name, songCount: p.songCount || 0, cover: p.coverArt || "" };
            }));
        });
    }

    function getPlaylist(id, cb) {
        get("getPlaylist", { id: id }, function (e, r) {
            cb(((r && r.playlist && r.playlist.entry) || []).map(track));
        });
    }

    function search(query, cb) {
        get("search3", { query: query, artistCount: 12, albumCount: 24, songCount: 40 }, function (e, r) {
            const s = (r && r.searchResult3) || {};
            cb({
                artists: (s.artist || []).map(function (a) { return { id: a.id, name: a.name }; }),
                albums: (s.album || []).map(album),
                songs: (s.song || []).map(track)
            });
        });
    }

    // Lyrics: Navidrome first (OpenSubsonic getLyricsBySongId, then plain getLyrics), then
    // LRCLIB (lrclib.net, free and open). Synced beats plain.
    // cb(lines, synced): lines are { time (ms, -1 when not synced), text }.
    function lyrics(t, cb) {
        get("getLyricsBySongId", { id: t.id }, function (e, r) {
            const list = ((r && r.lyricsList && r.lyricsList.structuredLyrics) || [])
                .filter(function (l) { return l.line && l.line.length; });
            const pick = list.find(function (l) { return l.synced; }) || list[0];
            if (pick && pick.synced)
                return cb(pick.line.map(function (l) {
                    return lyricLine(Math.max(0, (l.start || 0) - (pick.offset || 0)), l.value || "", pick.offset || 0);
                }), true);
            const plain = pick ? pick.line.map(function (l) { return l.value || ""; }).join("\n") : "";
            get("getLyrics", { artist: t.artist, title: t.title }, function (e2, r2) {
                // The tag as is: LRC when the song's lyrics are synced.
                const text = plain || (r2 && r2.lyrics && r2.lyrics.value) || "";
                const synced = lrc(text);
                if (synced.length)
                    return cb(synced, true);
                lrclib(t, plainLines(text), cb);
            });
        });
    }

    property string lrclibUrl: "https://lrclib.net/api/"

    // Synced lyrics from LRCLIB, or else the plain ones we already have (or LRCLIB's).
    // Exact match first, then a search by artist and title, then by title alone (only a
    // hit of about the same length counts), then by the song's original title from
    // MusicBrainz (an English tag, Japanese lyrics).
    function lrclib(t, plain, cb) {
        const artist = clean(t.artist); // "A (feat. B)" -> "A"
        const q = "track_name=" + encodeURIComponent(clean(t.title)); // "Song [Show]" -> "Song"
        const done = function (hit) {
            if (hit && hit.syncedLyrics)
                return cb(lrc(hit.syncedLyrics), true);
            cb(plain.length ? plain : plainLines((hit && hit.plainLyrics) || ""), false);
        };
        fetchJson(lrclibUrl + "get?artist_name=" + encodeURIComponent(artist) + "&" + q + "&album_name="
                  + encodeURIComponent(t.album || "") + "&duration=" + (t.duration || 0), function (hit) {
            if (hit && hit.syncedLyrics)
                return done(hit);
            fetchJson(lrclibUrl + "search?artist_name=" + encodeURIComponent(artist) + "&" + q, function (list) {
                // Synced lyrics only from a recording of the same length (± 2 s): another
                // version (a longer intro) puts every line seconds early or late.
                const best = pickHit(list, t.duration, 2) || hit || plainOnly(pickHit(list, 0));
                if (best && best.syncedLyrics)
                    return done(best);
                fetchJson(lrclibUrl + "search?" + q, function (list2) {
                    const near = pickHit(list2, t.duration, 2) || best;
                    if (near || plain.length)
                        return done(near);
                    original(t, function (o) {
                        if (!o)
                            return done(null);
                        fetchJson(lrclibUrl + "search?track_name=" + encodeURIComponent(o.title), function (list3) {
                            done(pickHit(list3, t.duration, 5));
                        });
                    });
                });
            });
        });
    }

    // The hit with words (synced first); with a length, only hits that long (± slack s).
    // A hit's plain lyrics only (its timing belongs to another recording).
    function plainOnly(h) {
        return h ? { plainLyrics: h.plainLyrics || h.syncedLyrics || "" } : null;
    }
    function pickHit(list, length, slack) {
        list = (Array.isArray(list) ? list : []).filter(function (h) {
            return !length || Math.abs(h.duration - length) <= slack;
        });
        return list.find(function (h) { return h.syncedLyrics; }) || list.find(function (h) { return h.plainLyrics; });
    }

    // "Let's Go!! Rider Kick [Masked Rider]" -> "Let's Go!! Rider Kick"
    function clean(s) {
        return (s || "").replace(/\s*[(\[].*$/, "").trim() || (s || "");
    }

    // The song's original title and artist on MusicBrainz: the album's release, then the
    // track at the same disc and position, if its length agrees (± 5 s). A release is
    // asked for once per album.
    property string mbUrl: "https://musicbrainz.org/ws/2/"
    property var releases: ({})
    function original(t, cb) {
        const pick = function (rel) {
            const disc = rel && (rel.media || [])[(t.disc || 1) - 1];
            const tr = disc && (disc.tracks || [])[(t.number || 0) - 1];
            if (!tr || (tr.length && t.duration && Math.abs(tr.length / 1000 - t.duration) > 5))
                return cb(null);
            cb({ title: tr.title.normalize("NFKC"), artist: ((tr["artist-credit"] || [])[0] || {}).name || "" });
        };
        if (!t.album || !t.number)
            return cb(null);
        if (t.album in releases)
            return pick(releases[t.album]);
        mbJson("release/?fmt=json&limit=1&query=" + encodeURIComponent('release:"' + t.album.replace(/"/g, "") + '"'), function (found) {
            const id = found && found.releases && found.releases[0] && found.releases[0].id;
            if (!id) {
                if (found)
                    releases[t.album] = null; // not on MusicBrainz; a busy server is asked again later
                return cb(null);
            }
            mbJson("release/" + id + "?fmt=json&inc=recordings+artist-credits", function (rel) {
                if (rel)
                    releases[t.album] = rel;
                pick(rel);
            });
        });
    }
    function mbJson(path, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            cb(r);
        };
        xhr.open("GET", mbUrl + path);
        xhr.setRequestHeader("User-Agent", "ryugin/1.0 ( https://codeberg.org )"); // MusicBrainz asks for one
        xhr.setRequestHeader("Accept", "application/json");
        xhr.send();
    }

    // Last try, for songs tagged in another language than LRCLIB has them (an English
    // tag, Japanese lyrics): the album's songs on LRCLIB, matched by exact length (ms, from
    // the player). Rips of the same CD agree to a few hundredths of a second.
    function albumLyrics(t, ms, cb) {
        if (!t.album || ms <= 0)
            return cb([], false);
        const off = /instrumental|インストゥルメンタル|karaoke|カラオケ|off vocal/i;
        fetchJson(lrclibUrl + "search?q=" + encodeURIComponent(t.album), function (list) {
            const gap = function (h) { return Math.abs(h.duration * 1000 - ms); };
            const hit = (Array.isArray(list) ? list : []).filter(function (h) {
                return gap(h) <= 150 && (h.syncedLyrics || h.plainLyrics) && (off.test(t.title) || !off.test(h.trackName || ""));
            }).sort(function (a, b) { return gap(a) - gap(b); })[0];
            if (!hit)
                cb([], false);
            else if (hit.syncedLyrics)
                cb(lrc(hit.syncedLyrics), true);
            else
                cb(plainLines(hit.plainLyrics), false);
        });
    }

    function fetchJson(u, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let r = null;
            try {
                r = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            cb(r);
        };
        xhr.open("GET", u);
        xhr.send();
    }

    // Lines without times: LRC tags ("[00:01.00]", "[ar: x]", "<00:01.20>") dropped.
    function plainLines(text) {
        const lines = text.split("\n").filter(function (s) { return !/^\s*\[[a-z]+:.*\]\s*$/i.test(s); }).map(function (s) {
            return s.replace(/\[\d+:\d+(?:\.\d+)?\]|<\d+:\d+(?:\.\d+)?>/g, "").trim();
        });
        return lines.join("\n").trim() ? lines.map(function (s) { return { time: -1, text: s }; }) : [];
    }

    // "[01:02.50] text" -> { time: 62500, text, words }; a line sung again has a stamp for
    // each time ("[00:12.00][01:30.00] chorus").
    function lrc(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const m = /^((?:\[\d+:\d+(?:\.\d+)?\])+)(.*)$/.exec(line.trim());
            if (!m)
                continue;
            for (const st of m[1].match(/\d+:\d+(?:\.\d+)?/g)) {
                const [min, sec] = st.split(":");
                out.push(lyricLine(Math.round((parseInt(min) * 60 + parseFloat(sec)) * 1000), m[2], 0));
            }
        }
        return out.sort(function (a, b) { return a.time - b.time; });
    }

    // A line with word times (enhanced LRC), "<00:13.99>布<00:14.16>団<00:14.48>":
    // { time, text: "布団", words: [{ time: 13990, end: 14160, text: "布" }, ...] }. Each word
    // ends where the next starts (an empty last word only ends the one before); end is -1
    // when the line does not say. A line without them has no words.
    function lyricLine(time, raw, offset) {
        const parts = raw.split(/<(\d+):(\d+(?:\.\d+)?)>/); // text, m, s, text, m, s, text...
        const words = [];
        if (parts.length > 1 && parts[0].trim())
            words.push({ time: time, end: -1, text: parts[0] });
        for (let i = 1; i + 2 < parts.length; i += 3) {
            const t = Math.max(0, Math.round((parseInt(parts[i]) * 60 + parseFloat(parts[i + 1])) * 1000) - offset);
            if (words.length && words[words.length - 1].end < 0)
                words[words.length - 1].end = t;
            if (parts[i + 2] !== "")
                words.push({ time: t, end: -1, text: parts[i + 2] });
        }
        return { time: time, text: words.length ? words.map(function (w) { return w.text; }).join("").trim() : raw.trim(), words: words };
    }

    function randomSongs(size, cb) {
        get("getRandomSongs", { size: size }, function (e, r) {
            cb(((r && r.randomSongs && r.randomSongs.song) || []).map(track));
        });
    }

    function starredSongs(cb) {
        get("getStarred2", {}, function (e, r) {
            cb(((r && r.starred2 && r.starred2.song) || []).map(track));
        });
    }

    // Navidrome's last scan: a new one (songs added, tags changed) tells the pages to
    // reload. The first answer only sets the mark; a scan still running is waited for.
    property string lastScan: ""
    signal libraryChanged()
    onConfiguredChanged: lastScan = ""
    function checkLibrary() {
        if (!configured)
            return;
        get("getScanStatus", {}, function (e, r) {
            const s = r && r.scanStatus;
            if (!s || s.scanning || !s.lastScan)
                return;
            const changed = lastScan !== "" && s.lastScan !== lastScan;
            lastScan = s.lastScan;
            if (changed)
                libraryChanged();
        });
    }

    function songCount(cb) {
        get("getScanStatus", {}, function (e, r) {
            cb((r && r.scanStatus && r.scanStatus.count) || 0);
        });
    }

    function scrobble(id, submission) {
        get("scrobble", { id: id, submission: submission, time: Date.now() });
    }

    function star(id, on) {
        get(on ? "star" : "unstar", { id: id });
    }
}
