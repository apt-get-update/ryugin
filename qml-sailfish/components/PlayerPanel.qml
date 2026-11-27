import QtQuick 2.6
import Sailfish.Silica 1.0
import "../../qml" as R

// Now playing's controls, docked at its bottom, as Jolla's Media player has them: ported
// from Sailfish.Media's MediaPlayerControlsPanel (Qt 5 only, not in Keel). Its glow, the
// time, the song (title and artist), previous, play, next a third each; its push-up menu (a swipe up): shuffle, repeat,
// the heart. In the page: the song's colours come with it.
DockedPanel {
    id: panel

    readonly property bool _isLandscape: pageStack.currentPage !== null && pageStack.currentPage.isLandscape

    objectName: "playerPanel"
    // In landscape at the right of the cover (as tall as the page), under the lyrics.
    width: _isLandscape ? parent.width - parent.height : parent.width
    x: parent.width - width
    height: grid.height + (_isLandscape ? Theme.paddingLarge : 2 * Theme.paddingLarge)
    contentHeight: height
    flickableDirection: Flickable.VerticalFlick
    dock: Dock.Bottom
    open: true
    onOpenChanged: if (!open) open = true // a swipe down closes a docked panel: the controls stay

    // MediaPlayerPanelBackground: the highlight, fading in from the top.
    background: Rectangle {
        id: glow

        width: panel.width
        height: panel.height
        color: Theme.rgba(palette.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.7; color: glow.color }
        }
    }

    Column {
        id: grid

        width: parent.width
        y: panel._isLandscape ? Theme.paddingSmall : Theme.paddingMedium

        // The slider has its own padding: the buttons come a bit closer.
        Item {
            width: parent.width
            height: progress.height - Theme.paddingMedium - Theme.paddingSmall

            Slider {
                id: progress

                objectName: "playerProgress"
                width: parent.width
                handleVisible: false
                minimumValue: 0
                maximumValue: Math.max(1, R.Player.duration)
                valueText: R.Theme.time(Math.floor((down ? sliderValue : value) / 1000))
                onReleased: R.Player.seek(sliderValue)
                Component.onCompleted: value = R.Player.shownPosition
            }
            // Set, not bound, as the Media player does: a seek assigns the slider's value,
            // which would end a binding and leave the bar where the finger left it.
            Connections {
                target: R.Player
                function onShownPositionChanged() {
                    if (!progress.down)
                        progress.value = R.Player.shownPosition
                }
            }
        }

        // The song between the time and the buttons, as the Media player has it.
        Column {
            width: parent.width

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                // Centred while it fits; longer, it starts at the left and fades at its end.
                horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                text: R.Player.current ? R.Player.current.title : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeSmall
                color: palette.secondaryColor
                text: R.Player.current ? R.Player.current.artist : ""
            }
        }

        Row {
            width: parent.width

            IconButton {
                width: parent.width / 3
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-previous"
                onClicked: R.Player.previous()
            }
            IconButton {
                width: parent.width / 3
                icon.source: R.Player.playing ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                onClicked: R.Player.toggle()
            }
            IconButton {
                width: parent.width / 3
                anchors.verticalCenter: parent.verticalCenter
                enabled: R.Player.queue.length > 1 // something to go forward to
                icon.source: "image://theme/icon-m-next"
                onClicked: R.Player.next()
            }
        }
    }

    PushUpMenu {
        // Silica ticks as a pulley passes each MenuItem: this one has switches, no items, so
        // it ticks once as it opens (the same feedback; Nemo.Ngf, not needed to run).
        property QtObject tick: Qt.createQmlObject("import Nemo.Ngf 1.0; NonGraphicalFeedback { event: 'pulldown_highlight' }", panel, "tick")

        bottomMargin: panel._isLandscape ? Theme.itemSizeExtraSmall : Theme.itemSizeSmall
        onActiveChanged: if (active && tick) tick.play()

        Row {
            width: parent.width

            Switch {
                width: parent.width / 3
                anchors.bottom: parent.bottom
                icon.source: "image://theme/icon-m-shuffle"
                automaticCheck: false
                checked: R.Player.settings.shuffle
                onClicked: R.Player.toggleShuffle()
            }
            Switch {
                width: parent.width / 3
                anchors.bottom: parent.bottom
                icon.source: R.Player.repeat === "one" ? "image://theme/icon-m-repeat-single" : "image://theme/icon-m-repeat"
                automaticCheck: false
                checked: R.Player.repeat !== "off"
                onClicked: R.Player.cycleRepeat()
            }
            // Liked: a switch as the others, its light on (a heart drawn as Silica draws its
            // icons: Silica's "favorite" is a star).
            Switch {
                objectName: "like"
                width: parent.width / 3
                anchors.bottom: parent.bottom
                icon.source: R.Icons.silica("heart", Theme.iconSizeMedium, palette.primaryColor)
                automaticCheck: false
                checked: R.Player.current !== null && !!R.Player.current.starred
                onClicked: R.Player.toggleStar()
            }
        }
    }
}
