import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Services.Pipewire
import "../../core"
import "../../ui"

// Mic & camera: which microphone is used and how loud, and a look through the camera.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var mics: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [Pipewire.defaultAudioSource] }

    Label { text: "Microphone"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
    SettingRow {
        icon: sec.mic && sec.mic.audio && sec.mic.audio.muted ? "mic_off" : "mic"; title: "Level"; desc: sec.mic ? (sec.mic.description || sec.mic.name) : "No microphone"
        Slider {
            width: 240; implicitHeight: 36
            icon: sec.mic && sec.mic.audio && sec.mic.audio.muted ? "mic_off" : "mic"
            muted: !!(sec.mic && sec.mic.audio && sec.mic.audio.muted)
            value: sec.mic && sec.mic.audio ? sec.mic.audio.volume : 0
            onMoved: v => { if (sec.mic && sec.mic.audio) sec.mic.audio.volume = v; }
            onIconClicked: if (sec.mic && sec.mic.audio) sec.mic.audio.muted = !sec.mic.audio.muted
        }
    }
    Repeater {
        model: sec.mics
        Pressable {
            required property var modelData
            readonly property bool on: sec.mic === modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: on ? Theme.accentContainer : Theme.containerHigh
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
            Row {
                x: 16; spacing: 10
                anchors.verticalCenter: parent.verticalCenter
                Icon { name: parent.parent.on ? "radio_button_checked" : "radio_button_unchecked"; size: 19; color: parent.parent.on ? Theme.accent : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                Label { text: parent.parent.modelData.description || parent.parent.modelData.name; strong: parent.parent.on; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Label { text: "Camera"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    MediaDevices { id: devices }
    property int camIndex: 0
    property bool looking: false
    SettingRow {
        icon: "videocam"; title: "Look through the camera"
        desc: devices.videoInputs.length === 0 ? "No camera found" : devices.videoInputs[Math.min(sec.camIndex, devices.videoInputs.length - 1)].description
        Row {
            spacing: 6
            Button { visible: devices.videoInputs.length > 1; text: "Next camera"; onClicked: sec.camIndex = (sec.camIndex + 1) % devices.videoInputs.length }
            Button { enabledInput: devices.videoInputs.length > 0; text: sec.looking ? "Stop" : "Show"; primary: !sec.looking; onClicked: sec.looking = !sec.looking }
        }
    }
    Rectangle {
        visible: sec.looking
        Layout.fillWidth: true
        Layout.preferredHeight: width * 9 / 16 * 0.7
        radius: Theme.corner(80, 6)
        color: "black"
        clip: true
        CaptureSession {
            camera: Camera {
                active: sec.looking
                cameraDevice: devices.videoInputs.length ? devices.videoInputs[Math.min(sec.camIndex, devices.videoInputs.length - 1)] : devices.defaultVideoInput
            }
            videoOutput: view
        }
        VideoOutput { id: view; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
    }
}
