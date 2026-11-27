import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The queue: a tap plays a song, a long press moves it (next, to the top) or takes it out;
// a heart marks a liked song. Pull down to save it as a playlist or clear it.
Page {
    id: page

    RemorsePopup {
        id: remorse
    }

    // The new playlist's name.
    Component {
        id: nameDialog

        Dialog {
            canAccept: name.text.trim() !== ""
            onAccepted: R.Api.createPlaylist(name.text.trim(), R.Player.queue.map(function (t) { return t.id }))

            Column {
                width: parent.width

                DialogHeader {
                    //% "Save"
                    acceptText: qsTrId("ryugin-bt-save")
                }
                TextField {
                    id: name

                    width: parent.width
                    focus: true
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
        // Room for the player docked over its end (the pull-down menu owns bottomMargin).
        footer: Item {
            width: 1
            height: R.Player.current ? Theme.itemSizeLarge : 0
        }
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
                onClicked: remorse.execute(qsTrId("ryugin-la-clearing_the_queue"), function () { R.Player.clear() })
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

            contentHeight: Theme.itemSizeMedium
            onClicked: R.Player.jump(model.index)

            menu: ContextMenu {
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

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x - (heart.visible ? heart.width + Theme.paddingMedium : 0)
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
            Icon { // as TrackItem's
                id: heart

                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                visible: !!modelData.starred
                width: Theme.iconSizeExtraSmall
                height: width
                source: R.Icons.silica("heart-fill", Theme.iconSizeExtraSmall, palette.highlightColor) // a heart, as on the desktop
                color: palette.highlightColor
            }
        }

        ViewPlaceholder {
            enabled: R.Player.queue.length === 0
            //% "The queue is empty"
            text: qsTrId("ryugin-la-the_queue_is_empty")
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: list.positionViewAtIndex(Math.max(0, R.Player.index), ListView.Center)
}
