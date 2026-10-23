import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "modules"

BarModulesSettings {
    id: barModulesRoot
    subTabIndex: 1
    // the module whose settings are shown (picked from the tiles at the top)
    property int selectedModule: 0

    function inView(item) {
        if (!item || !visible) return false;
        void modulesFlick.contentY;
        void modulesFlick.contentHeight;
        void modulesFlick.height;
        void item.y;
        void item.height;
        const top = item.mapToItem(modulesFlick.contentItem, 0, 0).y;
        const margin = modulesFlick.height * 0.5;
        return top + item.height > modulesFlick.contentY - margin && top < modulesFlick.contentY + modulesFlick.height + margin;
    }

    Flickable {
        id: modulesFlick
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: modulesCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: ThemeBackend.rad(rootObj.s(2))
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: modulesCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            // pick a module, then edit it below (instead of one long list of every module)
            Text {
                Layout.leftMargin: rootObj.s(4)
                text: I18n.t("guide.bar.modules.pick", "Pick a module to change how it looks on the bar")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(13)
                color: ThemeBackend.subtext0
            }
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(3, Math.floor(width / rootObj.s(118)))
                columnSpacing: rootObj.s(8)
                rowSpacing: rootObj.s(8)
                Repeater {
                    model: [
                        { name: I18n.t("guide.bar.modules.tile.0", "Actions"), icon: "󰍜" },
                        { name: I18n.t("guide.bar.modules.tile.1", "Workspaces"), icon: "󰮯" },
                        { name: I18n.t("guide.bar.modules.tile.2", "Time & date"), icon: "󰥔" },
                        { name: I18n.t("guide.bar.modules.tile.3", "Visualizer"), icon: "󰝚" },
                        { name: I18n.t("guide.bar.modules.tile.4", "System monitor"), icon: "󰍛" },
                        { name: I18n.t("guide.bar.modules.tile.5", "Battery"), icon: "󰁹" },
                        { name: I18n.t("guide.bar.modules.tile.6", "Network"), icon: "󰤨" },
                        { name: I18n.t("guide.bar.modules.tile.7", "Bluetooth"), icon: "󰂯" },
                        { name: I18n.t("guide.bar.modules.tile.8", "Volume"), icon: "󰕾" },
                        { name: I18n.t("guide.bar.modules.tile.9", "Keyboard"), icon: "󰌌" },
                        { name: I18n.t("guide.bar.modules.tile.10", "Media"), icon: "󰎈" }
                    ]
                    Rectangle {
                        id: modTile
                        required property var modelData
                        required property int index
                        readonly property bool selected: barModulesRoot.selectedModule === index
                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(76)
                        radius: ThemeBackend.square ? 0 : rootObj.s(16)
                        color: selected ? (ThemeBackend.material ? ThemeBackend.secondaryContainer : Qt.alpha(ThemeBackend.mauve, 0.2))
                                        : (tileMa.containsMouse ? Qt.alpha(ThemeBackend.text, 0.07) : Qt.alpha(ThemeBackend.surface0, 0.45))
                        border.width: selected ? 2 : 0
                        border.color: ThemeBackend.mauve
                        Column {
                            anchors.centerIn: parent
                            spacing: rootObj.s(6)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modTile.modelData.icon
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: rootObj.s(22)
                                color: modTile.selected ? ThemeBackend.mauve : ThemeBackend.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modTile.modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                font.weight: modTile.selected ? Font.DemiBold : Font.Normal
                                color: ThemeBackend.text
                            }
                        }
                        MouseArea {
                            id: tileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { barModulesRoot.selectedModule = modTile.index; modulesFlick.contentY = 0; }
                        }
                    }
                }
            }

            BarMenuCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 0 }

            BarWorkspacesCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 1 }

            BarTimeDateCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 2 }

            BarVisualizerCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 3 }

            BarSysmonCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 4 }

            BarBatteryCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 5 }

            BarNetworkCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 6 }

            BarBluetoothCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 7 }

            BarVolumeCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 8 }

            BarKeyboardCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 9 }

            BarMediaCard { tab: barModulesRoot; visible: barModulesRoot.selectedModule === 10 }
        }
    }
}
