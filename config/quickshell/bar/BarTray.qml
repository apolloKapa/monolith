import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Row {
    id: root
    property var window
    spacing: Theme.spacing

    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: slot
            required property var modelData
            width: Theme.trayIcon
            height: Theme.trayIcon

            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutBack
                }
            }

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(48, 48)
                source: slot.modelData.icon
                opacity: area.containsMouse ? 1.0 : 0.8
                scale: area.containsMouse ? 1.18 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        if (slot.modelData.onlyMenu && slot.modelData.hasMenu) {
                            // apps that only have a menu (no left-click action)
                            openMenu(mouse)
                        } else {
                            slot.modelData.activate()
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        slot.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton && slot.modelData.hasMenu) {
                        openMenu(mouse)
                    }
                }

                function openMenu(mouse) {
                    // map icon bottom-left into the panel window
                    const p = slot.mapToItem(root.window.contentItem, 0, slot.height)
                    slot.modelData.display(root.window, p.x, p.y)
                }
            }
        }
    }
}
