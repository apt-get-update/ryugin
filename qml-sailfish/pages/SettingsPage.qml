import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The server and its library scan, the song colours, Home's rows, the song cache, and about.
Page {
    id: page

    property var used: null
    property string scanError: "" // a scan refused (not an admin)

    function size(bytes) {
        return bytes < 1 << 30
                //% "%1 MB"
                ? qsTrId("ryugin-la-mb").arg(Math.round(bytes / (1 << 20)))
                //% "%1 GB"
                : qsTrId("ryugin-la-gb").arg((bytes / (1 << 30)).toFixed(1))
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
                //% "Settings"
                title: qsTrId("ryugin-he-settings")
            }

            SectionHeader {
                text: "Navidrome"
            }
            ValueButton {
                //% "Server"
                label: qsTrId("ryugin-la-server")
                //% "None"
                value: R.Api.configured ? R.Api.settings.user + " @ " + R.Api.settings.url : qsTrId("ryugin-la-none")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("LoginDialog.qml"))
            }
            ValueButton {
                objectName: "scan"
                enabled: R.Api.configured && !R.Api.scanning
                //% "Library"
                label: qsTrId("ryugin-la-library")
                value: R.Api.scanning
                       //% "Scanning…"
                       ? qsTrId("ryugin-la-scanning")
                       //% "%n songs"
                       : R.Api.songTotal ? qsTrId("ryugin-la-n_songs", R.Api.songTotal) : ""
                //% "Tap to find new and changed music"
                description: page.scanError || qsTrId("ryugin-de-scan")
                onClicked: R.Api.startScan(function (err) { page.scanError = err || "" })
            }

            SectionHeader {
                //% "Look"
                text: qsTrId("ryugin-he-look")
            }
            TextSwitch {
                //% "Song colours"
                text: qsTrId("ryugin-la-song_colours")
                //% "The pages and the player take the colours of the song's cover"
                description: qsTrId("ryugin-de-song_colours")
                checked: R.Theme.settings.followCover
                onCheckedChanged: R.Theme.settings.followCover = checked
            }

            SectionHeader {
                //% "Home"
                text: qsTrId("ryugin-he-home")
            }
            Repeater {
                // Sailfish OS's Home order.
                model: ["recentSongs", "newest", "recent", "frequent"]

                delegate: TextSwitch {
                    text: R.Nav.homeRows[modelData]
                    checked: R.Nav.layout.homeHidden.split(" ").indexOf(modelData) < 0
                    onCheckedChanged: {
                        var hidden = R.Nav.layout.homeHidden.split(" ").filter(function (k) { return k && k !== modelData })
                        R.Nav.layout.homeHidden = (checked ? hidden : hidden.concat([modelData])).join(" ")
                    }
                }
            }

            SectionHeader {
                visible: hiddenAlbums.count > 0
                //% "Hidden albums"
                text: qsTrId("ryugin-he-hidden_albums")
            }
            Repeater {
                id: hiddenAlbums

                model: Object.keys(R.Api.hidden).map(function (k) { return R.Api.hidden[k] }).sort(function (a, b) { return a.title.localeCompare(b.title) })

                delegate: ListItem {
                    contentHeight: Theme.itemSizeMedium
                    onClicked: pageStack.animatorPush(Qt.resolvedUrl("AlbumPage.qml"), { albumId: modelData.id })
                    menu: ContextMenu {
                        MenuItem {
                            //% "Show album"
                            text: qsTrId("ryugin-me-show_album")
                            onClicked: R.Api.hide(modelData, false)
                        }
                    }

                    Column {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            color: highlighted ? palette.highlightColor : palette.primaryColor
                            text: modelData.title
                        }
                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeSmall
                            color: highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
                            text: modelData.artist
                        }
                    }
                }
            }

            SectionHeader {
                //% "Cache"
                text: qsTrId("ryugin-he-cache")
            }
            TextSwitch {
                //% "Keep songs"
                text: qsTrId("ryugin-la-keep_songs")
                //% "Songs played stay on the phone, also for offline use"
                description: qsTrId("ryugin-de-keep_songs")
                checked: R.Player.settings.cache
                onCheckedChanged: {
                    if (checked !== R.Player.settings.cache) {
                        R.Player.settings.cache = checked
                        R.Api.cache({ on: checked ? 1 : 0 }, page.showUsed)
                    }
                }
            }
            TextSwitch {
                //% "Use mobile data"
                text: qsTrId("ryugin-la-mobile_data")
                //% "Also on mobile data: look for synced lyrics in the library, and download the next song"
                description: qsTrId("ryugin-de-mobile_data")
                             + (R.Player.sweepLeft > 0
                                //% "Lyrics: %n songs left to check"
                                ? "\n" + qsTrId("ryugin-la-n_lyrics_left", R.Player.sweepLeft)
                                //% "Lyrics: waiting for WLAN"
                                : R.Player.sweepPaused ? "\n" + qsTrId("ryugin-la-waiting_wlan") : "")
                checked: R.Player.settings.mobileData
                onCheckedChanged: R.Player.settings.mobileData = checked
            }
            Slider {
                width: parent.width
                //% "Songs, at most"
                label: qsTrId("ryugin-la-cache_limit")
                minimumValue: 1
                maximumValue: 20
                stepSize: 1
                value: R.Player.settings.cacheLimit
                //% "%1 GB"
                valueText: qsTrId("ryugin-la-gb").arg(value)
                onReleased: {
                    R.Player.settings.cacheLimit = value
                    R.Api.cache({ limit: value }, page.showUsed)
                }
            }
            Repeater {
                model: [
                    //% "Songs"
                    { kind: "songs", label: qsTrId("ryugin-la-songs") },
                    //% "Covers"
                    { kind: "covers", label: qsTrId("ryugin-la-covers") }
                ]

                delegate: ListItem {
                    contentHeight: Theme.itemSizeSmall
                    menu: ContextMenu {
                        MenuItem {
                            //% "Clear"
                            text: qsTrId("ryugin-me-clear")
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
                //% "About"
                text: qsTrId("ryugin-he-about")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                linkColor: palette.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                color: palette.secondaryColor
                //% ", the dragon's song."
                text: "Ryūgin 龍吟" + (Qt.application.version ? " " + Qt.application.version : "") + qsTrId("ryugin-la-the_dragon_s_song") + "<br>"
                      //% "Design and code after %1 by imsyy; lyrics after %2."
                      + qsTrId("ryugin-la-credits")
                        .arg("<a href=\"https://github.com/imsyy/SPlayer\">SPlayer</a>")
                        .arg("<a href=\"https://github.com/amll-dev/applemusic-like-lyrics\">AMLL</a>")
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }

        VerticalScrollDecorator {}
    }
}
