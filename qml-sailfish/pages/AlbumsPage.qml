import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R
import "../components"

// Every album, by name, as a grid of covers; pull down to search them (name or artist), as
// Artists.
Page {
    id: page

    property var albums: []
    property bool loaded
    property string filter
    readonly property var shown: {
        var f = filter.toLowerCase()
        return f ? albums.filter(function (a) { return (a.title + " " + a.artist).toLowerCase().indexOf(f) >= 0 }) : albums
    }

    function load() {
        R.Api.allAlbums(function (list) {
            if (!page)
                return // gone before Navidrome answered
            page.albums = list
            page.loaded = true
        })
    }

    Component.onCompleted: load()

    Connections {
        target: R.Api

        function onLibraryChanged() { page.load() } // a scan done, an album hidden
    }

    SilicaGridView {
        id: grid

        anchors.fill: parent
        cellWidth: width / Math.max(2, Math.round(width / (Theme.itemSizeHuge * 1.5)))
        cellHeight: cellWidth + Theme.itemSizeSmall
        model: page.shown
        quickScroll: true
        onMovementStarted: headerItem.field.focus = false // a scroll closes the keyboard

        Pulley {
            MenuItem {
                text: qsTrId("ryugin-me-search")
                onClicked: grid.headerItem.search()
            }
        }

        header: Column {
            property alias field: field

            function search() {
                field.active = true
                field.forceActiveFocus()
                Qt.inputMethod.show() // Keel's field alone opens no keyboard
            }

            width: grid.width

            PageHeader {
                //% "Albums"
                title: qsTrId("ryugin-he-albums")
            }
            SearchField {
                id: field

                width: parent.width
                active: false
                canHide: text.length === 0
                //% "Search albums"
                placeholderText: qsTrId("ryugin-ph-search_albums")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase | Qt.ImhNoPredictiveText
                onTextChanged: page.filter = text
                onHideClicked: active = false
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }
        // Room for the player docked over its end (the pull-down menu owns bottomMargin).
        footer: Item {
            width: 1
            height: R.Player.current ? Theme.itemSizeLarge : 0
        }

        delegate: AlbumTile {
            width: grid.cellWidth
            album: modelData
        }

        PageBusyIndicator {
            running: !page.loaded && R.Api.configured
        }

        ViewPlaceholder {
            enabled: page.loaded && page.shown.length === 0
            text: page.filter
                  ? qsTrId("ryugin-la-no_results")
                  //% "No albums"
                  : qsTrId("ryugin-la-no_albums")
            hintText: page.filter ? "" : R.Api.error
        }

        VerticalScrollDecorator {}
    }
}
