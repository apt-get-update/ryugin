pragma Singleton
import QtQuick
import QtCore

// Every colour comes from one tone: the playing cover's dominant colour (like SPlayer's
// "follow cover colour"), or warm gold when the cover is grey; or, when following the
// cover is off, from the desktop's palette.
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

    // Follow album colours off: the desktop's own colours (qt6ct, KDE: the system palette).
    // A switch fades over 800 ms, like a new song's tone.
    readonly property SystemPalette sys: SystemPalette {}
    property real k: settings.followCover ? 1 : 0 // 0: system, 1: cover
    Behavior on k { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }
    function pick(system, cover) { return mix(system, cover, k); }
    function alpha(col, a) { return Qt.rgba(col.r, col.g, col.b, a); }
    // A list row's ground: lit when chosen (or playing), faint under the mouse.
    function lit(on, hover) { return alpha(text, on ? 0.11 : hover ? 0.05 : 0); }
    // See-through like the desktop's other apps (Kvantum's reduce_window_opacity=30), so
    // the compositor's blur shows behind the window, in both modes; panels and cards lie
    // over it, half see-through.
    readonly property real glass: 0.7

    // Lightness ladder measured on SPlayer-Next's screen (page, panels, buttons, text).
    readonly property color bg: alpha(pick(sys.window, c(ss * 0.72, 0.18)), glass)
    readonly property color popup: alpha(pick(sys.window, c(ss * 0.72, 0.18)), 0.8) // over the blurred page
    readonly property color panel: alpha(pick(sys.base, c(ss * 0.9, 0.145)), 0.5)
    readonly property color card: alpha(pick(sys.button, c(ss * 0.6, 0.22)), 0.5)
    readonly property color cardHover: alpha(pick(Qt.lighter(sys.button, 1.2), c(ss * 0.55, 0.26)), 0.6)
    readonly property color bright: alpha(pick(Qt.lighter(sys.button, 1.4), c(ss * 0.55, 0.29)), 0.7)
    readonly property color field: alpha(pick(sys.base, c(ss * 0.65, 0.2)), 0.5)
    readonly property color border: alpha(pick(Qt.lighter(sys.button, 1.15), c(ss * 0.58, 0.23)), 0.6)
    readonly property color track: alpha(pick(sys.windowText, c(0.4, 0.85, 0.12)), 0.12)
    readonly property color text: pick(sys.windowText, c(0.55, 0.88))
    readonly property color dim: pick(mix(sys.windowText, sys.window, 0.3), c(0.17, 0.665))
    readonly property color faint: pick(mix(sys.windowText, sys.window, 0.5), c(0.13, 0.52))
    readonly property color gold: pick(sys.highlight, c(0.6, 0.8))
    readonly property color goldSoft: alpha(pick(sys.highlight, c(0.6, 0.8, 0.13)), 0.13)
    readonly property color goldInk: pick(sys.highlightedText, c(0.4, 0.12))
    readonly property int radius: 10
    readonly property int radiusXl: 14

    // 245 -> "4:05"
    function time(seconds) {
        const t = Math.max(0, Math.floor(seconds));
        const hh = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), r = t % 60;
        return (hh ? hh + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }
}
