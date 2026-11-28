pragma Singleton
import QtQuick
import QtCore

// Navigation requests from any page; Main.qml acts on them (Sailfish OS: ryugin.qml).
QtObject {
    // Sailfish OS: a page of qml-sailfish/pages by name (a signal takes all its arguments,
    // so props is optional here).
    signal openPage(string page, var props)
    function open(page, props) { openPage(page, props || {}); }
    signal openAlbum(string id)
    signal openArtist(string id, string name)
    signal openPlaylist(string id, string name)
    signal home()
    signal back() // a page's back arrow
    signal search(string query)
    signal focusSearch()
    // Search asked (Ctrl+F, the rail's search): a folded sidebar opens for its field, and
    // folds again when Escape leaves it (refold).
    property bool refold: false
    function openSearch() {
        if (layout.folded) {
            refold = true;
            layout.folded = false;
        }
        Qt.callLater(focusSearch);
    }
    property bool lyrics: false
    property bool queue: false
    // A phone (a narrow screen, e.g. Sailfish OS): tabs at the bottom, one column.
    property bool phone: Qt.application.screens.length > 0 && Qt.application.screens[0].width < 700 // qmllint disable missing-property
    // The pages on a rail at the left (a desktop, a phone on its side), else tabs at the
    // bottom (a phone upright). Main.qml sets it.
    property bool rail: !phone
    // The sidebar: its width (dragged by its edge), or folded to an icon rail (F9, its fold
    // button, or dragged narrow).
    component Prefs: Settings {
        category: "layout"
        property int sideWidth: 208
        property bool folded: false
        // Home's rows, in order, and the ones hidden (Settings › Home).
        property string homeOrder: "recentSongs recent frequent newest"
        property string homeHidden: ""
        property int queueWidth: 360
    }
    readonly property var homeRows: ({ recentSongs: /*% "Recently played" */ qsTrId("ryugin-he-recently_played"), recent: /*% "Recent albums" */ qsTrId("ryugin-he-recent_albums"), frequent: /*% "Most played" */ qsTrId("ryugin-he-most_played"), newest: /*% "Recently added" */ qsTrId("ryugin-he-recently_added") })
    readonly property Prefs layout: Prefs {}
}
