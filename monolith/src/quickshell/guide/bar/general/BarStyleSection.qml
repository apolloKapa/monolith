import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsGroup {
        rootObj: section.tab.rootObj
        icon: "󰏘"
        title: I18n.t("guide.bar.style.title")
        description: I18n.t("guide.bar.style.desc_long", "Modular: separate floating pills. Solid: one bar. Fill: a bar joined to the screen edge. Island: one pill in the middle. Frame: the bar plus a border round the whole screen")
        expanded: section.tab.barStyle === "solid" || section.tab.barStyle === "fill"
        wrapText: true

        // the styles as little pictures; click one to use it
        Flow {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.maximumWidth: rootObj.s(560)
            spacing: rootObj.s(8)

            Repeater {
                model: [
                    { id: "modular", name: I18n.t("guide.bar.style.modular") },
                    { id: "solid", name: I18n.t("guide.bar.style.solid") },
                    { id: "fill", name: I18n.t("guide.bar.style.fill") },
                    { id: "island", name: I18n.t("guide.bar.style.island") },
                    { id: "frame", name: I18n.t("guide.bar.style.frame") }
                ]
                Rectangle {
                    id: styleCard
                    required property var modelData
                    readonly property bool selected: section.tab.barStyle === modelData.id
                    width: rootObj.s(104)
                    height: cardCol.implicitHeight + rootObj.s(12)
                    radius: ThemeBackend.square ? 0 : rootObj.s(12)
                    color: selected ? Qt.alpha(ThemeBackend.mauve, 0.16) : (cardMa.containsMouse ? Qt.alpha(ThemeBackend.text, 0.06) : "transparent")
                    border.width: selected ? 2 : 1
                    border.color: selected ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.12)

                    Column {
                        id: cardCol
                        anchors.centerIn: parent
                        spacing: rootObj.s(4)
                        BarPreview {
                            width: rootObj.s(92)
                            height: implicitHeight
                            style: styleCard.modelData.id
                            position: "top"
                            zoom: 2.6
                            thickness: 40
                            pillGap: 6
                            sectionGap: 20
                            frameThickness: 14
                            showWindows: false
                            landscape: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: styleCard.modelData.name
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                            font.weight: styleCard.selected ? Font.DemiBold : Font.Normal
                            color: ThemeBackend.text
                        }
                    }
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            section.tab.clearPendingGroup();
                            section.tab.barStyle = styleCard.modelData.id;
                            section.tab.updateBarSettings();
                        }
                    }
                }
            }
        }

        subSettings: [
            SettingsRow {
                rootObj: section.tab.rootObj
                icon: "󰍜"
                title: I18n.t("guide.bar.distinct_pills.title")
                description: I18n.t("guide.bar.distinct_pills.desc")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: section.tab.distinctPills
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        section.tab.clearPendingGroup();
                        section.tab.distinctPills = c;
                        section.tab.updateBarSettings();
                    }
                }
            }
        ]
    }
}
