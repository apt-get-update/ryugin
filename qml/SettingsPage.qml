import QtQuick

// Connect to Navidrome. The password becomes a salted token; it is not stored.
Item {
    id: page
    implicitWidth: card.width
    implicitHeight: card.height
    Card {
        id: card
        anchors.centerIn: parent
        width: Nav.phone ? Math.min(480, (Window.width || 504) - 24) : 520
        height: form.implicitHeight + 64
        Column {
            id: form
            x: 32
            y: 32
            width: parent.width - 64
            spacing: 14
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 84
                height: 84
                source: "icon.png"
                sourceSize: Qt.size(168, 168)
                mipmap: true
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Ryūgin"; color: Theme.gold; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Connect to your Navidrome server"; color: Theme.dim; font.pixelSize: 13; bottomPadding: 8 }
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
                bottomPadding: 6
                text: Api.online ? "Connected to " + Api.settings.url : Api.error
                color: Api.online ? Theme.gold : Theme.dim
                font.pixelSize: 12
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Item {
                width: parent.width
                height: Math.max(40, childrenRect.height)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    Text { text: "Follow album colours"; color: Theme.text; font.pixelSize: 14 }
                    Text { width: parent.width; text: "Tint the app with the playing cover"; color: Theme.faint; font.pixelSize: 11; wrapMode: Text.WordWrap }
                }
                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Theme.settings.followCover
                    onToggled: function (on) { Theme.settings.followCover = on; }
                }
            }
            Item {
                width: parent.width
                height: Math.max(40, childrenRect.height)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    Text { text: "Show song tags"; color: Theme.text; font.pixelSize: 14 }
                    Text { width: parent.width; text: "Streaming, quality and lyrics, in the fullscreen player"; color: Theme.faint; font.pixelSize: 11; wrapMode: Text.WordWrap }
                }
                Toggle {
                    objectName: "tagsToggle"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Player.settings.tags
                    onToggled: function (on) { Player.settings.tags = on; }
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
