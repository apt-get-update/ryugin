pragma Singleton
import QtQuick

// Navigation requests from any page; Main.qml acts on them.
QtObject {
    signal openAlbum(string id)
    signal openArtist(string id, string name)
    signal openPlaylist(string id, string name)
    signal home()
    signal search(string query)
    signal focusSearch()
    signal settings()
    property bool lyrics: false
    property bool queue: false
    property bool covered: false // Sailfish OS: minimized, a card on the home screen
    // A phone (a narrow screen, e.g. Sailfish OS): tabs at the bottom, one column.
    property bool phone: Qt.application.screens.length > 0 && Qt.application.screens[0].width < 700 // qmllint disable missing-property
    // The pages on a rail at the left (a desktop, a phone on its side), else tabs at the
    // bottom (a phone upright). Main.qml sets it.
    property bool rail: !phone
}
