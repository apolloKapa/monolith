import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    // position and look: edit here
    readonly property string screenName: "DP-1"
    readonly property int topMargin: 48
    readonly property int rightMargin: 10
    readonly property int cardWidth: 360
    readonly property int slideMs: 200
    readonly property color bg: "#1a1a1a"
    readonly property color border: "#555555"
    readonly property color urgent: "#9b0000"
    readonly property color text: "#ffffff"
    readonly property color dim: "#a0a0a0"
    readonly property string font: "JetBrains Mono"

    NotificationServer {
        id: server
        bodySupported: true
        imageSupported: false
        onNotification: n => { n.tracked = true }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        margins { top: root.topMargin; right: root.rightMargin }
        implicitWidth: root.cardWidth
        implicitHeight: Math.max(1, col.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "notifs"

        Column {
            id: col
            width: root.cardWidth
            Repeater {
                model: server.trackedNotifications
                delegate: Item {
                    id: card
                    required property var modelData
                    property bool leaving: false
                    width: root.cardWidth
                    height: box.height + 8

                    function leave() {
                        if (leaving) return
                        leaving = true
                        box.x = root.cardWidth
                        box.opacity = 0
                        gone.start()
                    }
                    Timer { id: gone; interval: root.slideMs + 40; onTriggered: card.modelData.dismiss() }
                    Timer {
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout * 1000 : 5000
                        onTriggered: card.leave()
                    }

                    Rectangle {
                        id: box
                        x: root.cardWidth
                        width: root.cardWidth
                        height: content.implicitHeight + 24
                        color: root.bg
                        border.width: 2
                        border.color: card.modelData.urgency === NotificationUrgency.Critical ? root.urgent : root.border
                        Behavior on x { NumberAnimation { duration: root.slideMs; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: root.slideMs } }
                        Component.onCompleted: x = 0

                        Column {
                            id: content
                            x: 14
                            y: 12
                            width: parent.width - 28
                            spacing: 4
                            Text {
                                width: parent.width
                                text: card.modelData.appName
                                color: root.dim
                                font.family: root.font
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: card.modelData.summary
                                color: root.text
                                font.family: root.font
                                font.pixelSize: 14
                                font.bold: true
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: card.modelData.body
                                color: root.dim
                                font.family: root.font
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: card.leave() }
                    }
                }
            }
        }
    }
}
