pragma Singleton
import QtQuick

// Lucide icons (ISC license, https://lucide.dev), as SVG bodies; COLOR is filled in by Icon.qml.
QtObject {
    // The same icons in the desktop's icon theme (freedesktop names, symbolic: one colour,
    // so a shape), used first when the theme has them; the others stay Lucide: the dice and
    // the radio (a theme draws a gamepad and a radio button), shuffle and the three repeats
    // (their states must read as one set).
    property string dir: "" // the theme's icons as PNGs, drawn by Go (Main.qml sets it)
    property var have: ({}) // the theme names drawn
    readonly property var theme: ({
        "chevron-left": "go-previous-symbolic", "chevron-right": "go-next-symbolic", "chevron-down": "go-down-symbolic", "chevron-up": "go-up-symbolic",
        "disc-3": "media-optical-audio-symbolic", "house": "go-home-symbolic",
        "mic": "audio-input-microphone-symbolic", "users": "system-users-symbolic",
        "play": "media-playback-start-symbolic", "play-fill": "media-playback-start-symbolic",
        "pause": "media-playback-pause-symbolic", "pause-fill": "media-playback-pause-symbolic",
        "skip-back": "media-skip-backward-symbolic", "skip-back-fill": "media-skip-backward-symbolic",
        "skip-forward": "media-skip-forward-symbolic", "skip-forward-fill": "media-skip-forward-symbolic",
        "plus": "list-add-symbolic", "search": "edit-find-symbolic", "settings": "emblem-system-symbolic",
        "star": "non-starred-symbolic",
        "volume-2": "audio-volume-high", "volume-1": "audio-volume-medium-symbolic", "volume-x": "audio-volume-muted-symbolic",
        "x": "window-close-symbolic",
        "trash-2": "edit-delete-symbolic", "check": "object-select-symbolic", "refresh-cw": "view-refresh-symbolic",
        "favorite": "emblem-favorite-symbolic", "server": "network-server-symbolic", "sparkles": "color-select-symbolic",
        "info": "help-about-symbolic", "list-ordered": "view-list-ordered-symbolic", "list-plus": "list-add-symbolic",
        "panel-left": "view-left-pane-symbolic", "locate": "find-location-symbolic",
        "history": "document-open-recent-symbolic"
    })
    // Lucide's icon as a white SVG of px pixels (it states its size: Qt ignores sourceSize
    // for a data: URL), or "" for an unknown name.
    // color: drawn in it (Sailfish OS: Silica does not tint a picture), else white.
    function url(name, px, color) {
        return draw(name, px, color, "0 0 24 24", 2);
    }
    // As Silica draws its icons (Sailfish OS): the shape in 69 % of the box, a 4 % line.
    function silica(name, px, color) {
        return draw(name, px, color, "-2.5 -2.5 29 29", 1.15);
    }
    function draw(name, px, color, box, line) {
        const c = color ? String(color) : "#ffffff";
        return svg[name] ? "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="' + px + '" height="' + px + '" viewBox="' + box + '">'
            + svg[name].replace(/COLOR/g, c.length === 9 ? "#" + c.slice(3) : c).replace(/stroke-width="([\d.]+)"/g, (m, w) => 'stroke-width="' + w * line / 2 + '"')
            + '</svg>') : ""; // #aarrggbb: no alpha
    }
    readonly property var svg: ({
        "chevron-left": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m15 18l-6-6l6-6\"/>",
        "chevron-right": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m9 18l6-6l-6-6\"/>",
        "dices": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><rect width=\"12\" height=\"12\" x=\"2\" y=\"10\" rx=\"2\" ry=\"2\"/><path d=\"m17.92 14l3.5-3.5a2.24 2.24 0 0 0 0-3l-5-4.92a2.24 2.24 0 0 0-3 0L10 6M6 18h.01M10 14h.01M15 6h.01M18 9h.01\"/></g>",
        "disc-3": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M6 12c0-1.7.7-3.2 1.8-4.2\"/><circle cx=\"12\" cy=\"12\" r=\"2\"/><path d=\"M18 12c0 1.7-.7 3.2-1.8 4.2\"/></g>",
        "eye": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M2.062 12.348a1 1 0 0 1 0-.696a10.75 10.75 0 0 1 19.876 0a1 1 0 0 1 0 .696a10.75 10.75 0 0 1-19.876 0\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/></g>",
        "eye-off": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575a1 1 0 0 1 0 .696a10.8 10.8 0 0 1-1.444 2.49m-6.41-.679a3 3 0 0 1-4.242-4.242\"/><path d=\"M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151a1 1 0 0 1 0-.696a10.75 10.75 0 0 1 4.446-5.143M2 2l20 20\"/></g>",
        "heart": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M2 9.5a5.5 5.5 0 0 1 9.591-3.676a.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5\"/>",
        "house": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8\"/><path d=\"M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\"/></g>",
        "library": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m16 6l4 14M12 6v14M8 8v12M4 4v16\"/>",
        "list-music": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M16 5H3m8 7H3m8 7H3m18-3V5\"/><circle cx=\"18\" cy=\"16\" r=\"3\"/></g>",
        "mic-vocal": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"m11 7.601l-5.994 8.19a1 1 0 0 0 .1 1.298l.817.818a1 1 0 0 0 1.314.087L15.09 12\"/><path d=\"M16.5 21.174C15.5 20.5 14.372 20 13 20c-2.058 0-3.928 2.356-6 2s-2.775-3.369-1.5-4.5\"/><circle cx=\"16\" cy=\"7\" r=\"5\"/></g>",
        "music": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M9 18V5l12-2v13\"/><circle cx=\"6\" cy=\"18\" r=\"3\"/><circle cx=\"18\" cy=\"16\" r=\"3\"/></g>",
        "pause": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><rect width=\"5\" height=\"18\" x=\"14\" y=\"3\" rx=\"1\"/><rect width=\"5\" height=\"18\" x=\"5\" y=\"3\" rx=\"1\"/></g>",
        "play": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z\"/>",
        "plus": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 12h14m-7-7v14\"/>",
        "search": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"m21 21l-4.34-4.34\"/><circle cx=\"11\" cy=\"11\" r=\"8\"/></g>",
        "server": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><rect width=\"20\" height=\"8\" x=\"2\" y=\"2\" rx=\"2\" ry=\"2\"/><rect width=\"20\" height=\"8\" x=\"2\" y=\"14\" rx=\"2\" ry=\"2\"/><path d=\"M6 6h.01M6 18h.01\"/></g>",
        "settings": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M9.671 4.136a2.34 2.34 0 0 1 4.659 0a2.34 2.34 0 0 0 3.319 1.915a2.34 2.34 0 0 1 2.33 4.033a2.34 2.34 0 0 0 0 3.831a2.34 2.34 0 0 1-2.33 4.033a2.34 2.34 0 0 0-3.319 1.915a2.34 2.34 0 0 1-4.659 0a2.34 2.34 0 0 0-3.32-1.915a2.34 2.34 0 0 1-2.33-4.033a2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915\"/><circle cx=\"12\" cy=\"12\" r=\"3\"/></g>",
        "shuffle": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"m18 14l4 4l-4 4m0-20l4 4l-4 4\"/><path d=\"M2 18h1.973a4 4 0 0 0 3.3-1.7l5.454-8.6a4 4 0 0 1 3.3-1.7H22M2 6h1.972a4 4 0 0 1 3.6 2.2M22 18h-6.041a4 4 0 0 1-3.3-1.8l-.359-.45\"/></g>",
        "skip-back": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432zM3 20V4\"/>",
        "skip-forward": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M21 4v16M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z\"/>",
        "sparkles": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594zM20 2v4m2-2h-4\"/><circle cx=\"4\" cy=\"20\" r=\"2\"/></g>",
        "star": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.12 2.12 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.12 2.12 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.12 2.12 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.12 2.12 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.12 2.12 0 0 0 1.597-1.16z\"/>",
        "users": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 3.128a4 4 0 0 1 0 7.744M22 21v-2a4 4 0 0 0-3-3.87\"/><circle cx=\"9\" cy=\"7\" r=\"4\"/></g>",
        "volume-2": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298zM16 9a5 5 0 0 1 0 6m3.364 3.364a9 9 0 0 0 0-12.728\"/>",
        "volume-x": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298zm5.5 9.798l5-5m-5 0l5 5\"/>",
        "refresh-cw": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M3 12a9 9 0 0 1 9-9a9.75 9.75 0 0 1 6.74 2.74L21 8\"/><path d=\"M21 3v5h-5m5 4a9 9 0 0 1-9 9a9.75 9.75 0 0 1-6.74-2.74L3 16\"/><path d=\"M8 16H3v5\"/></g>",
        "favorite": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M2 9.5a5.5 5.5 0 0 1 9.591-3.676a.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5\"/>",
        "panel-left": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\"/><path d=\"M9 3v18\"/></g>",
        "chevron-up": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m18 15l-6-6l-6 6\"/>",
        "grip-vertical": "<g fill=\"COLOR\"><circle cx=\"9\" cy=\"5\" r=\"1.5\"/><circle cx=\"9\" cy=\"12\" r=\"1.5\"/><circle cx=\"9\" cy=\"19\" r=\"1.5\"/><circle cx=\"15\" cy=\"5\" r=\"1.5\"/><circle cx=\"15\" cy=\"12\" r=\"1.5\"/><circle cx=\"15\" cy=\"19\" r=\"1.5\"/></g>",
        "x": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M18 6L6 18M6 6l12 12\"/>",
        // SPlayer-Next's play-order: shuffle off.
        "play-order": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M2 6h16m0-4l4 4l-4 4M2 18h16m0-4l4 4l-4 4\"/>",
        "repeat": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"m17 2l4 4l-4 4\"/><path d=\"M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4l4-4\"/><path d=\"M21 13v1a4 4 0 0 1-4 4H3\"/></g>",
        "radio": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M16.247 7.761a6 6 0 0 1 0 8.478m2.828-11.306a10 10 0 0 1 0 14.134m-14.15 0a10 10 0 0 1 0-14.134m2.828 11.306a6 6 0 0 1 0-8.478\"/><circle cx=\"12\" cy=\"12\" r=\"2\"/></g>",
        "history": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M3 12a9 9 0 1 0 9-9a9.75 9.75 0 0 0-6.74 2.74L3 8\"/><path d=\"M3 3v5h5m4-1v5l4 2\"/></g>",
        "text-quote": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17 5H3m18 7H8m13 7H8m-5-7v7\"/>",
        "chevron-down": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m6 9l6 6l6-6\"/>",
        "repeat-1": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"m17 2l4 4l-4 4\"/><path d=\"M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4l4-4\"/><path d=\"M21 13v1a4 4 0 0 1-4 4H3m8-8h1v4\"/></g>",
        "locate": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M2 12h3m14 0h3M12 2v3m0 14v3\"/><circle cx=\"12\" cy=\"12\" r=\"7\"/></g>",
        "trash-2": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 11v6m4-6v6m5-11v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"/>",
        "mic": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><path d=\"M12 19v3m7-12v2a7 7 0 0 1-14 0v-2\"/><rect width=\"6\" height=\"13\" x=\"9\" y=\"2\" rx=\"3\"/></g>",
        "volume-1": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298zM16 9a5 5 0 0 1 0 6\"/>",
        "check": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M20 6L9 17l-5-5\"/>",
        "info": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 16v-4m0-4h.01\"/></g>",
        "list-ordered": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 12h11M10 18h11M10 6h11M4 10h2M4 6h1v4m1 8H4c0-1 2-2 2-3s-1-1.5-2-1\"/>",
        "list-plus": "<path fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11 12H3m13-6H3m13 12H3m15-9v6m3-3h-6\"/>",
        // Lucide's zap with two small hearts, clear of the bolt (a coup de foudre, not a broken
        // heart); scaled parts have wider strokes, to draw as thick as the others.
        "heartbeat": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path transform=\"translate(1.6 2.4) scale(.8)\" stroke-width=\"2.5\" d=\"M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z\"/><path transform=\"translate(16.8 1) scale(1.1)\" stroke-width=\"1.82\" d=\"M3 5.5S0 3.7 0 1.75A1.6 1.6 0 0 1 3 1A1.6 1.6 0 0 1 6 1.75C6 3.7 3 5.5 3 5.5z\"/><path transform=\"translate(.8 16.5) scale(1.1)\" stroke-width=\"1.82\" d=\"M3 5.5S0 3.7 0 1.75A1.6 1.6 0 0 1 3 1A1.6 1.6 0 0 1 6 1.75C6 3.7 3 5.5 3 5.5z\"/></g>",
        "heart-fill": "<path fill=\"COLOR\" d=\"M11.288 20.2q-.363-.125-.638-.4l-1.725-1.575q-2.65-2.425-4.787-4.812T2 8.15Q2 5.8 3.575 4.225T7.5 2.65q1.325 0 2.5.562t2 1.538q.825-.975 2-1.537t2.5-.563q2.35 0 3.925 1.575T22 8.15q0 2.875-2.125 5.275T15.05 18.25l-1.7 1.55q-.275.275-.637.4t-.713.125t-.712-.125\"/>",
        "layout-template": "<g fill=\"none\" stroke=\"COLOR\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"><rect width=\"18\" height=\"7\" x=\"3\" y=\"3\" rx=\"1\"/><rect width=\"9\" height=\"7\" x=\"3\" y=\"14\" rx=\"1\"/><rect width=\"5\" height=\"7\" x=\"16\" y=\"14\" rx=\"1\"/></g>",
        "play-fill": "<path fill=\"COLOR\" d=\"M7 4.6c0-1 1.1-1.6 2-1.1l11.2 6.9c.8.5.8 1.7 0 2.2L9 19.5c-.9.5-2-.1-2-1.1z\"/>",
        "pause-fill": "<rect x=\"5.5\" y=\"4\" width=\"4.5\" height=\"16\" rx=\"1.4\" fill=\"COLOR\"/><rect x=\"14\" y=\"4\" width=\"4.5\" height=\"16\" rx=\"1.4\" fill=\"COLOR\"/>",
        "skip-forward-fill": "<path fill=\"COLOR\" d=\"M4 5.4c0-.9 1-1.4 1.7-.9l10.4 6.6c.7.4.7 1.4 0 1.8L5.7 19.5c-.7.5-1.7 0-1.7-.9z\"/><rect x=\"17.6\" y=\"4.5\" width=\"2.8\" height=\"15\" rx=\"1.4\" fill=\"COLOR\"/>",
        "skip-back-fill": "<path fill=\"COLOR\" d=\"M20 5.4c0-.9-1-1.4-1.7-.9L7.9 11.1c-.7.4-.7 1.4 0 1.8l10.4 6.6c.7.5 1.7 0 1.7-.9z\"/><rect x=\"3.6\" y=\"4.5\" width=\"2.8\" height=\"15\" rx=\"1.4\" fill=\"COLOR\"/>",
    })
}
