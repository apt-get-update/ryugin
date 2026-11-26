import QtQuick
import "../../qml"

// Points Api at the mock Navidrome (tests/mocknavidrome) and reads back its call log.
QtObject {
    readonly property string url: "http://127.0.0.1:4533"
    function connect() {
        Api.settings.url = url;
        Api.settings.user = "u";
        Api.settings.token = "t";
        Api.settings.salt = "s";
        Api.lrclibUrl = url + "/lrclib/";
        Api.mbUrl = url + "/mb/";
    }
    // The calls made since the last reset, e.g. ["scrobble?u=...&id=s0&submission=true"].
    function calls(reset) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url + "/calls" + (reset ? "?reset=1" : ""), false);
        xhr.send();
        return JSON.parse(xhr.responseText) || [];
    }
    // Navidrome scans the library again (a new lastScan); running: a scan not ended yet.
    function scan(running) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url + "/scan" + (running ? "?running=1" : ""), false);
        xhr.send();
    }
    function called(method, part) {
        return calls(false).some(function (c) { return c.startsWith(method + "?") && (!part || c.indexOf(part) >= 0); });
    }
}
