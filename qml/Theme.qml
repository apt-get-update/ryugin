pragma Singleton
import QtQuick
import QtCore

// Every colour comes from one tone: the playing cover's dominant colour (like SPlayer's
// "follow cover colour"), or warm gold when that is off or the cover is grey.
QtObject {
    id: theme
    // Typed (an inline component), so qmllint knows its properties.
    component Prefs: Settings {
        category: "theme"
        property bool followCover: true
    }
    readonly property Prefs settings: Prefs {}
    property color seed: fallback
    property string flow: "" // the moving backdrop: the cover's 32x32 AMLL texture (a PNG from Go)
    property string wash: "" // the still backdrop: the cover blurred for the window (a PNG from Go)
    readonly property color fallback: "#e2b55e"
    readonly property color tone: settings.followCover && seed.hslSaturation >= 0.12 ? seed : fallback
    // A new song's tone fades in by hue (the short way round) and saturation, never
    // through an RGB mix: that passes by grey, whose hue is red, and the UI blinked.
    property real hue: fallback.hslHue // unwrapped
    property real sat: fallback.hslSaturation
    Behavior on hue { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    Behavior on sat { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    onToneChanged: {
        if (tone.hslHue >= 0) {
            let d = tone.hslHue - (hue - Math.floor(hue));
            hue += d > 0.5 ? d - 1 : d < -0.5 ? d + 1 : d;
        }
        sat = Math.max(0, tone.hslSaturation);
    }

    readonly property real h: hue - Math.floor(hue)
    readonly property real s: sat
    readonly property real ss: Math.min(s, 0.45)
    function c(sat, light, alpha) { return Qt.hsla(h, sat, light, alpha === undefined ? 1 : alpha); }

    // Lightness ladder measured on SPlayer-Next's screen (page, panels, buttons, text).
    readonly property color bg: c(ss * 0.72, 0.18)
    readonly property color panel: c(ss * 0.9, 0.145)
    readonly property color card: c(ss * 0.6, 0.22)
    readonly property color cardHover: c(ss * 0.55, 0.26)
    readonly property color bright: c(ss * 0.55, 0.29)
    readonly property color field: c(ss * 0.65, 0.2)
    readonly property color border: c(ss * 0.58, 0.23)
    readonly property color track: c(0.4, 0.85, 0.12)
    readonly property color text: c(0.55, 0.88)
    readonly property color dim: c(0.17, 0.665)
    readonly property color faint: c(0.13, 0.52)
    readonly property color gold: c(0.6, 0.8)
    readonly property color goldSoft: c(0.6, 0.8, 0.13)
    readonly property color goldInk: c(0.4, 0.12)
    readonly property int radius: 10
    readonly property int radiusXl: 14

    // 245 -> "4:05"
    function time(seconds) {
        const t = Math.max(0, Math.floor(seconds));
        const hh = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), r = t % 60;
        return (hh ? hh + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }
}
