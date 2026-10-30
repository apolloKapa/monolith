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

            // a sample panel wearing the effects that are on, so you can see what each one does
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(170)
                radius: ThemeBackend.square ? 0 : ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)

                Rectangle {
                    id: fxSample
                    anchors.centerIn: parent
                    width: rootObj.s(300)
                    height: rootObj.s(120)
                    radius: ThemeBackend.square ? 0 : rootObj.s(18)
                    color: ThemeBackend.base
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.text, 0.08)
                    // unfold: the panel opens from a line, replayed every few seconds
                    property real unfold: 1
                    transform: Scale { origin.y: fxSample.height / 2; yScale: 0.04 + 0.96 * fxSample.unfold }
                    SequentialAnimation on unfold {
                        running: ThemeBackend.fxUnfold && fxTab.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2200 }
                        NumberAnimation { to: 0; duration: 220; easing.type: Easing.InCubic }
                        PauseAnimation { duration: 250 }
                        NumberAnimation { to: 1; duration: 420; easing.type: Easing.OutCubic }
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: ThemeBackend.fxGrain
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real radius: fxSample.radius
                        property real amount: 0.09
                        property real seed: 0
                        fragmentShader: Caching.monolithDir ? ("file://" + Caching.monolithDir + "/assets/shaders/effects/surface_grain.frag.qsb") : ""
                    }
                    Rectangle {
                        visible: ThemeBackend.fxEdge
                        x: fxSample.radius * 0.6
                        width: parent.width - fxSample.radius * 1.2
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.alpha(ThemeBackend.text, 0.5) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    Repeater {
                        model: ThemeBackend.fxMarks !== "off" ? 4 : 0
                        Rectangle {
                            readonly property bool atRight: index % 2 === 1
                            readonly property bool atBottom: index >= 2
                            readonly property real inset: rootObj.s(10)
                            width: rootObj.s(12); height: rootObj.s(12)
                            x: atRight ? fxSample.width - inset - width : inset
                            y: atBottom ? fxSample.height - inset - height : inset
                            color: "transparent"
                            radius: ThemeBackend.fxMarks === "round" ? width : 0
                            border.width: 1.5
                            border.color: Qt.alpha(ThemeBackend.mauve, 0.8)
                            // only the two outer sides of each corner
                            Rectangle { x: parent.atRight ? -2 : parent.width * 0.5; y: parent.atBottom ? -2 : parent.height * 0.5; width: parent.width * 0.5 + 2; height: parent.height * 0.5 + 2; color: ThemeBackend.base }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: rootObj.s(6)
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("guide.theme.effects.sample", "A panel"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(15); color: ThemeBackend.text }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.t("guide.theme.effects.sample_desc", "with the effects that are on"); font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(11); color: ThemeBackend.subtext0 }
                    }
                }
            }

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

        WheelScroll {}
    }
}
