import QtQuick 2.0
import QtQuick.Effects
import Sailfish.Silica 1.0
import "../../qml" as R

// The song playing, docked over the end of every page but its own (Now playing, its queue
// and lyrics): its cover, title and artist, play/pause and next; a tap opens it. Frosted
// glass: the page under it blurred, toned as the ambience's panels, in the song's colours
// (those of the page stack, ryugin.qml).
DockedPanel {
    id: panel

    // The app's wallpaper (Backdrop, out of the window's content), for the glass.
    property Item backdrop
    // The song's colours, for its text and buttons (ryugin.qml sets them).
    readonly property var songPalette: content.palette
    readonly property bool _songPage: pageStack.currentPage !== null
                                      && (pageStack.currentPage.objectName === "nowPlaying"
                                          || pageStack.currentPage.objectName === "queue"
                                          || pageStack.currentPage.objectName === "lyrics")

    width: parent.width
    height: Theme.itemSizeLarge
    dock: Dock.Bottom
    // Out of the keyboard's way, as Jolla's media panel.
    opacity: Qt.inputMethod.visible ? 0 : 1

    Behavior on opacity {
        FadeAnimation {}
    }
    // A Binding, not a plain one: a swipe down sets open itself, which would end a plain
    // binding and leave the player gone.
    Binding on open {
        value: R.Player.current !== null && !panel._songPage
    }

    // Silica glass, as Backdrop: what is under the bar (at a quarter size: a strong blur),
    // blurred, toned to the scheme, tinted with the highlight dimmer, dithered, and the
    // ambience's panel tint over it.
    background: Component {
        SilicaItem {
            id: glass

            readonly property bool light: Theme.colorScheme === Theme.DarkOnLight

            clip: true
            palette.highlightBackgroundColor: pageStack.palette.highlightBackgroundColor
            palette.highlightDimmerColor: pageStack.palette.highlightDimmerColor

            // Without the song's wallpaper (song colours off: Lipstick draws the ambience,
            // out of reach), a base the page's text cannot show through.
            Rectangle {
                anchors.fill: parent
                visible: opacity > 0
                color: glass.light ? "white" : "black"
                opacity: 0.85 * (1 - R.Theme.k) // fades as the cover's ambience comes
            }
            // The window under the bar, its wallpaper and page together (text has no
            // background: a page alone blurs thin and lets it through), with a margin
            // above (the blur reads past the bar's top). Their pictures are turned to the bar's
            // (the window's content stays in the screen's frame, the wallpaper turns).
            Item {
                id: under

                readonly property Item window: __silica_applicationwindow_instance // qmllint disable unqualified

                y: -2 * Theme.paddingLarge
                width: parent.width
                height: parent.height - y
                visible: false

                Repeater {
                    model: panel.backdrop ? [panel.backdrop, under.window.contentItem] : [under.window.contentItem]

                    ShaderEffectSource {
                        readonly property bool turned: Math.abs(rotation) % 180 === 90

                        anchors.centerIn: parent
                        rotation: modelData.rotation - under.window.screenRotation // the wallpaper turns too
                        width: turned ? parent.height : parent.width
                        height: turned ? parent.width : parent.height
                        live: panel.open // open from the start (a song restored): never "expanded"
                        sourceItem: modelData
                        textureSize: Qt.size(width / 4, height / 4)
                        sourceRect: {
                            // Again when the bar moves or turns.
                            panel.y
                            panel.width
                            panel.height
                            rotation
                            var a = under.mapToItem(sourceItem, 0, 0)
                            var b = under.mapToItem(sourceItem, under.width, under.height)
                            return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y))
                        }
                    }
                }
            }
            MultiEffect {
                anchors.fill: under
                source: under
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 64
            }
            Rectangle {
                anchors.fill: parent
                color: glass.light ? "white" : "black"
                opacity: glass.light ? 0.35 : 0.4
            }
            Rectangle {
                anchors.fill: parent
                visible: !glass.light
                color: glass.palette.highlightDimmerColor
                opacity: 0.12
            }
            Image {
                anchors.fill: parent
                source: "qrc:/qt/qml/Sailfish/Silica/ambience/glass-dither.png"
                fillMode: Image.Tile
                smooth: false
                opacity: glass.light ? 0.6 : 1.0
            }
            PanelBackground {
                anchors.fill: parent
            }
        }
    }

    // Its content clear of the display's notch (the screen's top: at the bar's left end in
    // landscape, its right end turned over), as Keel keeps pages clear of it; the glass
    // goes under it, as the wallpaper.
    SilicaItem {
        id: content

        readonly property int orientation: pageStack.currentPage ? pageStack.currentPage.orientation : Orientation.Portrait

        anchors {
            fill: parent
            leftMargin: orientation === Orientation.Landscape ? Screen.topCutout.height : 0
            rightMargin: orientation === Orientation.LandscapeInverted ? Screen.topCutout.height : 0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: R.Nav.open("NowPlayingPage")
        }

        Image {
            id: art

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: parent.height
            height: parent.height
            sourceSize {
                width: width
                height: height
            }
            fillMode: Image.PreserveAspectCrop
            source: R.Player.current ? R.Api.cover(R.Player.current.cover, 256) : ""
        }

        Column {
            anchors {
                left: art.right
                leftMargin: Theme.paddingMedium
                right: buttons.left
                verticalCenter: parent.verticalCenter
            }

            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                text: R.Player.current ? R.Player.current.title : ""
            }
            Label {
                width: parent.width
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: palette.secondaryColor
                text: R.Player.current ? R.Player.current.artist : ""
            }
        }

        Row {
            id: buttons

            anchors {
                right: parent.right
                rightMargin: Theme.paddingSmall
                verticalCenter: parent.verticalCenter
            }

            IconButton {
                icon.source: R.Player.playing ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                onClicked: R.Player.toggle()
            }
            IconButton {
                enabled: R.Player.queue.length > 1 // something to go forward to, as Now playing's
                icon.source: "image://theme/icon-m-next"
                onClicked: R.Player.next()
            }
        }
    }
}
