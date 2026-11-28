pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// Settings as a KDE dialog: its pages at the left (one shown at a time), a form at the
// right (names right-aligned before their controls), Close at the bottom. Connect to Navidrome (the password becomes
// a salted token; it is not stored), then the options. A phone: one column, in a popup.
Item {
    id: page
    property string scanError: "" // a scan refused (not an admin)
    property string section: "navidrome" // the page shown (a phone: all, one column)
    // Home's rows: shown or not, moved up or down (Nav.layout keeps them).
    function showRow(key, on) {
        const hidden = Nav.layout.homeHidden.split(" ").filter(function (k) { return k && k !== key; });
        Nav.layout.homeHidden = (on ? hidden : hidden.concat([key])).join(" ");
    }
    // Home's rows in order (a row no more known, as Favorites, left out).
    function homeOrder() {
        return Nav.layout.homeOrder.split(" ").filter(function (k) { return Nav.homeRows[k]; });
    }
    function moveRow(key, by) {
        moveTo(key, homeOrder().indexOf(key) + by);
    }
    function moveTo(key, to) {
        const order = homeOrder();
        const i = order.indexOf(key);
        if (i < 0)
            return;
        order.splice(i, 1);
        order.splice(Math.max(0, Math.min(order.length, to)), 0, key);
        Nav.layout.homeOrder = order.join(" ");
    }
    implicitWidth: Nav.phone ? Math.min(480, (Window.width || 504) - 24) : 760
    implicitHeight: Nav.phone ? Math.min(form.implicitHeight + 2 * pad + buttons.height, (Window.height || 900) - 24) : 560
    readonly property int pad: Nav.phone ? 18 : 26
    readonly property int labelWidth: Nav.phone ? 0 : 150 // a phone: names above their controls
    readonly property int fieldWidth: form.width - (labelWidth ? labelWidth + 14 : 0)
    // Close (Main.qml closes the dialog or the popup): a phone has no Escape.
    signal closeRequested()
    // The bytes the cache holds: { songs, covers }; null until Go answers.
    property var used: null
    function showUsed(sizes) { page.used = sizes; }
    function usedText(kind) { return page.used ? /*% "%1 used" */ qsTrId("ryugin-la-used").arg(Theme.size(page.used[kind])) : ""; }
    onVisibleChanged: if (visible) Api.cache({}, showUsed)
    Component.onCompleted: Api.cache({}, showUsed)

    // A group's name, small and gold.
    component Heading: Text {
        topPadding: 12
        bottomPadding: 2
        color: Theme.gold
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
    }
    // One page of the form (a phone: all of them, one under the other).
    component Group: Column {
        property string key
        width: parent ? parent.width : 0
        spacing: 10
        visible: Nav.phone || page.section === key
    }
    // One row of the form: its name right-aligned at the left, its control(s) at the right,
    // what it does under them.
    component Option: Item {
        id: o
        property string title
        property string desc
        default property alias controls: side.data
        width: parent ? parent.width : 0
        height: side.y + Math.max(28, side.implicitHeight, page.labelWidth ? label.implicitHeight : 0) + (o.desc !== "" ? hint.implicitHeight + 4 : 0)
        Text {
            id: label
            width: page.labelWidth ? page.labelWidth : parent.width
            height: page.labelWidth ? Math.max(28, side.implicitHeight, implicitHeight) : implicitHeight
            horizontalAlignment: page.labelWidth ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap // a long name (a translation) on two lines, in its column
            text: o.title !== "" && page.labelWidth ? /*% "%1:" */ qsTrId("ryugin-la-label").arg(o.title) : o.title
            color: Theme.text
            font.pixelSize: 12
        }
        Row {
            id: side
            x: page.labelWidth ? page.labelWidth + 14 : 0
            y: page.labelWidth || o.title === "" ? 0 : label.height + 4
            height: Math.max(28, implicitHeight)
            spacing: 8
        }
        Text {
            id: hint
            x: side.x
            y: side.y + side.height + 4
            width: parent.width - x
            text: o.desc
            visible: o.desc !== ""
            color: Theme.faint
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }

    // A phone's popup: a card behind it.
    Rectangle {
        visible: Nav.phone
        anchors.fill: parent
        radius: Theme.radiusXl
        color: Theme.popup
        border.color: Theme.border
    }

    // The pages, at the left; the one shown is lit.
    Rectangle {
        id: pagesList
        visible: !Nav.phone
        width: visible ? 170 : 0
        height: parent.height
        color: Theme.panel
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
        Column {
            x: 8
            y: 12
            width: parent.width - 16
            spacing: 2
            Repeater {
                model: [
                    { label: "Navidrome", icon: "server", key: "navidrome" },
                    { label: /*% "Look" */ qsTrId("ryugin-he-look"), icon: "sparkles", key: "look" },
                    { label: /*% "Home" */ qsTrId("ryugin-he-home"), icon: "house", key: "home" },
                    { label: /*% "Cache" */ qsTrId("ryugin-he-cache"), icon: "history", key: "cache" },
                    { label: /*% "About" */ qsTrId("ryugin-he-about"), icon: "info", key: "about" }
                ]
                delegate: Rectangle {
                    id: cat
                    required property var modelData
                    width: parent.width
                    height: 30
                    radius: 4
                    objectName: "page-" + cat.modelData.key
                    readonly property bool active: page.section === cat.modelData.key
                    color: Theme.lit(active, catArea.containsMouse)
                    Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: cat.modelData.icon; size: 16; color: cat.active ? Theme.gold : Theme.dim }
                    Text { x: 34; anchors.verticalCenter: parent.verticalCenter; text: cat.modelData.label; color: Theme.text; font.pixelSize: 12 }
                    MouseArea { id: catArea; anchors.fill: parent; hoverEnabled: true; onClicked: { page.section = cat.modelData.key; flick.contentY = 0; } }
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.left: pagesList.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: buttons.top
        clip: true
        contentHeight: form.implicitHeight + 2 * page.pad
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: Scroller {}
        Column {
            id: form
            x: page.pad
            y: page.pad
            width: parent.width - 2 * page.pad
            spacing: 10
            Group {
                key: "navidrome"
                Heading { text: "Navidrome" }
                Option {
                    title: /*% "Server" */ qsTrId("ryugin-la-server")
                    desc: Api.configured ? "" : /*% "Your Navidrome server" */ qsTrId("ryugin-la-your_navidrome_server")
                    Field { id: url; width: page.fieldWidth; placeholderText: "https://music.example.org"; text: Api.settings.url; onAccepted: user.forceActiveFocus() }
                }
                Option {
                    title: /*% "User" */ qsTrId("ryugin-la-user")
                    Field { id: user; width: Math.min(260, page.fieldWidth); text: Api.settings.user; onAccepted: pass.forceActiveFocus() }
                }
                Option {
                    title: /*% "Password" */ qsTrId("ryugin-he-password")
                    desc: Api.configured ? /*% "Only to change it" */ qsTrId("ryugin-de-only_to_change_it") : ""
                    Field { id: pass; width: Math.min(260, page.fieldWidth); echoMode: TextInput.Password; onAccepted: connect.clicked() }
                }
                Option {
                    TextButton {
                        id: connect
                        text: /*% "Connect" */ qsTrId("ryugin-bt-connect")
                        onClicked: Api.login(url.text, user.text, pass.text, function (err) {
                            if (!err) { pass.text = ""; Nav.home(); }
                        })
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: page.fieldWidth - connect.width - 8
                        wrapMode: Text.WordWrap
                        text: Api.online ? "● " + /*% "Connected" */ qsTrId("ryugin-la-connected") : Api.error
                        color: Api.online ? Theme.gold : Theme.dim
                        font.pixelSize: 11
                    }
                }

                Option {
                    objectName: "scan"
                    visible: Api.configured
                    title: /*% "Library" */ qsTrId("ryugin-la-library")
                    desc: Api.scanning
                          ? /*% "Navidrome is scanning your music…" */ qsTrId("ryugin-la-navidrome_scanning")
                          : page.scanError || (Api.songTotal ? /*% "%n songs" */ qsTrId("ryugin-la-n_songs", Api.songTotal) + " · " : "")
                            + /*% "Find new and changed music" */ qsTrId("ryugin-la-find_new_and_changed_music")
                    TextButton {
                        objectName: "scanButton"
                        icon: "refresh-cw"
                        text: Api.scanning ? /*% "Scanning…" */ qsTrId("ryugin-la-scanning") : /*% "Scan" */ qsTrId("ryugin-la-scan")
                        enabled: !Api.scanning
                        onClicked: Api.startScan(function (err) { page.scanError = err || ""; })
                    }
                }
                Option {
                    objectName: "hiddenAlbums"
                    visible: Api.configured && Object.keys(Api.hidden).length > 0
                    title: /*% "Hidden albums" */ qsTrId("ryugin-he-hidden_albums")
                    desc: /*% "Left out of Home, the lists, the radio and karaoke (1 star on Navidrome)" */ qsTrId("ryugin-de-hidden_albums")
                    Column {
                        spacing: 2
                        Repeater {
                            model: Object.keys(Api.hidden).map(function (k) { return Api.hidden[k]; }).sort(function (a, b) { return a.title.localeCompare(b.title); })
                            delegate: Row {
                                id: hiddenRow
                                required property var modelData
                                spacing: 6
                                IconButton {
                                    icon: "eye"
                                    iconSize: 16
                                    tip: /*% "Show album" */ qsTrId("ryugin-me-show_album")
                                    onClicked: Api.hide(hiddenRow.modelData, false)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: page.fieldWidth - 40
                                    elide: Text.ElideRight
                                    text: hiddenRow.modelData.title + (hiddenRow.modelData.artist ? " · " + hiddenRow.modelData.artist : "")
                                    color: Theme.text
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
            Group {
                key: "look"
                Heading { text: /*% "Look" */ qsTrId("ryugin-he-look") }
                Option {
                    title: /*% "Song colours" */ qsTrId("ryugin-la-song_colours")
                    desc: /*% "The pages and the player take the colours of the song's cover; off: your desktop's" */ qsTrId("ryugin-de-song_colours_desktop")
                    Toggle { checked: Theme.settings.followCover; onToggled: function (on) { Theme.settings.followCover = on; } }
                }
                Option {
                    title: /*% "Show song tags" */ qsTrId("ryugin-he-show_song_tags")
                    desc: /*% "Streaming, quality and lyrics, in the fullscreen player" */ qsTrId("ryugin-de-song_tags")
                    Toggle { objectName: "tagsToggle"; checked: Player.settings.tags; onToggled: function (on) { Player.settings.tags = on; } }
                }
            }
            Group {
                key: "home"
                Heading { text: /*% "Home" */ qsTrId("ryugin-he-home") }
                Option {
                    objectName: "homeRows"
                    title: /*% "Rows" */ qsTrId("ryugin-he-rows")
                    desc: /*% "The rows Home shows, top to bottom: drag to reorder" */ qsTrId("ryugin-de-rows")
                    Column {
                        Repeater {
                            model: page.homeOrder()
                            delegate: Row {
                                id: homeRow
                                required property string modelData
                                required property int index
                                spacing: 2
                                z: grab.pressed ? 2 : 0
                                transform: Translate { id: shift }
                                // Its grip: drag the row up or down.
                                Item {
                                    width: 20
                                    height: tick.height
                                    Icon { anchors.centerIn: parent; name: "grip-vertical"; size: 14; color: grab.containsMouse || grab.pressed ? Theme.text : Theme.faint }
                                    MouseArea {
                                        id: grab
                                        property real from: 0
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        onPressed: function (mouse) { from = mapToItem(null, 0, mouse.y).y; }
                                        onPositionChanged: function (mouse) { if (pressed) shift.y = mapToItem(null, 0, mouse.y).y - from; }
                                        onReleased: {
                                            const by = Math.round(shift.y / homeRow.height);
                                            shift.y = 0;
                                            page.moveTo(homeRow.modelData, homeRow.index + by);
                                        }
                                    }
                                }
                                C.CheckBox {
                                    id: tick
                                    objectName: "homeRow-" + homeRow.modelData
                                    width: page.fieldWidth - 20 - moveUp.width - moveDown.width - 3 * homeRow.spacing // the row's name: all the room there is
                                    text: Nav.homeRows[homeRow.modelData]
                                    checked: Nav.layout.homeHidden.split(" ").indexOf(homeRow.modelData) < 0
                                    onToggled: page.showRow(homeRow.modelData, checked)
                                    // Ticked in the song's colour (a widget style paints its own).
                                    indicator: Rectangle {
                                        x: tick.leftPadding
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        radius: 3
                                        color: tick.checked ? Theme.gold : "transparent"
                                        border.color: tick.checked ? Theme.gold : Theme.faint
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Icon { anchors.centerIn: parent; name: "check"; size: 12; color: Theme.goldInk; visible: tick.checked }
                                    }
                                }
                                IconButton { id: moveUp; icon: "chevron-up"; iconSize: 14; tip: /*% "Up" */ qsTrId("ryugin-la-up"); enabled: homeRow.index > 0; opacity: enabled ? 1 : 0.3; anchors.verticalCenter: parent.verticalCenter; onClicked: page.moveRow(homeRow.modelData, -1) }
                                IconButton { id: moveDown; icon: "chevron-down"; iconSize: 14; tip: /*% "Down" */ qsTrId("ryugin-la-down"); enabled: homeRow.index < Object.keys(Nav.homeRows).length - 1; opacity: enabled ? 1 : 0.3; anchors.verticalCenter: parent.verticalCenter; onClicked: page.moveRow(homeRow.modelData, 1) }
                            }
                        }
                    }
                }
            }
            Group {
                key: "cache"
                Heading { text: /*% "Cache" */ qsTrId("ryugin-he-cache") }
                Option {
                    title: /*% "Keep songs" */ qsTrId("ryugin-la-keep_songs")
                    desc: /*% "Songs played play again from disk, also offline" */ qsTrId("ryugin-de-keep_songs_disk")
                    Toggle {
                        objectName: "cacheToggle"
                        checked: Player.settings.cache
                        onToggled: function (on) { Player.settings.cache = on; Api.cache({ on: on ? 1 : 0 }, page.showUsed); }
                    }
                }
                Option {
                    objectName: "cacheSize"
                    visible: Player.settings.cache
                    title: /*% "Songs" */ qsTrId("ryugin-he-songs")
                    desc: page.usedText("songs")
                    Field {
                        objectName: "cacheLimit"
                        width: 84
                        rightPadding: 30
                        horizontalAlignment: TextInput.AlignRight
                        text: Player.settings.cacheLimit
                        validator: IntValidator { bottom: 1; top: 9999 }
                        onEditingFinished: { Player.settings.cacheLimit = Number(text); Api.cache({ limit: text }, page.showUsed); }
                        Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: /*% "GB" */ qsTrId("ryugin-la-gb_unit"); color: Theme.faint; font.pixelSize: 11 }
                    }
                    IconButton {
                        objectName: "cacheClear"
                        icon: "trash-2"
                        iconSize: 16
                        filled: true
                        onClicked: Api.cache({ clear: "songs" }, page.showUsed)
                    }
                }
                Option {
                    objectName: "coverCache"
                    title: /*% "Covers" */ qsTrId("ryugin-la-covers")
                    desc: page.usedText("covers") + (page.used ? " · " : "") + /*% "every album's, kept offline" */ qsTrId("ryugin-de-covers")
                    IconButton {
                        objectName: "coverClear"
                        icon: "trash-2"
                        iconSize: 16
                        filled: true
                        onClicked: Api.cache({ clear: "covers" }, page.showUsed)
                    }
                }
            }
            Group {
                key: "about"
                topPadding: 16
                // About, as KDE apps show it: the dragon, the name, what it is, whose work it builds on.
                Image { anchors.horizontalCenter: parent.horizontalCenter; width: 72; height: 72; source: "icon.png"; sourceSize: Qt.size(144, 144); mipmap: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Ryūgin 龍吟"; color: Theme.text; font.pixelSize: 20 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Qt.application.version ? Qt.application.version + " · " : "") + /*% "A Navidrome player" */ qsTrId("ryugin-la-a_navidrome_player"); color: Theme.faint; font.pixelSize: 11 }
                Text {
                    objectName: "about"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    linkColor: Theme.gold
                    color: Theme.faint
                    font.pixelSize: 11
                    lineHeight: 1.3
                    text: "Ryūgin 龍吟" + (Qt.application.version ? " " + Qt.application.version : "") + /*% ", the dragon's song." */ qsTrId("ryugin-la-the_dragon_s_song") + "<br>"
                        + /*% "Design, layouts and code after %1 by imsyy; lyrics and fluid background after %2." */ qsTrId("ryugin-la-credits_desktop")
                          .arg("<a href=\"https://github.com/imsyy/SPlayer\">SPlayer</a>")
                          .arg("<a href=\"https://github.com/amll-dev/applemusic-like-lyrics\">AMLL</a>") + "<br><br>"
                        + /*% "License: AGPL-3.0 or later" */ qsTrId("ryugin-la-license")
                    onLinkActivated: function (link) { Qt.openUrlExternally(link); }
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }
        }
    }

    // Close, at the bottom right, as a KDE dialog's buttons.
    Item {
        id: buttons
        anchors.left: pagesList.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 48
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        TextButton {
            objectName: "settingsClose"
            visible: Api.configured // until a server is set, it stays
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: /*% "Close" */ qsTrId("ryugin-la-close")
            onClicked: page.closeRequested()
        }
    }
}
