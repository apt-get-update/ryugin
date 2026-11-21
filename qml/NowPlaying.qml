import QtQuick
import QtQuick.Controls.Basic as C
import QtQuick.Effects

// Fullscreen player, after SPlayer-Next, with its four layouts (switched from the top
// bar, remembered): Classic (cover and data left, lyrics right), Full cover (the cover
// fills the left and fades out), Full lyric (lyrics across the window) and Controls (cover
// with its controls left). The queue takes the lyrics' place. The bars fade out when the
// mouse rests for 3 s (SPlayer's immersive mode).
Rectangle {
    id: view
    color: "#14141c"
    clip: true
    readonly property var t: Player.current
    // A phone always has Controls: the cover over its controls, lyrics and queue in its place.
    readonly property string layout: Nav.phone ? "controls" : Player.settings.layout === "apple" ? "controls" : Player.settings.layout // the old name
    readonly property bool hasLyrics: Player.lyrics.length > 0
    property bool showLyrics: !Nav.phone // a phone opens on the cover
    property bool showQueue: false
    readonly property bool lyricVisible: showLyrics && hasLyrics && !showQueue
    // Classic and Controls put the cover in the middle when there is nothing beside it.
    readonly property bool centered: (layout === "classic" || layout === "controls") && !lyricVisible && !showQueue
    readonly property color ink: inkA(0.95) // the cover's colour, very light, like SPlayer
    // The line being sung, word by word: a word goes from dim to full ink over the time it is
    // sung (StyledText, so the line still wraps and centres as one text).
    function sung(words, ms) {
        const hex = function (v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); };
        const rgb = hex(view.ink.r) + hex(view.ink.g) + hex(view.ink.b);
        return words.map(function (w) {
            const end = w.end > w.time ? w.end : w.time + 500;
            const lit = Math.max(0, Math.min(1, (ms - w.time) / (end - w.time)));
            const text = w.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            return '<font color="#' + hex(view.ink.a * (0.35 + 0.65 * lit)) + rgb + '">' + text + "</font>";
        }).join("");
    }
    function inkA(a) { return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, a); }
    readonly property real fs: Math.max(12, Math.min(16, height * 14 / 1080)) // SPlayer's base size
    // ms: on a phone, one panel fades out (a bit quicker, so they never meet), then the other in
    readonly property int swap: 200
    readonly property real leftWidth: Nav.phone ? width : width * 0.45
    readonly property bool wide: Nav.phone && width > height // a phone on its side
    property real topInset: 0 // a phone's notch (Main.qml)
    // Dragged down from the handle or above the cover: Main.qml moves the view by pull,
    // and a long enough drag closes it.
    property real pull: 0
    readonly property bool pulling: pullDrag.active

    // ---- Background, SPlayer-Next's two (the settings' backdrop):
    // "blur": its default, the cover filling the window, 1.5x, blur(45px) saturate(1.2)
    //   (made in Go for this window size), under 50% black;
    // "flow": its fluid one (AMLL), the cover's 32x32 texture bent by a mesh and turning.
    // A new cover is loaded in the hidden image, then faded over the shown one.
    component Backdrop: ShaderEffect {
        id: bd
        property string src
        property real fade: 0
        property var coverA: imgA
        property var coverB: imgB
        property real aspect: width / Math.max(1, height)
        // Opaque: the GPU then skips the pages under the player (a phone's fill rate).
        blending: false
        Image { id: imgA; visible: false; smooth: true }
        Image { id: imgB; visible: false; smooth: true }
        Behavior on fade { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
        Component.onCompleted: imgA.source = src
        onSrcChanged: {
            if (fade < 0.5) {
                imgB.source = src;
                fade = 1;
            } else {
                imgA.source = src;
                fade = 0;
            }
        }
    }
    Backdrop {
        id: blurBackdrop
        objectName: "blurBackdrop"
        anchors.fill: parent
        visible: Player.settings.backdrop !== "flow"
        src: Theme.wash
        fragmentShader: "wash.frag.qsb"
    }
    Backdrop {
        id: flowBackdrop
        objectName: "flowBackdrop"
        anchors.fill: parent
        visible: Player.settings.backdrop === "flow"
        src: Theme.flow
        property real w: width
        property real h: height
        property real time // from 0, by the animation
        NumberAnimation on time {
            from: 0
            to: 100000
            duration: 100000 * 1000
            loops: Animation.Infinite
            paused: !Player.playing || !view.visible || Player.settings.backdrop !== "flow"
        }
        mesh: GridMesh { resolution: Qt.size(100, 100) }
        vertexShader: "flow.vert.qsb"
        fragmentShader: "flow.frag.qsb"
    }
    // The blur is 45 px of the window: a new size asks Go for a new backdrop.
    Timer {
        interval: 400
        running: view.width > 0 && Math.max(view.width, view.height) !== Player.backdropSide
        onTriggered: Player.backdropSide = Math.max(view.width, view.height)
    }

    MouseArea { anchors.fill: parent } // keep clicks off the pages below

    // ---- Immersive: the bars hide when the mouse rests 3 s or leaves; not while it is on a bar.
    property bool idle: false
    readonly property real chrome: Nav.phone || switcher.open || (hover.hovered && (!idle || topHover.hovered || bottomHover.hovered)) ? 1 : 0
    HoverHandler {
        id: hover
        cursorShape: view.chrome ? Qt.ArrowCursor : Qt.BlankCursor
        // Qt also sends hover events when items move under a still mouse: only a real move counts.
        property point last
        onPointChanged: {
            if (point.position === last)
                return;
            last = point.position;
            view.idle = false;
            idleTimer.restart();
        }
    }
    Timer { id: idleTimer; interval: 3000; onTriggered: view.idle = true }

    // A double tap on the cover opens the playlist (two taps within 400 ms).
    component DoubleTap: TapHandler {
        property double last: 0
        onTapped: {
            const now = Date.now();
            if (now - last < 400) {
                view.showQueue = true;
                last = 0;
            } else {
                last = now;
            }
        }
    }

    // A round button on the cover's colours (SPlayer's "cover" buttons).
    component Btn: Item {
        id: b
        property string icon
        property int size: 40
        property int iconSize: 20
        property bool secondary: false
        property bool dim: false
        readonly property bool hovered: area.containsMouse
        signal clicked()
        width: size
        height: size
        opacity: enabled ? (dim ? 0.6 : 1) : 0.35
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: view.inkA(b.secondary ? (area.containsMouse ? 0.2 : 0.12) : (area.containsMouse ? 0.1 : 0))
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Icon { anchors.centerIn: parent; name: b.icon; size: b.iconSize; color: view.ink }
        scale: area.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    // A bordered tag ("STREAMING", "LOSSLESS", "LRC").
    component Tag: Rectangle {
        property alias text: label.text
        width: label.implicitWidth + 12
        height: label.implicitHeight + 10
        radius: 6
        color: "transparent"
        border.color: view.inkA(0.3)
        Text { id: label; anchors.centerIn: parent; color: view.inkA(0.6); font.pixelSize: view.fs }
    }

    // A line under the cover: an icon and a link (artist, album).
    component Link: Row {
        id: link
        property string icon
        property string text
        signal clicked()
        spacing: 6
        Icon { name: link.icon; size: view.fs * 1.2; color: linkArea.containsMouse ? view.ink : view.inkA(0.6); anchors.verticalCenter: parent.verticalCenter }
        Text {
            width: Math.min(implicitWidth, link.width - view.fs * 1.2 - 6)
            text: link.text
            color: linkArea.containsMouse ? view.ink : view.inkA(0.6)
            font.pixelSize: view.fs * 1.2
            elide: Text.ElideRight
            MouseArea { id: linkArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: link.clicked() }
        }
    }

    // The song's data (SPlayer's PlayerData): title (scrolling when too long), tags,
    // artist, album; left aligned or centred.
    component Data: Column {
        id: data
        property bool center: false
        spacing: view.fs * 0.5
        Item {
            id: marquee
            width: data.width
            height: title.implicitHeight
            clip: true
            readonly property bool overflows: title.implicitWidth > width
            Row {
                id: run
                spacing: 48
                x: marquee.overflows ? 0 : (data.center ? (marquee.width - title.implicitWidth) / 2 : 0)
                Text { id: title; text: view.t ? view.t.title : ""; color: view.ink; font.pixelSize: view.fs * 2; font.weight: Font.DemiBold }
                Text { visible: marquee.overflows; text: title.text; color: view.ink; font: title.font }
                SequentialAnimation on x {
                    running: marquee.overflows && view.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2500 }
                    NumberAnimation { from: 0; to: -(title.implicitWidth + run.spacing); duration: (title.implicitWidth + run.spacing) * 30 }
                }
            }
        }
        Row {
            objectName: "tags"
            visible: Player.settings.tags // an option in the settings
            anchors.horizontalCenter: data.center ? parent.horizontalCenter : undefined
            spacing: 6
            topPadding: 4
            bottomPadding: 4
            Tag { text: "Streaming" }
            Tag { text: view.t ? Api.quality(view.t) : ""; visible: text !== "" }
            Tag { text: !view.hasLyrics ? "No-lrc" : Player.lyricsSynced ? "Lrc" : "Txt" }
        }
        Link {
            anchors.horizontalCenter: data.center ? parent.horizontalCenter : undefined
            width: data.width
            icon: "mic"
            text: view.t ? view.t.artist : ""
            onClicked: if (view.t) { Nav.lyrics = false; Nav.openArtist(view.t.artistId, view.t.artist); }
        }
        Link {
            anchors.horizontalCenter: data.center ? parent.horizontalCenter : undefined
            width: data.width
            visible: !!view.t && view.t.album !== ""
            icon: "disc-3"
            text: view.t ? view.t.album : ""
            onClicked: if (view.t) { Nav.lyrics = false; Nav.openAlbum(view.t.albumId); }
        }
    }

    // ---- Full cover: the cover fills the left 60% and fades out to the right; the bars
    // get dark masks so they stay readable.
    Image {
        visible: view.layout === "fullCover"
        width: parent.width * 0.6
        height: parent.height
        source: view.t && visible ? Api.cover(view.t.cover, 1200) : ""
        sourceSize: Qt.size(1200, 1200)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: visible
        layer.effect: ShaderEffect { fragmentShader: "fade.frag.qsb" }
    }
    Rectangle {
        visible: view.layout === "fullCover"
        width: parent.width
        height: 80
        opacity: view.chrome
        Behavior on opacity { NumberAnimation { duration: 400 } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.27) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.1) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }
    Rectangle {
        visible: view.layout === "fullCover"
        anchors.bottom: parent.bottom
        width: parent.width
        height: 192
        opacity: view.chrome
        Behavior on opacity { NumberAnimation { duration: 400 } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.1) }
            GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.27) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
        }
    }

    // ---- Middle
    Item {
        id: middle
        y: 56 + view.topInset
        width: parent.width
        height: parent.height - y - (view.layout === "controls" ? 64 : 80)

        // Classic: the cover, the data under it.
        Item {
            id: classic
            visible: view.layout === "classic"
            width: view.leftWidth
            height: parent.height
            x: view.centered ? (view.width - width) / 2 : 0
            Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
            Item {
                width: Math.max(200, Math.min((classic.width - 96) * 0.85, view.height * 0.5))
                height: width
                DoubleTap {}
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -view.height * 0.11
                Shadow {
                    anchors.fill: classicCover
                    radius: classicCover.radius
                    blur: 20
                    spread: 10
                    color: Qt.rgba(0, 0, 0, 0.1)
                    scale: classicCover.scale
                }
                Cover {
                    id: classicCover
                    anchors.fill: parent
                    size: 1000
                    radius: 32
                    coverId: view.t ? view.t.cover : ""
                    scale: Player.playing ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.56 } }
                }
                Data {
                    anchors.top: parent.bottom
                    anchors.topMargin: 24
                    x: 8
                    width: parent.width - 16
                }
            }
        }

        // Controls: the cover with its controls under it (beside it on a phone on its side).
        Item {
            id: controls
            // On a phone the playlist and lyrics take its place: it fades out first, and
            // back in once they are gone (never both at once).
            opacity: Nav.phone && !view.centered ? 0 : 1
            visible: view.layout === "controls" && opacity > 0
            Behavior on opacity { id: ctlFade; SequentialAnimation {
                PauseAnimation { duration: Nav.phone && ctlFade.targetValue > 0 ? view.swap : 0 }
                NumberAnimation { duration: ctlFade.targetValue > 0 ? view.swap : view.swap * 0.8; easing.type: Easing.InOutQuad } } }
            width: view.leftWidth
            height: parent.height
            x: view.centered ? (view.width - width) / 2 : 0
            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
            readonly property real side: view.wide ? Math.min(height - 32, view.width * 0.42)
                                       : Nav.phone ? view.width - 48 : Math.min(view.height * 0.5, view.width * 0.38)
            readonly property real panel: view.wide ? Math.min(view.width - 48 - side - 40, 480) : side
            Grid {
                id: controlsGrid
                objectName: "controlsGrid"
                anchors.centerIn: parent
                columns: view.wide ? 2 : 1
                columnSpacing: 40
                rowSpacing: view.height * 0.04
                verticalItemAlignment: Grid.AlignVCenter
                Item {
                    objectName: "controlsCoverBox"
                    width: controls.side
                    height: width
                    DoubleTap {}
                    Shadow { anchors.fill: controlsCover; radius: controlsCover.radius; blur: 40; offset.y: 16; color: Qt.rgba(0, 0, 0, 0.3) }
                    Cover { id: controlsCover; anchors.fill: parent; size: 1000; radius: 12; coverId: view.t ? view.t.cover : "" }
                }
                Column {
                    width: controls.panel
                    spacing: view.height * 0.016
                    Item { // title, artist, favourite
                        width: parent.width
                        height: info.height
                        Column {
                            id: info
                            width: parent.width - 44
                            spacing: 2
                            Text { width: parent.width; text: view.t ? view.t.title : ""; color: view.ink; font.pixelSize: view.fs * 1.4; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { width: parent.width; text: view.t ? view.t.artist : ""; color: view.inkA(0.55); font.pixelSize: view.fs * 1.2; elide: Text.ElideRight }
                        }
                        Btn {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            size: 34
                            iconSize: 17
                            secondary: true
                            icon: view.t && view.t.starred ? "heart-fill" : "heart"
                            onClicked: Player.toggleStar()
                        }
                    }
                    Column { // progress
                        width: parent.width
                        spacing: 4
                        WhiteSlider {
                            id: controlsProgress
                            width: parent.width
                            from: 0
                            to: Math.max(1, Player.duration)
                            Binding on value { value: Player.shownPosition; when: !controlsProgress.pressed; restoreMode: Binding.RestoreNone }
                            onPressedChanged: if (!pressed) Player.seek(value)
                        }
                        Item {
                            width: parent.width
                            height: 14
                            Text { text: Theme.time(controlsProgress.value / 1000); color: view.inkA(0.5); font.pixelSize: 11 }
                            Text { anchors.right: parent.right; text: "-" + Theme.time((Player.duration - controlsProgress.value) / 1000); color: view.inkA(0.5); font.pixelSize: 11 }
                        }
                    }
                    Item { // controls
                        width: parent.width
                        height: view.height * 0.075
                        readonly property real big: Math.max(28, view.height * 0.05)
                        Glyph { name: "shuffle"; size: parent.big * 0.5; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.shuffleRest() }
                        Row {
                            anchors.centerIn: parent
                            spacing: parent.width * 0.09
                            Glyph { name: "skip-back-fill"; size: parent.parent.big * 0.8; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.previous() }
                            Glyph { name: Player.playing ? "pause-fill" : "play-fill"; size: parent.parent.big; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.toggle() }
                            Glyph { name: "skip-forward-fill"; size: parent.parent.big * 0.8; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.next() }
                        }
                        Glyph {
                            readonly property bool once: Player.repeat === "one"
                            name: once ? "repeat-1" : "repeat"
                            size: parent.big * 0.5
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            dim: Player.repeat === "off"
                            onClicked: Player.cycleRepeat()
                        }
                    }
                    Row { // volume
                        width: parent.width
                        spacing: 10
                        Icon { name: "volume-x"; size: 16; color: view.inkA(0.5); anchors.verticalCenter: parent.verticalCenter }
                        WhiteSlider {
                            width: parent.width - 52
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            value: Player.settings.volume
                            onMoved: Player.setVolume(value)
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: function (e) { Player.wheelVolume(e); } }
                        }
                        Icon { name: "volume-2"; size: 16; color: view.inkA(0.5); anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // Lyrics; in Full cover and Full lyric with the song's data on top, and always
        // there (a quiet "No lyrics" when the song has none).
        Item {
            id: lyricPanel
            readonly property bool withData: view.layout === "fullCover" || view.layout === "fullLyric"
            x: Nav.phone ? 24 : view.layout === "fullLyric" ? 80 : view.layout === "fullCover" ? view.width / 2 : view.leftWidth
            width: Nav.phone ? view.width - 48 : (view.layout === "fullLyric" ? view.width - 80 : view.width - x) - 80
            height: parent.height
            opacity: (withData ? !view.showQueue : view.lyricVisible) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { id: lyricFade; SequentialAnimation {
                PauseAnimation { duration: Nav.phone && lyricFade.targetValue > 0 ? view.swap : 0 }
                NumberAnimation { duration: !Nav.phone ? 600 : lyricFade.targetValue > 0 ? view.swap : view.swap * 0.8; easing.type: Easing.InOutCubic } } }

            Data {
                id: panelData
                visible: lyricPanel.withData
                center: view.layout === "fullLyric"
                y: 8
                width: parent.width
            }
            Text {
                visible: lyricPanel.withData && !view.hasLyrics
                anchors.centerIn: lines
                text: "No lyrics"
                color: view.inkA(0.3)
                font.pixelSize: view.fs * 1.2
            }
            ListView {
                id: lines
                objectName: "lyricLines"
                y: lyricPanel.withData ? panelData.height + 32 : 0
                width: parent.width
                height: parent.height - y
                clip: true
                visible: view.hasLyrics && view.showLyrics
                model: Player.lyrics
                currentIndex: Player.lyricIndex
                highlightRangeMode: Player.lyricsSynced ? ListView.ApplyRange : ListView.NoHighlightRange
                preferredHighlightBegin: height * 0.3
                preferredHighlightEnd: height * 0.4
                highlightMoveDuration: 650
                highlightMoveVelocity: -1
                spacing: view.fs * 1.6
                header: Item { width: 1; height: Player.lyricsSynced ? lines.height * 0.3 : 40 }
                footer: Item { width: 1; height: Player.lyricsSynced ? lines.height * 0.6 : 40 }
                // The song's time at each frame (the player reports it only now and then),
                // so sung words light up smoothly.
                property real ms: 0
                property double stamp: 0
                Connections {
                    target: Player
                    function onPositionChanged() { lines.stamp = Date.now(); lines.ms = Player.position; }
                }
                FrameAnimation {
                    running: lines.visible && Player.playing
                    onTriggered: lines.ms = Player.position + Math.min(1000, Date.now() - lines.stamp)
                }
                delegate: Text {
                    required property var modelData
                    required property int index
                    readonly property bool now: index === Player.lyricIndex
                    readonly property int gap: Math.abs(index - Player.lyricIndex)
                    readonly property bool byWord: now && !!modelData.words && modelData.words.length > 0
                    width: lines.width
                    textFormat: byWord ? Text.StyledText : Text.PlainText
                    text: modelData.text === "" ? "• • •" : byWord ? view.sung(modelData.words, lines.ms) : modelData.text
                    wrapMode: Text.WordWrap
                    horizontalAlignment: view.layout === "fullLyric" ? Text.AlignHCenter : Text.AlignLeft
                    color: view.ink
                    opacity: !Player.lyricsSynced ? 0.85 : now ? 1 : Math.max(0.15, 0.4 - gap * 0.05)
                    font.pixelSize: Nav.phone ? 22 : Math.max(26, view.height * 0.042)
                    font.weight: Font.Bold
                    scale: now ? 1 : 0.95
                    transformOrigin: view.layout === "fullLyric" ? Item.Center : Item.Left
                    Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 450 } }
                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.time >= 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Player.seek(modelData.time)
                    }
                }
            }
        }

        // Queue (SPlayer's QueuePanel)
        Item {
            id: queue
            objectName: "queuePanel"
            x: Nav.phone ? 0 : (view.layout === "fullCover" || view.layout === "fullLyric" ? view.width / 2 : view.leftWidth) + 16
            // On a phone on its side, up into the top bar and down to the bottom: room for rows.
            y: view.wide ? -40 : 24
            width: view.width - x
            height: view.wide ? parent.height + 40 + 64 - 8 : parent.height - 48
            opacity: view.showQueue ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { id: queueFade; SequentialAnimation {
                PauseAnimation { duration: Nav.phone && queueFade.targetValue > 0 ? view.swap : 0 }
                NumberAnimation { duration: !Nav.phone ? 600 : queueFade.targetValue > 0 ? view.swap : view.swap * 0.8; easing.type: Easing.InOutCubic } } }
            // Sailfish's remorse: the bin clears after a few seconds; a tap on the bar cancels.
            property bool clearing: false
            Timer { id: remorse; interval: 4000; onTriggered: { queue.clearing = false; Player.clear(); } }

            Column {
                x: 14
                spacing: 4
                Text { text: "Playlist"; color: view.ink; font.pixelSize: 24; font.weight: Font.DemiBold }
                Text { text: Player.queue.length + " songs"; color: view.inkA(0.55); font.pixelSize: 14 }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Nav.phone ? 16 : 80
                spacing: 12
                Btn { icon: "locate"; secondary: true; enabled: Player.queue.length > 0; onClicked: upNext.positionViewAtIndex(Player.index, ListView.Center) }
                Btn {
                    objectName: "clearQueue"
                    icon: "trash-2"
                    secondary: true
                    enabled: Player.queue.length > 0 && !queue.clearing
                    onClicked: { queue.clearing = true; remorse.restart(); }
                }
                Btn { icon: "x"; secondary: true; onClicked: view.showQueue = false }
            }

            Rectangle {
                objectName: "remorse"
                visible: queue.clearing
                z: 1
                x: 8
                y: 72
                width: parent.width - (Nav.phone ? 16 : 88)
                height: 56
                radius: 12
                color: view.inkA(0.16)
                Text { anchors.centerIn: parent; text: "Clearing playlist · tap to cancel"; color: view.ink; font.pixelSize: 15 }
                Rectangle { // the time left
                    anchors.bottom: parent.bottom
                    x: 12
                    height: 3
                    radius: 1.5
                    color: view.ink
                    NumberAnimation on width { running: queue.clearing; from: (parent.width - 24); to: 0; duration: remorse.interval }
                }
                MouseArea { anchors.fill: parent; onClicked: { remorse.stop(); queue.clearing = false; } }
            }
            ListView {
                id: upNext
                y: 72
                width: parent.width
                height: parent.height - 72
                clip: true
                C.ScrollBar.vertical: Scroller {}
                model: Player.queue
                topMargin: 16
                bottomMargin: 16
                onVisibleChanged: if (visible) positionViewAtIndex(Player.index, ListView.Center)
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool now: index === Player.index
                    width: upNext.width - 80
                    height: 72
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        radius: 12
                        color: view.inkA(row.now ? 0.14 : rowArea.containsMouse ? 0.08 : 0)
                        Rectangle { visible: row.now; x: 0; y: 12; width: 2; height: parent.height - 24; radius: 1; color: view.ink }
                        MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Player.jump(row.index) }
                        Cover { id: c; x: 10; width: 48; height: 48; size: 96; radius: 8; anchors.verticalCenter: parent.verticalCenter; coverId: row.modelData.cover }
                        Column {
                            anchors.left: c.right
                            anchors.leftMargin: 12
                            anchors.right: remove.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { width: parent.width; text: row.modelData.title; color: view.ink; font.pixelSize: 16; font.weight: Font.Medium; elide: Text.ElideRight }
                            Text { width: parent.width; text: row.modelData.artist; color: view.inkA(row.now ? 0.7 : 0.55); font.pixelSize: 14; elide: Text.ElideRight }
                        }
                        Btn {
                            id: remove
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            size: 28
                            iconSize: 14
                            icon: "x"
                            opacity: rowArea.containsMouse || hovered ? 1 : 0
                            onClicked: Player.removeAt(row.index)
                        }
                    }
                }
            }
        }
    }

    // ---- Top bar: lyrics toggle (Classic), collapse handle (Controls), layouts, fullscreen
    Item {
        id: topBar
        y: view.topInset
        width: parent.width
        height: 56
        z: 2
        opacity: view.chrome
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        HoverHandler { id: topHover }
        Btn {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: view.layout === "classic"
            icon: "text-quote"
            enabled: view.hasLyrics
            dim: !view.lyricVisible
            onClicked: {
                if (view.showQueue) {
                    view.showQueue = false;
                    view.showLyrics = true;
                } else {
                    view.showLyrics = !view.showLyrics;
                }
            }
        }
        Rectangle {
            visible: view.layout === "controls"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            width: 88
            height: 28
            radius: 14
            color: handle.hovered ? view.inkA(0.1) : "transparent"
            Rectangle { anchors.centerIn: parent; width: 56; height: 5; radius: 3; color: view.inkA(0.4) }
            // Handlers, not a MouseArea: a drag from here reaches the pull zone under the bar.
            HoverHandler { id: handle; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Nav.lyrics = false }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Btn { objectName: "layoutButton"; visible: !Nav.phone; icon: "layout-template"; onClicked: switcher.open = !switcher.open }
            Btn {
                visible: !Nav.phone
                readonly property var win: view.Window.window
                icon: win && win.visibility === Window.FullScreen ? "minimize" : "maximize"
                onClicked: if (win) (win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen())
            }
        }
    }

    // ---- Layout switcher (SPlayer's popover: a small drawing of each layout)
    MouseArea { // a click outside closes it
        anchors.fill: parent
        z: 3
        visible: switcher.open
        onClicked: switcher.open = false
    }
    Rectangle {
        id: switcher
        objectName: "switcher"
        property bool open: false
        z: 4
        anchors.right: parent.right
        anchors.rightMargin: 64
        y: 56
        width: grid.width + 24
        height: backdrops.y + backdrops.height + 12
        radius: 16
        color: "transparent"
        opacity: open ? 1 : 0
        visible: opacity > 0
        scale: open ? 1 : 0.95
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }
        // Frosted glass: the backdrop and the page behind, blurred, then tinted.
        Item {
            id: frost
            anchors.fill: parent
            visible: false
            ShaderEffectSource {
                anchors.fill: parent
                live: switcher.visible
                sourceItem: flowBackdrop.visible ? flowBackdrop : blurBackdrop
                sourceRect: Qt.rect(switcher.x, switcher.y, switcher.width, switcher.height)
            }
            ShaderEffectSource {
                anchors.fill: parent
                live: switcher.visible
                sourceItem: middle
                sourceRect: Qt.rect(switcher.x - middle.x, switcher.y - middle.y, switcher.width, switcher.height)
            }
        }
        Rectangle {
            id: frostMask
            anchors.fill: parent
            radius: switcher.radius
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            objectName: "frost"
            anchors.fill: parent
            source: frost
            blurEnabled: true
            blur: 1
            blurMax: 48
            maskEnabled: true
            maskSource: frostMask
        }
        Rectangle {
            anchors.fill: parent
            radius: switcher.radius
            color: Qt.rgba(0.08, 0.07, 0.08, 0.5)
            border.color: view.inkA(0.12)
        }
        MouseArea { anchors.fill: parent } // clicks inside stay inside
        Text { id: heading; x: 14; y: 12; text: "Layout"; color: view.ink; font.pixelSize: 14; font.weight: Font.Medium }
        Grid {
            id: grid
            x: 12
            y: heading.y + heading.height + 10
            columns: 2
            spacing: 8
            Repeater {
                model: [
                    { id: "classic", label: "Classic" },
                    { id: "fullCover", label: "Full cover" },
                    { id: "fullLyric", label: "Full lyric" },
                    { id: "controls", label: "Controls" }
                ]
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool chosen: view.layout === modelData.id
                    objectName: "layout-" + modelData.id
                    width: 124
                    height: preview.height + label.height + 18
                    radius: 12
                    color: view.inkA(chosen ? 0.14 : optionArea.containsMouse ? 0.08 : 0)
                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Player.settings.layout = option.modelData.id;
                            switcher.open = false;
                        }
                    }
                    Rectangle { // the drawing
                        id: preview
                        x: 6
                        y: 6
                        width: 112
                        height: 70
                        radius: 8
                        clip: true
                        color: view.inkA(0.08)
                        border.color: view.inkA(option.chosen ? 0.6 : 0.15)
                        readonly property string kind: option.modelData.id
                        Rectangle { // classic: a cover
                            visible: preview.kind === "classic"
                            x: parent.width * 0.12; width: parent.width * 0.3; height: width; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: view.inkA(0.45)
                        }
                        Rectangle { // full cover: fading to the right
                            visible: preview.kind === "fullCover"
                            width: parent.width * 0.6; height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.4; color: view.inkA(0.45) }
                                GradientStop { position: 1; color: view.inkA(0) }
                            }
                        }
                        Column { // controls: a cover with two lines
                            visible: preview.kind === "controls"
                            x: parent.width * 0.14; width: parent.width * 0.24
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Rectangle { width: parent.width; height: width; radius: 2; color: view.inkA(0.45) }
                            Rectangle { width: parent.width; height: 2; radius: 1; color: view.inkA(0.3) }
                            Rectangle { width: parent.width * 0.6; height: 2; radius: 1; color: view.inkA(0.3); anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        Column { // the lyric lines
                            x: preview.kind === "fullLyric" ? parent.width * 0.1 : parent.width * 0.54
                            width: preview.kind === "fullLyric" ? parent.width * 0.8 : parent.width * 0.36
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Rectangle { width: parent.width * 0.7; height: 4; radius: 2; color: view.inkA(0.3) }
                            Rectangle { width: parent.width; height: 4; radius: 2; color: view.inkA(0.7) }
                            Rectangle { width: parent.width * 0.85; height: 4; radius: 2; color: view.inkA(0.3) }
                        }
                    }
                    Text {
                        id: label
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: preview.bottom
                        anchors.topMargin: 6
                        text: option.modelData.label
                        color: option.chosen ? view.ink : view.inkA(0.6)
                        font.pixelSize: 12
                    }
                }
            }
        }
        Text { id: bgHeading; x: 14; y: grid.y + grid.height + 14; text: "Background"; color: view.ink; font.pixelSize: 14; font.weight: Font.Medium }
        Row {
            id: backdrops
            x: 12
            y: bgHeading.y + bgHeading.height + 8
            spacing: 8
            Repeater {
                model: [
                    { id: "blur", label: "Blur" },
                    { id: "flow", label: "Flow" }
                ]
                delegate: Rectangle {
                    id: bgOption
                    required property var modelData
                    readonly property bool chosen: (Player.settings.backdrop === "flow") === (modelData.id === "flow")
                    objectName: "backdrop-" + modelData.id
                    width: 124
                    height: 32
                    radius: 16
                    color: view.inkA(chosen ? 0.14 : bgArea.containsMouse ? 0.08 : 0)
                    border.color: view.inkA(chosen ? 0.6 : 0.15)
                    Text { anchors.centerIn: parent; text: bgOption.modelData.label; color: bgOption.chosen ? view.ink : view.inkA(0.6); font.pixelSize: 12 }
                    MouseArea {
                        id: bgArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Player.settings.backdrop = bgOption.modelData.id
                    }
                }
            }
        }
    }

    // ---- Bottom bar (Classic, Full cover, Full lyric)
    Item {
        id: bottomBar
        visible: view.layout !== "controls" && opacity > 0
        anchors.bottom: parent.bottom
        width: parent.width
        height: 80
        z: 2
        opacity: view.chrome
        Behavior on opacity { NumberAnimation { duration: 400 } }
        HoverHandler { id: bottomHover }

        Row { // left: collapse, favourite
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Btn { icon: "chevron-down"; size: 44; iconSize: 22; onClicked: Nav.lyrics = false }
            Btn {
                size: 44
                iconSize: 22
                enabled: !!view.t
                icon: view.t && view.t.starred ? "heart-fill" : "heart"
                onClicked: Player.toggleStar()
            }
        }

        Column { // middle: controls and progress
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(360, Math.min(view.width * 0.35, 480))
            spacing: 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Btn { icon: "shuffle"; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.shuffleRest() }
                Btn { icon: "skip-back"; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.previous() }
                Btn { icon: Player.playing ? "pause" : "play"; secondary: true; size: 44; iconSize: 22; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.toggle() }
                Btn { icon: "skip-forward"; anchors.verticalCenter: parent.verticalCenter; onClicked: Player.next() }
                Btn {
                    readonly property bool once: Player.repeat === "one"
                    icon: once ? "repeat-1" : "repeat"
                    dim: Player.repeat === "off"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: Player.cycleRepeat()
                }
            }
            Item {
                width: parent.width
                height: 20
                property bool remaining: true
                Text {
                    id: elapsed
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: parent.remaining ? "-" + Theme.time((Player.duration - progress.value) / 1000) : Theme.time(progress.value / 1000)
                    color: view.inkA(0.5)
                    font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.remaining = !parent.parent.remaining }
                }
                WhiteSlider {
                    id: progress
                    objectName: "progress"
                    anchors.left: elapsed.right
                    anchors.right: total.left
                    anchors.margins: 6
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: Math.max(1, Player.duration)
                    // Follow the song, except while dragged; seek on release.
                    Binding on value { value: Player.shownPosition; when: !progress.pressed; restoreMode: Binding.RestoreNone }
                    onPressedChanged: if (!pressed) Player.seek(value)
                }
                Text {
                    id: total
                    width: 44
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Theme.time(Player.duration / 1000)
                    color: view.inkA(0.5)
                    font.pixelSize: 12
                }
            }
        }

        Row { // right: volume, lyrics (Full cover, Full lyric), queue
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Item {
                width: volumeRow.width
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                HoverHandler { id: volumeHover }
                Row {
                    id: volumeRow
                    height: parent.height
                    spacing: 4
                    WhiteSlider {
                        width: volumeHover.hovered ? 96 : 0
                        visible: width > 4
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on width { NumberAnimation { duration: 200 } }
                        from: 0
                        to: 1
                        value: Player.settings.volume
                        onMoved: Player.setVolume(value)
                    }
                    Btn {
                        property real before: 0.8
                        icon: Player.settings.volume === 0 ? "volume-x" : Player.settings.volume < 0.5 ? "volume-1" : "volume-2"
                        onClicked: {
                            if (Player.settings.volume > 0) {
                                before = Player.settings.volume;
                                Player.setVolume(0);
                            } else {
                                Player.setVolume(before);
                            }
                        }
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; onWheel: function (e) { Player.wheelVolume(e); } }
            }
            Btn {
                visible: view.layout !== "classic"
                icon: "text-quote"
                enabled: view.hasLyrics
                dim: !view.showLyrics
                onClicked: view.showLyrics = !view.showLyrics
            }
            Btn { icon: "list-music"; dim: !view.showQueue; onClicked: view.showQueue = !view.showQueue }
        }
    }

    // ---- Pull down to close: the top bar, and on a phone upright the space above the cover.
    Item {
        objectName: "pullZone"
        z: 1 // under the top bar (z 2): its buttons keep their clicks
        width: parent.width
        height: view.layout === "controls" && !view.wide && controls.visible && view.centered
                ? middle.y + (middle.height - controlsGrid.height) / 2 : topBar.y + topBar.height
        DragHandler {
            id: pullDrag
            target: null
            xAxis.enabled: false
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            // From where the drag starts: no jump by the drag threshold under the finger.
            property real from: NaN
            onTranslationChanged: if (active) {
                if (isNaN(from))
                    from = translation.y;
                view.pull = Math.max(0, translation.y - from);
            }
            // Far enough, or flicked down: it closes; otherwise it springs back.
            onActiveChanged: if (!active) {
                if (view.pull > Math.min(160, view.height * 0.2) || (view.pull > 24 && centroid.velocity.y > 800))
                    Nav.lyrics = false;
                view.pull = 0;
                from = NaN;
            }
        }
    }

    // ---- Controls: lyrics and queue toggles, bottom right
    Row {
        visible: view.layout === "controls"
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 16
        opacity: view.chrome
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Btn {
            objectName: "lyricsToggle"
            icon: "mic-vocal"
            size: 44
            iconSize: 22
            secondary: true
            dim: !view.lyricVisible
            enabled: view.hasLyrics
            onClicked: { view.showQueue = false; view.showLyrics = !view.lyricVisible; }
        }
        Btn { icon: "list-music"; size: 44; iconSize: 22; secondary: true; dim: !view.showQueue; onClicked: view.showQueue = !view.showQueue }
    }
}
