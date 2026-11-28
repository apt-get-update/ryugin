import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// Search Navidrome: artists, albums and songs, as one types.
Page {
    id: page

    property var result: ({ artists: [], albums: [], songs: [] })
    property string query
    property string searched // the query result answers
    // Two letters at least; one kanji or kana is a word already (龍).
    readonly property bool enough: query.length > 1 || /[^\u0000-\u024f]/.test(query)
    readonly property bool empty: result.artists.length + result.albums.length + result.songs.length === 0

    onQueryChanged: _wait.restart()
    // The pulley's Search: the field and the keyboard ready (Keel's field alone opens no keyboard).
    onStatusChanged: {
        if (status === PageStatus.Active && !query) {
            list.headerItem.field.forceActiveFocus()
            Qt.inputMethod.show()
        }
    }

    Timer {
        id: _wait

        interval: 400
        onTriggered: {
            if (!page.enough) {
                page.result = { artists: [], albums: [], songs: [] }
                page.searched = ""
                return
            }
            var q = page.query
            R.Api.search(q, function (r) {
                if (page && q === page.query) {
                    page.result = r
                    page.searched = q
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
                //% "Search"
                title: qsTrId("ryugin-he-search")
            }
            SearchField {
                id: field

                width: parent.width
                //% "Search artists, albums, songs"
                placeholderText: qsTrId("ryugin-ph-search_artists_albums_songs")
                onTextChanged: page.query = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            SectionHeader {
                visible: page.result.artists.length > 0
                //% "Artists"
                text: qsTrId("ryugin-he-artists")
            }
            Repeater {
                model: page.result.artists

                delegate: BackgroundItem {
                    width: list.width
                    onClicked: R.Nav.openArtist(modelData.id, modelData.name)

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
                //% "Albums"
                title: qsTrId("ryugin-he-albums")
                albums: page.result.albums
            }

            SectionHeader {
                visible: page.result.songs.length > 0
                //% "Songs"
                text: qsTrId("ryugin-he-songs")
            }
        }

        delegate: TrackItem {
            tracks: page.result.songs
            index: model.index
        }

        PageBusyIndicator {
            running: page.enough && page.searched !== page.query
        }

        ViewPlaceholder {
            enabled: page.searched !== "" && page.searched === page.query && page.empty
            //% "No results"
            text: qsTrId("ryugin-la-no_results")
        }

        VerticalScrollDecorator {}
    }
}
