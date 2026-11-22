import QtQuick
import QtQuick.Controls.Basic as C

// Connect to Navidrome (the password becomes a salted token; it is not stored), then the
// options, by group. Taller than the window (a phone on its side), it scrolls.
Item {
    id: page
    implicitWidth: card.width
    implicitHeight: card.height
    readonly property int pad: Nav.phone ? 20 : 32
    // The close button (Main.qml closes the popup): a phone has no Escape, and the card
    // leaves little outside to tap.
    signal closeRequested()
    // The bytes the song cache holds, -1 until Go answers.
    // The bytes the cache holds: { songs, covers }; null until Go answers.
    property var used: null
    function showUsed(sizes) { page.used = sizes; }
    function usedText(kind) { return page.used ? page.size(page.used[kind]) + " used" : ""; }
    function size(bytes) {
        return bytes < 1 << 30 ? Math.round(bytes / (1 << 20)) + " MB" : (bytes / (1 << 30)).toFixed(1) + " GB";
    }
    onVisibleChanged: if (visible) Api.cache({}, showUsed)
    Component.onCompleted: Api.cache({}, showUsed)

    // A group's name, small and gold.
    component Heading: Text {
        topPadding: 10
        color: Theme.gold
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
    }
    // One option: its name and what it does on the left, its control(s) on the right.
    component Option: Item {
        id: o
        property string title
        property string desc
        default property alias controls: side.data
        width: parent ? parent.width : 0
        height: Math.max(40, label.implicitHeight)
        Column {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - side.width - 16
            Text { text: o.title; color: Theme.text; font.pixelSize: 14 }
            Text { width: parent.width; text: o.desc; visible: o.desc !== ""; color: Theme.faint; font.pixelSize: 11; wrapMode: Text.WordWrap }
        }
        Row {
            id: side
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    Card {
        id: card
        anchors.centerIn: parent
        width: Nav.phone ? Math.min(480, (Window.width || 504) - 24) : 520
        height: Math.min(form.implicitHeight + 2 * page.pad, (Window.height || 900) - (Nav.phone ? 24 : 48))
        Flickable {
            anchors.fill: parent
            anchors.margins: 1 // inside the border
            clip: true
            contentHeight: form.implicitHeight + 2 * page.pad
            boundsBehavior: Flickable.StopAtBounds
            C.ScrollBar.vertical: Scroller {}
            Column {
                id: form
                x: page.pad
                y: page.pad
                width: parent.width - 2 * page.pad
                spacing: 12
                Item {
                    width: parent.width
                    height: Nav.phone ? 48 : 64
                    Row {
                        anchors.centerIn: parent
                        spacing: 14
                        Image {
                            width: parent.parent.height
                            height: width
                            source: "icon.png"
                            sourceSize: Qt.size(128, 128)
                            mipmap: true
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Ryūgin"; color: Theme.gold; font.pixelSize: 22; font.weight: Font.DemiBold }
                    }
                    IconButton {
                        objectName: "settingsClose"
                        visible: Api.configured // until a server is set, it stays
                        anchors.right: parent.right
                        anchors.top: parent.top
                        icon: "x"
                        iconSize: 20
                        filled: true
                        onClicked: page.closeRequested()
                    }
                }

                Heading { text: "Server" }
                Text { visible: !Api.configured; text: "Connect to your Navidrome server"; color: Theme.dim; font.pixelSize: 13 }
                Field { id: url; width: parent.width; icon: "server"; placeholderText: "https://music.example.org"; text: Api.settings.url; onAccepted: user.forceActiveFocus() }
                Field { id: user; width: parent.width; icon: "user"; placeholderText: "User"; text: Api.settings.user; onAccepted: pass.forceActiveFocus() }
                Field { id: pass; width: parent.width; icon: "key-round"; placeholderText: Api.configured ? "Password (only to change it)" : "Password"; echoMode: TextInput.Password; onAccepted: connect.clicked() }
                TextButton {
                    id: connect
                    width: parent.width
                    height: 42
                    primary: true
                    icon: "log-in"
                    text: "Connect"
                    onClicked: Api.login(url.text, user.text, pass.text, function (err) {
                        if (!err) { pass.text = ""; Nav.home(); }
                    })
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Api.online ? "Connected to " + Api.settings.url : Api.error
                    color: Api.online ? Theme.gold : Theme.dim
                    font.pixelSize: 12
                }

                Heading { text: "Appearance" }
                Option {
                    title: "Follow album colours"
                    desc: "Tint the app with the playing cover"
                    Toggle { checked: Theme.settings.followCover; onToggled: function (on) { Theme.settings.followCover = on; } }
                }
                Option {
                    title: "Show song tags"
                    desc: "Streaming, quality and lyrics, in the fullscreen player"
                    Toggle { objectName: "tagsToggle"; checked: Player.settings.tags; onToggled: function (on) { Player.settings.tags = on; } }
                }

                Heading { text: "Cache" }
                Option {
                    title: "Keep songs"
                    desc: "Songs played to the end play again from disk, also offline"
                    Toggle {
                        objectName: "cacheToggle"
                        checked: Player.settings.cache
                        onToggled: function (on) { Player.settings.cache = on; Api.cache({ on: on ? 1 : 0 }, page.showUsed); }
                    }
                }
                Option {
                    objectName: "cacheSize"
                    visible: Player.settings.cache
                    title: "Songs"
                    desc: page.usedText("songs")
                    Field {
                        objectName: "cacheLimit"
                        width: 84
                        implicitHeight: 36
                        rightPadding: 34
                        horizontalAlignment: TextInput.AlignRight
                        text: Player.settings.cacheLimit
                        validator: IntValidator { bottom: 1; top: 9999 }
                        onEditingFinished: { Player.settings.cacheLimit = Number(text); Api.cache({ limit: text }, page.showUsed); }
                        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "GB"; color: Theme.faint; font.pixelSize: 13 }
                    }
                    IconButton {
                        objectName: "cacheClear"
                        icon: "trash-2"
                        iconSize: 18
                        filled: true
                        onClicked: Api.cache({ clear: "songs" }, page.showUsed)
                    }
                }
                Option {
                    objectName: "coverCache"
                    title: "Covers"
                    desc: page.usedText("covers") + (page.used ? " · " : "") + "every album's, kept offline"
                    IconButton {
                        objectName: "coverClear"
                        icon: "trash-2"
                        iconSize: 18
                        filled: true
                        onClicked: Api.cache({ clear: "covers" }, page.showUsed)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }
                // About: what the name means, and whose work this player is built on.
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
                    text: "Ryūgin 龍吟" + (Qt.application.version ? " " + Qt.application.version : "") + ", the dragon's song.<br>"
                        + "Design, layouts and code after <a href=\"https://github.com/imsyy/SPlayer\">SPlayer</a> by imsyy; "
                        + "lyrics and fluid background after <a href=\"https://github.com/amll-dev/applemusic-like-lyrics\">AMLL</a>."
                    onLinkActivated: function (link) { Qt.openUrlExternally(link); }
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }
        }
    }
}
