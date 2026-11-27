import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0 as Private
import "../../qml" as R
import "../components"

// Every artist, by name, in sections by initial, as Sailfish's Media app lists them: the
// pulley's Search opens a field that filters the list, the scrollbar shows the letter it
// is at, a scroll closes the keyboard.
Page {
    id: page

    property var artists: []
    property string filter

    Component.onCompleted: R.Api.artists(function (list) {
        page.artists = list.map(function (a) {
            return { id: a.id, name: a.name, albumCount: a.albumCount, initial: (a.name.charAt(0) || "#").toUpperCase() }
        })
    })

    // A ListModel, for the sections (a JS array has no section property).
    function fill() {
        var f = filter.toLowerCase()
        rows.clear()
        for (var i = 0; i < artists.length; i++) {
            if (!f || artists[i].name.toLowerCase().indexOf(f) >= 0) {
                rows.append(artists[i])
            }
        }
    }
    onArtistsChanged: fill()
    onFilterChanged: fill()

    SilicaListView {
        id: list

        anchors.fill: parent
        bottomMargin: R.Player.current ? Theme.itemSizeLarge : 0 // the player docked over its end
        model: ListModel {
            id: rows
        }
        // As Sailfish's search pages: a scroll, or a tap away from the rows, closes the keyboard.
        onMovementStarted: headerItem.field.focus = false

        MouseArea {
            parent: list.contentItem
            z: -1
            y: list.originY
            width: list.width
            height: Math.max(list.contentHeight, list.height)
            onClicked: list.headerItem.field.focus = false
        }
        section {
            property: page.filter ? "" : "initial"
            delegate: SectionHeader {
                text: section
            }
        }

        Pulley {
            MenuItem {
                //% "Search"
                text: qsTrId("ryugin-me-search")
                onClicked: list.headerItem.search()
            }
        }

        header: Column {
            property alias field: field

            function search() {
                field.active = true
                field.forceActiveFocus()
                Qt.inputMethod.show() // Keel's field alone opens no keyboard
            }

            width: list.width

            PageHeader {
                //% "Artists"
                title: qsTrId("ryugin-he-artists")
            }
            SearchField {
                id: field

                width: parent.width
                active: false
                canHide: text.length === 0
                //% "Search artists"
                placeholderText: qsTrId("ryugin-ph-search_artists")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase | Qt.ImhNoPredictiveText
                onTextChanged: page.filter = text
                onHideClicked: active = false
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
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
                text: page.filter ? Theme.highlightText(model.name, page.filter, palette.highlightColor) : model.name
                textFormat: page.filter ? Text.StyledText : Text.PlainText
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

        // Media's scrollbar: drag it to go through the list, the letter of the first row seen
        // on it.
        Private.Scrollbar {
            headerHeight: list.headerItem ? list.headerItem.height : 0
            text: {
                var y = list.contentY + Theme.itemSizeExtraSmall
                var i = list.indexAt(list.width / 2, y)
                if (i < 0) {
                    i = list.indexAt(list.width / 2, y + Theme.itemSizeExtraSmall) // on a section's header
                }
                return i < 0 || i >= rows.count ? "" : " " + rows.get(i).initial + " " // spaces: easier to grab
            }
        }
    }
}
