import QtQuick
import QtQuick.Controls

// The desktop's scrollbar (Kvantum draws it) for every scrolling view: always there on
// the desktop when there is more to see, only while scrolling on a phone (as Sailfish does).
ScrollBar {
    objectName: "scrollbar"
    readonly property bool more: size < 1
    policy: !more ? ScrollBar.AlwaysOff : Nav.phone ? ScrollBar.AsNeeded : ScrollBar.AlwaysOn
}
