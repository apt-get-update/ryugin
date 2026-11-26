import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// Every artist, by name, in sections by initial.
Page {
    id: page

    property var artists: []

    Component.onCompleted: R.Api.artists(function (list) {
        page.artists = list.map(function (a) {
            return { id: a.id, name: a.name, albumCount: a.albumCount, initial: (a.name.charAt(0) || "#").toUpperCase() }
        })
    })

    SilicaListView {
        id: list

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        model: ListModel {
            id: rows
        }
        quickScroll: true
        section {
            property: "initial"
            delegate: SectionHeader {
                text: section
            }
        }

        header: PageHeader {
            title: "Artists"
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeSmall
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("ArtistPage.qml"), { artistId: model.id, name: model.name })

            Label {
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: count.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                truncationMode: TruncationMode.Fade
                color: highlighted ? palette.highlightColor : palette.primaryColor
                text: model.name
            }
            Label {
                id: count

                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                color: palette.secondaryColor
                text: model.albumCount
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: page.artists.length === 0 && R.Api.configured
        }

        VerticalScrollDecorator {}
    }

    // A ListModel, for the sections (a JS array has no section property).
    onArtistsChanged: {
        rows.clear()
        for (var i = 0; i < artists.length; i++) {
            rows.append(artists[i])
        }
    }
}
