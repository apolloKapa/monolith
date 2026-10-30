import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Animations: on/off, speed presets, fine speed, niri window animations,
// and a live preview. Stored as theme.animations = { enabled, speed, niri }.
GuideTab {
    id: animTab

    readonly property var presets: [
        { name: "Slow", speed: 0.65 },
        { name: "Normal", speed: 1.0 },
        { name: "Fast", speed: 1.6 }
    ]

    property var anim: (Config.getSetting("theme", {}).animations) || {}
    property bool animOn: anim.enabled !== false
    property real speed: anim.speed !== undefined ? Number(anim.speed) : 1.0
    property bool niri: anim.niri !== false
    readonly property bool niriSession: NiriState.isNiri

    function presetIndex() {
        let best = 1, bestDiff = 1e9;
        for (let i = 0; i < presets.length; i++) {
            const d = Math.abs(presets[i].speed - speed);
            if (d < bestDiff) { bestDiff = d; best = i; }
        }
        return best;
    }

    function save() {
        let theme = Config.getSetting("theme", {});
        theme.animations = { "enabled": animTab.animOn, "speed": animTab.speed, "niri": animTab.niri };
        Config.setSetting("theme", theme);
        applyNiri();
    }

    // same speed for niri's window animations (edits the animations block in ~/.config/niri)
    function applyNiri() {
        if (!animTab.niriSession || !Caching.monolithDir) return;
        const value = !animTab.niri ? "1" : (animTab.animOn ? animTab.speed.toFixed(2) : "off");
        Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/niri_animations.sh", value]);
    }

    Timer {
        id: saveDebounce
        interval: 250
        onTriggered: animTab.save()
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            animTab.anim = (Config.getSetting("theme", {}).animations) || {};
            animTab.animOn = animTab.anim.enabled !== false;
            animTab.speed = animTab.anim.speed !== undefined ? Number(animTab.anim.speed) : 1.0;
            animTab.niri = animTab.anim.niri !== false;
        }
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

            // live preview: a pill sliding across at the current speed
            SettingsBlob {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(96)

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: rootObj.s(20)
                        height: rootObj.s(44)
                        radius: ThemeBackend.rad(height / 2)
                        color: Qt.alpha(ThemeBackend.surface1, 0.6)
                        border.width: ThemeBackend.outlineInner
                        border.color: ThemeBackend.outlineColor

                        Rectangle {
                            id: pill
                            width: rootObj.s(88)
                            height: parent.height - rootObj.s(8)
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootObj.s(4)
                            radius: ThemeBackend.rad(height / 2)
                            color: ThemeBackend.mauve
                            scale: 1.0

                            Text {
                                anchors.centerIn: parent
                                text: !animTab.animOn ? "off" : (animTab.speed.toFixed(2) + "×")
                                color: ThemeBackend.crust
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                font.bold: true
                            }
                        }

                        // written by hand (not scaled by the global pass): it shows the scale
                        SequentialAnimation {
                            running: animTab.visible && animTab.animOn
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) pill.x = rootObj.s(4)
                            NumberAnimation { target: pill; property: "x"; to: track.width - pill.width - rootObj.s(4); duration: 700 / Math.max(0.25, animTab.speed); easing.type: Easing.OutCubic }
                            NumberAnimation { target: pill; property: "scale"; to: 1.12; duration: 140 / Math.max(0.25, animTab.speed); easing.type: Easing.OutQuad }
                            NumberAnimation { target: pill; property: "scale"; to: 1.0; duration: 220 / Math.max(0.25, animTab.speed); easing.type: Easing.OutBack }
                            PauseAnimation { duration: 350 }
                            NumberAnimation { target: pill; property: "x"; to: rootObj.s(4); duration: 700 / Math.max(0.25, animTab.speed); easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 350 }
                        }
                    }
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: animTab.rootObj
                    settingId: "animations_enabled"
                    icon: "󰔡"
                    title: "Animations"
                    description: animTab.animOn ? "Panels, popups and buttons animate" : "Everything changes instantly"
                    searchKeywords: "animation animations motion reduce motion off disable instant transitions"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: animTab.animOn
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            animTab.animOn = val;
                            animTab.save();
                        }
                    }
                }

                SettingsRow {
                    rootObj: animTab.rootObj
                    settingId: "animations_speed"
                    icon: "󰓅"
                    title: "Speed"
                    description: "Slow, normal or fast animations"
                    searchKeywords: "animation speed slow normal fast quick snappy"
                    hiddenByConfig: !animTab.animOn
                    unavailableReason: "Turn animations on to change their speed"

                    Switch {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(240)
                        implicitHeight: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        enabled: animTab.animOn
                        options: animTab.presets.map(p => p.name)
                        currentIndex: animTab.presetIndex()
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        onValueChanged: function(index, value) {
                            animTab.speed = animTab.presets[index].speed;
                            animTab.save();
                        }
                    }
                }

                SettingsRow {
                    rootObj: animTab.rootObj
                    settingId: "animations_fine_speed"
                    icon: "󰔛"
                    title: "Fine-tune speed"
                    description: "100% is normal. Higher is faster"
                    searchKeywords: "animation speed percent custom slider duration"
                    hiddenByConfig: !animTab.animOn
                    unavailableReason: "Turn animations on to change their speed"

                    Draggable {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.rightMargin: rootObj.s(8)
                        implicitWidth: rootObj.s(220)
                        implicitHeight: rootObj.s(18)
                        enabled: animTab.animOn
                        from: 50
                        to: 200
                        stepSize: 5
                        defaultValue: 100
                        showValueBubble: true
                        valueFormatter: function(v) { return Math.round(v) + "%" }
                        value: Math.round(animTab.speed * 100)
                        backgroundColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        handleColor: ThemeBackend.text
                        handleBorderColor: ThemeBackend.mantle
                        onMoved: function(val) {
                            animTab.speed = Math.round(val) / 100;
                            saveDebounce.restart();
                        }
                        onDragFinished: {
                            saveDebounce.stop();
                            animTab.save();
                        }
                    }
                }

                SettingsRow {
                    rootObj: animTab.rootObj
                    settingId: "animations_niri"
                    icon: "󰖲"
                    title: "Window animations"
                    description: "Use the same setting for niri's windows, workspaces and overview"
                    searchKeywords: "niri window animations workspace overview compositor slowdown"
                    hiddenByConfig: !animTab.niriSession
                    unavailableReason: "Only available on niri"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: animTab.niri
                        enabled: animTab.niriSession
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            animTab.niri = val;
                            animTab.save();
                        }
                    }
                }

                SettingsRow {
                    rootObj: animTab.rootObj
                    settingId: "game_mode"
                    icon: "󰊴"
                    title: "GameMode"
                    description: "While a fullscreen app has focus (games, videos), turn off animations, blur and liquid glass (panels go solid), the quick actions panel, video wallpapers and the music visualizer so the shell costs nothing. The Game mode button in the system panel turns it on any time"
                    searchKeywords: "game mode gaming fullscreen performance fps effects blur glass animations battery"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: Config.getSetting("theme", {}).gameMode !== false
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            let theme = Config.getSetting("theme", {});
                            theme.gameMode = val;
                            Config.setSetting("theme", theme);
                        }
                    }
                }
            }
        }

        WheelScroll {}
    }
}
