import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../core"

// One notification: the app's icon (or the notification's image) in a bubble, the summary
// and body, and its actions as chips. Click runs the default action; × dismisses.
Pressable {
    id: card
    required property var notif
    property bool popup: false
    signal closed()

    implicitHeight: body.implicitHeight + 24
    radius: Theme.corner(56, 6)
    color: popup ? Theme.card : Theme.containerHigh
    border.width: popup ? 1 : 0
    border.color: Theme.hairline

    readonly property string iconSrc: notif.image !== "" ? notif.image
        : (notif.appIcon !== "" ? (notif.appIcon.startsWith("/") || notif.appIcon.startsWith("file:") ? notif.appIcon : Quickshell.iconPath(notif.appIcon, true)) : "")
    readonly property bool urgent: notif.urgency === NotificationUrgency.Critical

    onClicked: {
        const def = notif.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        card.closed();
    }

    RowLayout {
        id: body
        x: 12; y: 12
        width: parent.width - 24
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.corner(40, 4)
            color: card.urgent ? Qt.alpha(Theme.danger, 0.3) : Theme.control
            clip: true
            Image {
                anchors.centerIn: parent
                width: card.notif.image !== "" ? parent.width : 24
                height: width
                source: card.iconSrc
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }
            Icon { anchors.centerIn: parent; name: card.urgent ? "priority_high" : "notifications"; size: 20; visible: card.iconSrc === "" }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Label { text: card.notif.appName || "Notification"; muted: true; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Pressable {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    color: "transparent"
                    onClicked: { card.notif.dismiss(); card.closed(); }
                    Icon { anchors.centerIn: parent; name: "close"; size: 16; color: Theme.subtext }
                }
            }
            Label { Layout.fillWidth: true; text: card.notif.summary; strong: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif.body
                textFormat: Text.StyledText
                muted: true
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 3 : 6
                font.pixelSize: Theme.sizeSmall + 1
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: card.notif.actions.filter(a => a.identifier !== "default").length > 0
                Repeater {
                    model: card.notif.actions.filter(a => a.identifier !== "default")
                    Pressable {
                        required property var modelData
                        height: 30
                        width: actLabel.implicitWidth + 24
                        color: Theme.selected
                        onClicked: { modelData.invoke(); card.closed(); }
                        Label { id: actLabel; anchors.centerIn: parent; text: modelData.text; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
        }
    }
}
