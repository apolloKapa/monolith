import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Effects: Monolith's own touches on every panel. All on by default;
// GameMode switches the surface ones off while a fullscreen app has focus.
GuideTab {
    id: fxTab

    readonly property var items: [
        { id: "unfold", icon: "󰡏", title: "Unfold", desc: "Panels open by unfolding from a thin line through their middle, and fold back into it" },
        { id: "edge", icon: "󰹞", title: "Edge light", desc: "A soft light along the top edge of every panel" },
        { id: "grain", icon: "󰟾", title: "Grain", desc: "A faint film grain over panels, so flat colours look less digital" }
    ]

    property var fx: Config.getSetting("theme", {}).effects || {}

    function setFx(id, on) {
        let theme = Config.getSetting("theme", {});
        let e = Object.assign({}, theme.effects || {});
        e[id] = on;
        theme.effects = e;
        Config.setSetting("theme", theme);
        fxTab.fx = e;
    }

    Connections {
        target: Config
        function onSettingsLoaded() { fxTab.fx = Config.getSetting("theme", {}).effects || {}; }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: col.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    Layout.fillWidth: true
                    rootObj: fxTab.rootObj
                    settingId: "effect_marks"
                    icon: "󰆾"
                    title: "Corner marks"
                    description: "Accent marks inside the corners of panels, popups and the settings window"
                    searchKeywords: "effects corner marks brackets round square arcs"

                    Switch {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(240)
                        implicitHeight: rootObj.s(32)
                        options: ["Off", "Square", "Round"]
                        currentIndex: fxTab.fx.marks === "round" ? 2 : (fxTab.fx.marks === "square" ? 1 : 0)
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.subtext0
                        activeTextColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onToggled: function(index) { fxTab.setFx("marks", ["off", "square", "round"][index]); }
                    }
                }

                Repeater {
                    model: fxTab.items
                    SettingsRow {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        rootObj: fxTab.rootObj
                        settingId: "effect_" + modelData.id
                        icon: modelData.icon
                        title: modelData.title
                        description: modelData.desc
                        searchKeywords: "effects effect unfold animation edge light grain noise film " + modelData.id
                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: fxTab.fx[row.modelData.id] !== false
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) { fxTab.setFx(row.modelData.id, val); }
                        }
                    }
                }
            }
        }
    }
}
