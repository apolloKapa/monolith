//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick

// top bar: workspaces + stats (left) - clock (centre) - tray + power buttons (right)
// look and feel is controlled from Theme.qml
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: Theme.screens.length === 0 || Theme.screens.indexOf(modelData.name) >= 0
            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.barHeight
            color: "transparent"
            WlrLayershell.namespace: "bar"

            // slide/fade in when the bar starts
            property real shown: 0
            Component.onCompleted: shown = 1
            Behavior on shown { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                opacity: win.shown

                // line along the bottom edge
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: Theme.borderWidth
                    color: Theme.border
                }
            }

            Item {
                anchors { fill: parent; bottomMargin: Theme.borderWidth }
                opacity: win.shown
                transform: Translate { y: (1 - win.shown) * -12 }

                Row {
                    spacing: Theme.spacing
                    anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }

                    BarWorkspaces {
                        visible: Theme.showWorkspaces
                        output: win.modelData.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        visible: Theme.showWorkspaces && Theme.showStats
                        width: Theme.borderWidth
                        height: 18
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    BarStats {
                        visible: Theme.showStats
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BarClock {
                    visible: Theme.showClock
                    anchors.centerIn: parent
                }

                Row {
                    spacing: Theme.spacing
                    anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }

                    BarTray {
                        visible: Theme.showTray
                        window: win
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        visible: Theme.showTray && Theme.showPower
                        width: Theme.borderWidth
                        height: 18
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    BarPower {
                        visible: Theme.showPower
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
