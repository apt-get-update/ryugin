import QtQuick 2.6
import Sailfish.Silica 1.0
import Nemo.FileManager 1.0

// Settings › Apps › Ryūgin (Sailfish's Settings app, its Qt 5 Silica): what Ryūgin keeps on
// the phone, the songs and the covers, each with its size and a way to clear it.
Page {
    id: page

    readonly property string cache: StandardPaths.home + "/.cache/dragon/ryugin/ryugin/"
    property var sizes: ({})

    function measure() {
        usage.calculate([cache + "songs", cache + "covers"], function (u) {
            page.sizes = u
        })
    }

    function size(dir) {
        var bytes = sizes[cache + dir]
        return bytes === undefined ? "…" : Format.formatFileSize(bytes)
    }

    // Ryūgin makes the folder again when it next keeps a file.
    function clear(dir, what) {
        remorse.execute(what, function () {
            FileEngine.deleteFiles([cache + dir], true)
        })
    }

    Component.onCompleted: measure()

    DiskUsage {
        id: usage
    }

    Connections {
        target: FileEngine
        onWorkerDone: page.measure()
    }

    RemorsePopup {
        id: remorse
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column

            width: parent.width

            PageHeader {
                title: "Ryūgin"
            }

            SectionHeader {
                text: "Kept on the phone"
            }
            DetailItem {
                label: "Songs"
                value: page.size("songs")
            }
            DetailItem {
                label: "Covers"
                value: page.size("covers")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                topPadding: Theme.paddingMedium
                bottomPadding: Theme.paddingLarge
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: "Songs played to the end (with Keep songs on, in Ryūgin's settings) and album covers, to play and show them without the network."
            }

            ButtonLayout {
                Button {
                    text: "Clear songs"
                    onClicked: page.clear("songs", "Clearing songs")
                }
                Button {
                    text: "Clear covers"
                    onClicked: page.clear("covers", "Clearing covers")
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
