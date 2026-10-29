import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Peripherals -> Microphone: which mic apps use, its volume and mute (PipeWire,
// through the Audio singleton like the volume popup), a level meter to check it hears you,
// and which apps are listening right now. The meter only runs while this page is open.
GuideTab {
    id: micTab

    readonly property var mics: Audio.inputs
    readonly property var mic: Audio.defaultSource
    readonly property bool hasMic: !!mic && !!mic.audio
    readonly property bool muted: hasMic && mic.audio.muted

    // apps recording from a mic (not monitors of speakers, not this page's own meter)
    readonly property var listeners: {
        let out = [];
        for (const n of Audio.trackedNodes) {
            const p = n && n.properties;
            if (!p || !n.isStream || p["media.class"] !== "Stream/Input/Audio") continue;
            if (String(p["stream.monitor"]) === "true" || p["node.name"] === "quickshell") continue;
            // the program, not its audio library ("Discord", not "WEBRTC VoiceEngine")
            const bin = p["application.process.binary"] || "";
            const name = bin ? bin.charAt(0).toUpperCase() + bin.slice(1) : Audio.getNodeAppName(n);
            if (out.indexOf(name) < 0) out.push(name);
        }
        return out;
    }

    PwNodePeakMonitor {
        id: meter
        node: micTab.mic
        enabled: micTab.isCurrent && micTab.hasMic && !micTab.muted
    }

    // falls quickly to the new peak on the way up, slowly on the way down, like a VU meter
    property real level: 0
    Timer {
        interval: 33
        repeat: true
        running: meter.enabled || micTab.level > 0.001
        onTriggered: {
            const p = meter.enabled ? Math.min(1, meter.peak) : 0;
            micTab.level = p > micTab.level ? p : Math.max(0, micTab.level - 0.03);
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

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: micTab.rootObj
                    settingId: "mic_device"
                    icon: "󰍬"
                    title: "Microphone"
                    description: micTab.mics.length === 0 ? "No microphone found. Plug one in and it shows up here"
                        : "The one apps record from (Discord, games, the browser...) unless they pick their own"
                    searchKeywords: "microphone mic input source device headset record voice default"

                    Dropdown {
                        visible: micTab.mics.length > 0
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(260)
                        implicitHeight: rootObj.s(32)
                        options: micTab.mics.map(n => Audio.getNodeName(n))
                        currentIndex: Math.max(0, micTab.mics.indexOf(micTab.mic))
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        onValueChanged: function(index, value) {
                            const n = micTab.mics[index];
                            if (n && n !== micTab.mic) Audio.setDefaultInput(n);
                        }
                    }
                }

                SettingsRow {
                    rootObj: micTab.rootObj
                    visible: micTab.hasMic
                    settingId: "mic_level"
                    icon: "󰕾"
                    title: "Is it hearing you?"
                    description: micTab.muted ? "The mic is muted" : "Say something: the bar moves with your voice"
                    searchKeywords: "microphone mic test level meter hear check voice"

                    Rectangle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.rightMargin: rootObj.s(8)
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(10)
                        radius: height / 2
                        color: ThemeBackend.surface0

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.sqrt(micTab.level)
                            color: micTab.level > 0.9 ? ThemeBackend.red : micTab.level > 0.55 ? ThemeBackend.peach : ThemeBackend.green
                        }
                    }
                }

                SettingsRow {
                    rootObj: micTab.rootObj
                    visible: micTab.hasMic
                    settingId: "mic_volume"
                    icon: "󰍬"
                    title: "Mic volume"
                    description: "How loud you are to others. Above 100% boosts a quiet mic but adds noise"
                    searchKeywords: "microphone mic volume gain loud quiet boost input level"

                    Draggable {
                        Layout.rightMargin: rootObj.s(8)
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(18)
                        from: 0
                        to: 150
                        stepSize: 1
                        defaultValue: 100
                        showValueBubble: true
                        valueFormatter: function(v) { return Math.round(v) + "%" }
                        value: micTab.hasMic ? Math.round(micTab.mic.audio.volume * 100) : 0
                        backgroundColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        handleColor: ThemeBackend.text
                        handleBorderColor: ThemeBackend.mantle
                        onMoved: function(val) { Audio.setVolume(micTab.mic, val); }
                    }
                }

                SettingsRow {
                    rootObj: micTab.rootObj
                    visible: micTab.hasMic
                    settingId: "mic_mute"
                    icon: "󰍭"
                    title: "Mute"
                    description: "Nobody hears you, in any app"
                    searchKeywords: "microphone mic mute silence off"

                    Toggle {
                        checked: micTab.muted
                        accentColor: ThemeBackend.red
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { if (micTab.hasMic) micTab.mic.audio.muted = c; }
                    }
                }

                SettingsRow {
                    rootObj: micTab.rootObj
                    settingId: "mic_listeners"
                    icon: "󰋎"
                    title: "Listening now"
                    description: micTab.listeners.length > 0 ? micTab.listeners.join(", ") : "No app is using the microphone"
                    searchKeywords: "microphone mic apps using recording privacy listening"
                }
            }
        }
    }
}
