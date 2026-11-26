import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// Search Navidrome: artists, albums and songs, as one types.
Page {
    id: page

    property var result: ({ artists: [], albums: [], songs: [] })
    property string query

    onQueryChanged: _wait.restart()

    Timer {
        id: _wait

        interval: 400
        onTriggered: {
            if (page.query.length < 2) {
                page.result = { artists: [], albums: [], songs: [] }
                return
            }
            var q = page.query
            R.Api.search(q, function (r) {
                if (q === page.query) {
                    page.result = r
                }
            })
        }
    }

    SilicaListView {
        id: list

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        currentIndex: -1
        model: page.result.songs
        // As Sailfish's search pages: a scroll, or a tap away from the results, closes the
        // keyboard.
        onMovementStarted: headerItem.field.focus = false

        MouseArea {
            parent: list.contentItem
            z: -1
            y: list.originY
            width: list.width
            height: Math.max(list.contentHeight, list.height)
            onClicked: list.headerItem.field.focus = false
        }

        header: Column {
            property alias field: field

            width: list.width

            // Its title, as Sailfish's search pages: it also keeps the field clear of the
            // display's notch.
            PageHeader {
                title: "Search"
            }
            SearchField {
                id: field

                width: parent.width
                placeholderText: "Search artists, albums, songs"
                focus: true
                onTextChanged: page.query = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                visible: page.result.artists.length > 0
                text: "Artists"
            }
            Repeater {
                model: page.result.artists

                delegate: BackgroundItem {
                    width: list.width
                    onClicked: pageStack.animatorPush(Qt.resolvedUrl("ArtistPage.qml"), { artistId: modelData.id, name: modelData.name })

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        anchors.verticalCenter: parent.verticalCenter
                        truncationMode: TruncationMode.Fade
                        color: parent.highlighted ? palette.highlightColor : palette.primaryColor
                        text: modelData.name
                    }
                }
            }

            Shelf {
                title: "Albums"
                albums: page.result.albums
            }

            SectionHeader {
                visible: page.result.songs.length > 0
                text: "Songs"
            }
        }

        delegate: TrackItem {
            tracks: page.result.songs
            index: model.index
        }

        VerticalScrollDecorator {}
    }
}
