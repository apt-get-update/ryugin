import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// The queue: a tap plays a song, a long press takes it out. Pull down to clear it.
Page {
    id: page

    RemorsePopup {
        id: remorse
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
                text: "Clear queue"
                onClicked: remorse.execute("Clearing the queue", function () { R.Player.clear() })
            }
        }

        header: PageHeader {
            title: "Queue"
            description: R.Player.queue.length + " songs"
        }

        delegate: ListItem {
            id: item

            readonly property bool current: model.index === R.Player.index

            contentHeight: Theme.itemSizeMedium
            onClicked: R.Player.jump(model.index)

            menu: ContextMenu {
                MenuItem {
                    text: "Remove"
                    onClicked: R.Player.removeAt(model.index)
                }
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
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
        }

        ViewPlaceholder {
            enabled: R.Player.queue.length === 0
            text: "The queue is empty"
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: list.positionViewAtIndex(Math.max(0, R.Player.index), ListView.Center)
}
