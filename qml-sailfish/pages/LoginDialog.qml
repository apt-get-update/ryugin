import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The Navidrome server: its address, the user and the password (only a token is kept).
// Accept connects; a failure shows on Settings' Server row (the dialog is gone by then).
Dialog {
    id: dialog

    canAccept: url.text !== "" && user.text !== "" && pass.text !== ""

    onAccepted: R.Api.login(url.text, user.text, pass.text, function () {})

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column

            width: parent.width

            DialogHeader {
                //% "Connect"
                acceptText: qsTrId("ryugin-bt-connect")
            }

            TextField {
                id: url

                width: parent.width
                //% "Server address"
                label: qsTrId("ryugin-la-server_address")
                placeholderText: "https://music.example.org"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                text: R.Api.settings.url
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: user.focus = true
            }
            TextField {
                id: user

                width: parent.width
                //% "User"
                label: qsTrId("ryugin-la-user")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                text: R.Api.settings.user
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: pass.focus = true
            }
            PasswordField {
                id: pass

                width: parent.width
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }
        }
    }
}
