import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The server, the song colours, the song cache, and about.
Page {
    id: page

    property var used: null

    function size(bytes) {
        return bytes < 1 << 30 ? Math.round(bytes / (1 << 20)) + " MB" : (bytes / (1 << 30)).toFixed(1) + " GB"
    }
    function showUsed(sizes) {
        page.used = sizes
    }

    Component.onCompleted: R.Api.cache({}, showUsed)

    SilicaFlickable {
        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: "Settings"
            }

            SectionHeader {
                text: "Navidrome"
            }
            ValueButton {
                label: "Server"
                value: R.Api.configured ? R.Api.settings.user + " @ " + R.Api.settings.url : "None"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("LoginDialog.qml"))
            }

            SectionHeader {
                text: "Look"
            }
            TextSwitch {
                text: "Song colours"
                description: "The pages and the player take the colours of the song's cover"
                checked: R.Theme.settings.followCover
                onCheckedChanged: R.Theme.settings.followCover = checked
            }

            SectionHeader {
                text: "Cache"
            }
            TextSwitch {
                text: "Keep songs"
                description: "Songs played to the end stay on the phone, also for offline use"
                checked: R.Player.settings.cache
                onCheckedChanged: {
                    if (checked !== R.Player.settings.cache) {
                        R.Player.settings.cache = checked
                        R.Api.cache({ on: checked ? 1 : 0 }, page.showUsed)
                    }
                }
            }
            Slider {
                width: parent.width
                label: "Songs, at most"
                minimumValue: 1
                maximumValue: 20
                stepSize: 1
                value: R.Player.settings.cacheLimit
                valueText: value + " GB"
                onReleased: {
                    R.Player.settings.cacheLimit = value
                    R.Api.cache({ limit: value }, page.showUsed)
                }
            }
            Repeater {
                model: [{ kind: "songs", label: "Songs" }, { kind: "covers", label: "Covers" }]

                delegate: ListItem {
                    contentHeight: Theme.itemSizeSmall
                    menu: ContextMenu {
                        MenuItem {
                            text: "Clear"
                            onClicked: R.Api.cache({ clear: modelData.kind }, page.showUsed)
                        }
                    }

                    Label {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                    }
                    Label {
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        color: palette.secondaryColor
                        text: page.used ? page.size(page.used[modelData.kind]) : ""
                    }
                }
            }

            SectionHeader {
                text: "About"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                linkColor: palette.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                color: palette.secondaryColor
                text: "Ryūgin 龍吟" + (Qt.application.version ? " " + Qt.application.version : "") + ", the dragon's song.<br>"
                      + "Design and code after <a href=\"https://github.com/imsyy/SPlayer\">SPlayer</a> by imsyy; "
                      + "lyrics after <a href=\"https://github.com/amll-dev/applemusic-like-lyrics\">AMLL</a>."
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }

        VerticalScrollDecorator {}
    }
}
