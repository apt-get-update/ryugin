import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The queue, attached to Now playing: a tap plays a song and goes back there; a long press
// moves it (next, to the top) or takes it out; a heart marks a liked song. Pull down to
// save it as a playlist or clear it.
Page {
    id: page

    objectName: "queue" // Now playing's (attached): no mini player over it

    RemorsePopup {
        id: remorse
    }

    // The new playlist's name.
    Component {
        id: nameDialog

        Dialog {
            canAccept: name.text.trim() !== ""
            onAccepted: R.Api.createPlaylist(name.text.trim(), R.Player.queue.map(function (t) { return t.id }))
            // The field and the keyboard ready to type in (Keel's field alone opens no
            // keyboard), as on the Search page.
            onStatusChanged: {
                if (status === PageStatus.Active) {
                    name.forceActiveFocus()
                    Qt.inputMethod.show()
                }
            }

            Column {
                width: parent.width

                DialogHeader {
                    //% "Save"
                    acceptText: qsTrId("ryugin-bt-save")
                }
                TextField {
                    id: name

                    width: parent.width
                    //% "Playlist's name"
                    label: qsTrId("ryugin-la-playlist_s_name")
                    placeholderText: label
                    EnterKey.enabled: text.trim() !== ""
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: accept()
                }
            }
        }
    }

    SilicaListView {
        id: list

        anchors.fill: parent
        model: R.Player.queue

        Pulley {
            enabled: R.Player.queue.length > 0

            MenuItem {
                //% "Save as playlist"
                text: qsTrId("ryugin-me-save_as_playlist")
                onClicked: pageStack.animatorPush(nameDialog)
            }
            MenuItem {
                //% "Clear queue"
                text: qsTrId("ryugin-me-clear_queue")
                //% "Clearing the queue"
                onClicked: remorse.execute(qsTrId("ryugin-la-clearing_the_queue"), function () {
                    R.Player.clear()
                    // Nothing plays now: past Now playing, back to where it opened from.
                    if (page.status === PageStatus.Active)
                        pageStack.pop(pageStack.previousPage(pageStack.previousPage(page)))
                })
            }
        }

        header: PageHeader {
            //% "Queue"
            title: qsTrId("ryugin-he-queue")
            //% "%n songs"
            description: qsTrId("ryugin-la-n_songs", R.Player.queue.length)
        }

        delegate: ListItem {
            id: item

            readonly property bool current: model.index === R.Player.index
            // The heart's colour, Silica's (inside the Loader, "item" is the Loader's own item).
            readonly property color heartColor: palette.highlightColor

            contentHeight: Theme.itemSizeMedium
            // Played, then back to Now playing, the page the queue is attached to (as a
            // picker returns to its page).
            onClicked: {
                R.Player.jump(model.index)
                pageStack.navigateBack()
            }

            menu: Component {
                ContextMenu {
                    MenuItem {
                        visible: !item.current
                        //% "Play next"
                        text: qsTrId("ryugin-me-play_next")
                        onClicked: R.Player.move(model.index, model.index < R.Player.index ? R.Player.index : R.Player.index + 1)
                    }
                    MenuItem {
                        visible: model.index > 0
                        //% "Move to top"
                        text: qsTrId("ryugin-me-move_to_top")
                        onClicked: R.Player.move(model.index, 0)
                    }
                    MenuItem {
                        //% "Remove"
                        text: qsTrId("ryugin-me-remove")
                        onClicked: R.Player.removeAt(model.index)
                    }
                }
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x - (heart.active ? heart.width + Theme.paddingMedium : 0)
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    color: item.current || item.highlighted ? palette.highlightColor : palette.primaryColor
                    text: modelData.title
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.current || item.highlighted ? palette.secondaryHighlightColor : palette.secondaryColor
                    text: modelData.artist
                }
            }
            Loader { // a liked song's heart, made for it only
                id: heart

                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                active: !!modelData.starred
                sourceComponent: Item { // as TrackItem's
                    width: Theme.iconSizeExtraSmall
                    height: width

                    // Drawn once in white, tinted on the GPU (icon.frag): the song's colour fading
                    // in redraws no SVG. Silica's inset: the shape in 24/29 of the box.
                    R.Icon {
                        anchors.centerIn: parent
                        name: "heart-fill"
                        size: Math.round(parent.width * 24 / 29)
                        color: heartColor
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: R.Player.queue.length === 0
            //% "The queue is empty"
            text: qsTrId("ryugin-la-the_queue_is_empty")
        }

        VerticalScrollDecorator {}
    }

    // Kept between swipes (attached): each time it comes in, at the song playing.
    onStatusChanged: if (status === PageStatus.Activating) list.positionViewAtIndex(Math.max(0, R.Player.index), ListView.Center)
}
