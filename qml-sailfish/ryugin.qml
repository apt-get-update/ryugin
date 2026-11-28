import QtQuick 6.4
import Sailfish.Silica 1.0
import "../qml" as R
import "components"

// Ryūgin on Sailfish OS (Keel: Silica on Qt 6). The library, playback and Navidrome are the
// desktop's (qml/: Api, Player); this tree is the Silica UI over them. Go (main_silica.go)
// sets goBridge and goStreamProxy, and sends commands through goCommand.
ApplicationWindow {
    id: app

    property string goCommand

    initialPage: Qt.resolvedUrl("pages/HomePage.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    // The song's mini ambience (1.2's "follow cover colour"), made as Sailfish makes one
    // from a picture (jolla-gallery-ambience): the hue of the cover's colour (color.go) at
    // full saturation and half value gives the highlight for the ambience's scheme, which
    // gives the rest; primary and secondary are the scheme's. On the page stack and the
    // player: every page takes it. A new hue turns in the short way round.
    readonly property bool _tinted: R.Theme.settings.followCover && R.Player.current !== null
    property real _hue: R.Theme.fallback.hsvHue // unwrapped: 1.1 is 0.1
    readonly property var _palette: {
        if (!_tinted) {
            return {
                primaryColor: Theme.primaryColor,
                secondaryColor: Theme.secondaryColor,
                highlightColor: Theme.highlightColor,
                secondaryHighlightColor: Theme.secondaryHighlightColor,
                highlightBackgroundColor: Theme.highlightBackgroundColor,
                highlightDimmerColor: Theme.highlightDimmerColor
            }
        }
        var scheme = Theme.colorScheme
        var light = scheme === Theme.DarkOnLight
        var highlight = Theme.highlightFromColor(Qt.hsva(_hue - Math.floor(_hue), 1.0, 0.5, 1.0), scheme)
        return {
            primaryColor: light ? Theme.darkPrimaryColor : Theme.lightPrimaryColor,
            secondaryColor: light ? Theme.darkSecondaryColor : Theme.lightSecondaryColor,
            highlightColor: highlight,
            secondaryHighlightColor: Theme.secondaryHighlightFromColor(highlight, scheme),
            highlightBackgroundColor: Theme.highlightBackgroundFromColor(highlight, scheme),
            highlightDimmerColor: Theme.highlightDimmerFromColor(highlight, scheme)
        }
    }

    Behavior on _hue {
        NumberAnimation {
            duration: 800
            easing.type: Easing.InOutQuad
        }
    }

    allowedOrientations: defaultAllowedOrientations
    _defaultPageOrientations: defaultAllowedOrientations // the pages too (Sailfish's app template)

    onGoCommandChanged: {
        var c = JSON.parse(goCommand)
        if (c.cmd === "raise") {
            activate()
        } else if (c.cmd === "quit") {
            Qt.quit()
        } else if (c.cmd === "coverColor") {
            // The song's colour and its blurred cover (color.go), for the pages that follow it.
            if (R.Player.current && c.url === R.Api.cover(R.Player.current.cover, 128)) {
                R.Theme.seed = c.color
                R.Theme.wash = c.wash || ""
                var hue = R.Theme.seed.hsvHue
                if (hue >= 0) {
                    var d = hue - (_hue - Math.floor(_hue))
                    _hue += d > 0.5 ? d - 1 : d < -0.5 ? d + 1 : d
                }
            }
        } else {
            R.Player.command(c)
        }
    }

    // The keyboard's link (Go, container.go): which way the pages face, and the app in front.
    readonly property string keyboardLink: JSON.stringify({ keyboard: { angle: backdrops.angle, active: Qt.application.state === Qt.ApplicationActive } })
    onKeyboardLinkChanged: if (R.Player.bridge) R.Player.bridge.objectName = keyboardLink

    Component.onCompleted: {
        // Context properties from Go: unknown to qmllint.
        if (typeof goBridge !== "undefined") {
            R.Player.bridge = goBridge // qmllint disable unqualified
            R.Player.bridge.objectName = keyboardLink
        }
        if (typeof goStreamProxy !== "undefined") {
            R.Api.streamProxy = goStreamProxy // qmllint disable unqualified
        }
        R.Api.cache({ on: R.Player.settings.cache ? 1 : 0, limit: R.Player.settings.cacheLimit })
        Object.keys(_palette).forEach(function (name) {
            pageStack.palette[name] = Qt.binding(function () { return app._palette[name] })
            player.songPalette[name] = Qt.binding(function () { return app._palette[name] })
        })
        if (typeof goStartPage !== "undefined" && goStartPage !== "cover") { // qmllint disable unqualified
            // "AlbumPage?albumId=x": a page with its properties.
            var parts = goStartPage.split("?") // qmllint disable unqualified
            var props = {}
            ;(parts[1] || "").split("&").forEach(function (kv) { if (kv) props[kv.split("=")[0]] = kv.split("=")[1] })
            pageStack.push(Qt.resolvedUrl("pages/" + parts[0] + ".qml"), props, PageStackAction.Immediate)
        }
        if (typeof goShot !== "undefined") {
            _shot.start()
        }
        if (typeof goLandscape !== "undefined") {
            deviceOrientation = Orientation.Landscape
        }
        if (typeof goScroll !== "undefined") {
            _scroll.start()
        }
        if (typeof goPerf !== "undefined") {
            _perf.running = true
        }
        if (typeof goKeyboard !== "undefined") {
            _keyboard.start()
        }
    }

    // Asks Go for the song's colours, once the window has its size (none yet when made).
    Binding {
        target: R.Player
        property: "backdropSide"
        value: Math.max(app.width, app.height)
        when: app.width > 0
    }

    // The song's cover, the wallpaper under every page, turned with them (as the ambience's
    // in landscape), one for each way: on a turn, the new one is under at once and the one
    // before fades out over it, as long as the page's own turn (Silica's: out, turn, in).
    // Out of the window's content, which fades out while the screen turns: it stays, as a
    // real wallpaper behind an app.
    Item {
        id: backdrops

        readonly property int orientation: pageStack.currentPage ? pageStack.currentPage.orientation : Orientation.Portrait
        readonly property bool landscape: (orientation & Orientation.LandscapeMask) !== 0
        readonly property Item shown: turns.count === 2 ? turns.itemAt(landscape ? 1 : 0) : null
        // The page's turn, in degrees.
        readonly property int angle: orientation === Orientation.Landscape ? 90
                                   : orientation === Orientation.PortraitInverted ? 180
                                   : orientation === Orientation.LandscapeInverted ? 270 : 0

        anchors.fill: parent
        z: -1
        Component.onCompleted: parent = app

        Repeater {
            id: turns

            model: 2 // portrait, landscape

            Item {
                readonly property bool mine: (index === 1) === backdrops.landscape

                anchors.centerIn: parent
                width: index === 1 ? parent.height : parent.width
                height: index === 1 ? parent.width : parent.height
                rotation: (index === 1) === backdrops.landscape ? backdrops.angle : index * 90
                z: mine ? 0 : 1
                opacity: mine ? 1 : 0
                onMineChanged: {
                    fade.stop()
                    if (mine) {
                        opacity = 1
                    } else {
                        fade.start()
                    }
                }

                NumberAnimation on opacity {
                    id: fade

                    running: false
                    from: 1
                    to: 0
                    duration: 300
                    easing.type: Easing.InOutQuad
                }

                Backdrop {
                    anchors.fill: parent
                }
            }
        }
    }

    // Over the pages' end (they leave room for it), not beside: its glass shows them.
    MiniPlayer {
        id: player

        backdrop: backdrops.shown
    }

    // tests/silica.sh, page "cover": the home screen's card, drawn over the window.
    Loader {
        anchors.centerIn: parent
        width: Theme.coverSizeLarge.width
        height: Theme.coverSizeLarge.height
        z: 1000
        active: typeof goStartPage !== "undefined" && goStartPage === "cover" // qmllint disable unqualified
        source: app.cover
    }

    // The keyboard closed (a swipe down) takes the field's focus with it, as Silica's fields
    // do under Qt 5 (Keel's kept it): the next tap on the field opens it again.
    Connections {
        target: Qt.inputMethod

        function onVisibleChanged() {
            var item = app.Window.activeFocusItem
            while (!Qt.inputMethod.visible && item && item.focusOutBehavior === undefined) {
                item = item.parent
            }
            if (!Qt.inputMethod.visible && item) {
                item.focus = false
            }
        }
    }

    // tests/silica.sh, SCROLL=1: the page's view, where it is each frame it moves (60 s),
    // while someone scrolls it.
    // tests/silica.sh, KEYBOARD=1: the page's first text field focused and the keyboard
    // shown, as a tap on it does ("keyboard:").
    Timer {
        id: _keyboard

        function input(item) {
            if (item.placeholderText !== undefined && item.forceActiveFocus !== undefined) {
                return item
            }
            for (var i = 0; i < item.children.length; i++) {
                var found = input(item.children[i])
                if (found) {
                    return found
                }
            }
            return null
        }

        interval: 3000
        onTriggered: {
            var field = pageStack.currentPage ? input(pageStack.currentPage) : null
            if (field) {
                field.forceActiveFocus()
                Qt.inputMethod.show()
            }
            console.log("keyboard:", field !== null, Qt.inputMethod.visible)
        }
    }
    // tests/silica.sh, PERF=1: a page pushed and popped every 1.2 s for 20 s; the frames
    // that took long logged ("perf:"), then a sum.
    FrameAnimation {
        id: _perf

        property int frames
        property int slow
        property real worst
        property real total

        onTriggered: {
            if (elapsedTime < 2) return
            if (elapsedTime > 22) {
                running = false
                console.log("perf: frames", frames, "slow(>20ms)", slow, "worst", Math.round(worst * 1000), "ms", "fps", Math.round(frames / total))
                return
            }
            frames++
            total += frameTime
            worst = Math.max(worst, frameTime)
            if (frameTime > 0.02) {
                slow++
                console.log("perf: slow", Math.round(frameTime * 1000), "ms at +" + Math.round((elapsedTime % 1.2) * 1000), "depth", pageStack.depth)
            }
            if (Math.floor((elapsedTime - frameTime) / 1.2) !== Math.floor(elapsedTime / 1.2)) {
                if (pageStack.depth > 1) pageStack.pop()
                else pageStack.animatorPush(Qt.resolvedUrl("pages/" + (goPerf === "1" ? "AlbumsPage" : goPerf) + ".qml")) // qmllint disable unqualified
            }
        }
    }
    Timer {
        id: _scroll

        property var view
        property var page
        property real last: -1e9
        property int ticks

        function find(item) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i]
                if (c.flick !== undefined && c.pullDownMenu !== undefined) {
                    return c
                }
                var f = find(c)
                if (f) {
                    return f
                }
            }
            return null
        }

        interval: 16
        repeat: true
        onTriggered: {
            if (++ticks > 3750) {
                stop()
            }
            if (pageStack.currentPage && (page !== pageStack.currentPage || !view)) {
                page = pageStack.currentPage
                view = find(page)
                console.log("scroll: view", page.objectName, view, view ? view.contentHeight + " in " + view.height : "")
            }
            if (view && view.contentY + view.contentItem.opacity !== last) {
                last = view.contentY + view.contentItem.opacity
                var m = view.pullDownMenu
                console.log("scroll:", Date.now() % 100000, view.contentY.toFixed(1), view.originY.toFixed(1),
                            view.height, view.dragging, view.flicking, view.boundsBehavior,
                            view.contentItem.opacity.toFixed(2),
                            m ? [m._inactivePosition, m.active, m._activationInhibited, m._activationPermitted].join(" ") : "")
            }
        }
    }

    // tests/silica.sh: the window's picture, saved to goShot 8 s after the start.
    Timer {
        id: _shot

        interval: 8000
        onTriggered: app.grabToImage(function (r) {
            console.log("shot:", r.saveToFile(goShot), goShot) // qmllint disable unqualified
        })
    }
}
