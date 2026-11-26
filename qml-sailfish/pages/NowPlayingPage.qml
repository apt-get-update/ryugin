import QtQuick 2.6
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The song playing: its cover, the time, the controls (beside the cover in landscape).
// Swipe left for its lyrics; pull down for the queue and its album.
Page {
    id: page

    readonly property var track: R.Player.current

    objectName: "nowPlaying"
    allowedOrientations: Orientation.All

    onStatusChanged: {
        if (status === PageStatus.Active) {
            pageStack.pushAttached(Qt.resolvedUrl("LyricsPage.qml"))
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Pulley {
            MenuItem {
                visible: page.track !== null && page.track.albumId !== ""
                text: "Go to album"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("AlbumPage.qml"), { albumId: page.track.albumId })
            }
            MenuItem {
                text: "Queue"
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("QueuePage.qml"))
            }
        }

        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                id: header

                title: "Now playing"
            }

            Grid {
                x: Theme.horizontalPageMargin
                columns: page.isLandscape ? 2 : 1
                columnSpacing: Theme.paddingLarge
                rowSpacing: Theme.paddingLarge
                verticalItemAlignment: Grid.AlignVCenter

                Image {
                    id: cover

                    width: page.isLandscape ? page.height - header.height - 2 * Theme.paddingLarge
                                            : page.width - 2 * Theme.horizontalPageMargin
                    height: width
                    sourceSize {
                        width: width
                        height: height
                    }
                    fillMode: Image.PreserveAspectCrop
                    source: page.track ? R.Api.cover(page.track.cover, 720) : ""
                }

                Column {
                    width: page.isLandscape ? page.width - cover.width - 2 * Theme.horizontalPageMargin - Theme.paddingLarge
                                            : cover.width
                    spacing: Theme.paddingLarge

                    Column {
                        width: parent.width

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            truncationMode: TruncationMode.Elide
                            font.pixelSize: Theme.fontSizeLarge
                            color: palette.highlightColor
                            text: page.track ? page.track.title : ""
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            truncationMode: TruncationMode.Fade
                            color: palette.secondaryHighlightColor
                            text: page.track ? page.track.artist + (page.track.album ? "  ·  " + page.track.album : "") : ""
                        }
                    }

                    Slider {
                        id: progress

                        width: parent.width
                        minimumValue: 0
                        maximumValue: Math.max(1, R.Player.duration)
                        value: R.Player.shownPosition
                        valueText: R.Theme.time(Math.floor((down ? sliderValue : R.Player.shownPosition) / 1000))
                        label: R.Theme.time(Math.floor(R.Player.duration / 1000))
                        onReleased: R.Player.seek(sliderValue)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingLarge

                        IconButton {
                            icon.source: "image://theme/icon-m-shuffle"
                            highlighted: R.Player.settings.shuffle
                            onClicked: R.Player.toggleShuffle()
                        }
                        IconButton {
                            icon.source: "image://theme/icon-m-previous"
                            onClicked: R.Player.previous()
                        }
                        IconButton {
                            width: Theme.iconSizeLarge
                            height: width
                            icon.source: R.Player.playing ? "image://theme/icon-l-pause" : "image://theme/icon-l-play"
                            onClicked: R.Player.toggle()
                        }
                        IconButton {
                            icon.source: "image://theme/icon-m-next"
                            onClicked: R.Player.next()
                        }
                        IconButton {
                            icon.source: R.Player.repeat === "one" ? "image://theme/icon-m-repeat-single" : "image://theme/icon-m-repeat"
                            highlighted: R.Player.repeat !== "off"
                            onClicked: R.Player.cycleRepeat()
                        }
                    }

                    IconButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon.source: page.track && page.track.starred ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                        onClicked: R.Player.toggleStar()
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
