import QtQuick 2.0
import QtQuick.Effects
import Sailfish.Silica 1.0
import "../../qml" as R

// The song's cover as the app's wallpaper (ryugin.qml: under every page), treated as
// Sailfish treats the ambience's behind an app (Keel's ApplicationWindow and its
// keelambience image provider): at an eighth of the window, blurred about 7.5% of its
// width, toned to the scheme (black 62%, or white 45%), tinted with the highlight
// dimmer, dithered as glass. Shown while the app follows the song's colours. A new cover
// fades in over the last. Drawn once into a picture, kept until the cover changes (not
// blurred again each frame).
SilicaItem {
    id: backdrop

    readonly property bool _light: Theme.colorScheme === Theme.DarkOnLight
    readonly property string _source: R.Player.current ? R.Api.cover(R.Player.current.cover, 256) : ""
    property bool _second

    visible: R.Theme.settings.followCover && R.Player.current !== null
    clip: true
    layer.enabled: visible
    palette.highlightDimmerColor: pageStack.palette.highlightDimmerColor

    on_SourceChanged: {
        if (covers.count === 2) {
            _second = !_second
            covers.itemAt(_second ? 1 : 0).source = _source
        }
    }

    Item {
        id: wallpaper

        anchors.fill: parent
        visible: false

        Repeater {
            id: covers

            model: 2

            // Filling the page 1.5x, as 1.2's player (wash.frag): a cover's own black
            // bands stay out.
            Image {
                anchors.centerIn: parent
                width: 1.5 * parent.width
                height: 1.5 * parent.height
                fillMode: Image.PreserveAspectCrop
                sourceSize {
                    width: width / 8
                    height: height / 8
                }
                smooth: true
                asynchronous: true
                opacity: (index === 1) === backdrop._second && status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    FadeAnimator {
                        duration: 500
                    }
                }
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
    }

    Rectangle {
        anchors.fill: parent
        color: backdrop._light ? "white" : "black"
        opacity: backdrop._light ? 0.45 : 0.62
    }
    Rectangle {
        anchors.fill: parent
        visible: !backdrop._light
        color: backdrop.palette.highlightDimmerColor
        opacity: 0.12
    }
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/Sailfish/Silica/ambience/glass-dither.png"
        fillMode: Image.Tile
        smooth: false
        opacity: backdrop._light ? 0.6 : 1.0
    }

    Component.onCompleted: covers.itemAt(0).source = _source
}
