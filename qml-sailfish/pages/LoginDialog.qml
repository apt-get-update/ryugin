import QtQuick 2.0
import Sailfish.Silica 1.0
import "../../qml" as R

// The Navidrome server: its address, the user and the password (only a token is kept).
// Accept connects; a failure keeps the dialog open with the error.
Dialog {
    id: dialog

    property string error

    canAccept: url.text !== "" && user.text !== "" && pass.text !== ""
    acceptDestinationAction: PageStackAction.Pop

    onAccepted: R.Api.login(url.text, user.text, pass.text, function (err) {
        if (err) {
            pageStack.push(dialog, {}, PageStackAction.Immediate)
            dialog.error = R.Api.error
        }
    })

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
            Label {
                visible: dialog.error !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.errorColor
                //% "Could not connect"
                text: qsTrId("ryugin-la-could_not_connect") + "\n" + dialog.error
            }
        }
    }
}
