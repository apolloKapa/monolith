import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../ui"

// Sound: outputs, inputs and the apps playing, each with its own volume. Clicking a device
// makes it the default.
Page {
    id: page
    pageId: "sound"
    implicitHeight: Math.min(560, col.implicitHeight)
    property string tab: "out"

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream)
    readonly property var shown: tab === "out" ? outputs : (tab === "in" ? inputs : streams)
    PwObjectTracker { objects: page.nodes }

    function isDefault(n) { return n === Pipewire.defaultAudioSink || n === Pipewire.defaultAudioSource; }
    function nameOf(n) {
        if (n.isStream) return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }
    function iconOf(n) {
        if (n.isStream) return "music_note";
        if (!n.isSink) return "mic";
        const d = (n.description || "").toLowerCase();
        return d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 ? "headphones" : (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1 ? "tv" : "speaker");
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        // the three lists as a segmented row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Theme.corner(height)
            color: Theme.container
            readonly property var opts: [["out", "Outputs", "speaker"], ["in", "Inputs", "mic"], ["apps", "Apps", "apps"]]
            Rectangle {
                y: 4
                x: 4 + parent.opts.findIndex(o => o[0] === page.tab) * ((parent.width - 8) / 3)
                width: (parent.width - 8) / 3
                height: parent.height - 8
                radius: Theme.corner(height)
                color: Theme.selected
                Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: parent.parent.opts
                    Pressable {
                        required property var modelData
                        width: parent.width / 3
                        height: parent.height
                        color: "transparent"
                        onClicked: page.tab = modelData[0]
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: modelData[2]; size: 18; filled: page.tab === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData[1]; strong: page.tab === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            visible: page.shown.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: page.tab === "apps" ? "No apps are playing sound" : "No devices"
            muted: true
        }

        Repeater {
            model: page.shown
            Pressable {
                id: row
                required property var modelData
                readonly property bool def: page.isDefault(modelData)
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: Theme.corner(56, 6)
                color: def ? Theme.selected : Theme.containerHigh
                enabledInput: !modelData.isStream
                onClicked: {
                    if (modelData.isSink) Pipewire.preferredDefaultAudioSink = modelData;
                    else Pipewire.preferredDefaultAudioSource = modelData;
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Bubble { size: 34; icon: page.iconOf(row.modelData); on: row.def }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { Layout.fillWidth: true; text: page.nameOf(row.modelData); strong: true }
                            Label {
                                Layout.fillWidth: true
                                text: row.def ? "Default" : (row.modelData.isStream ? (row.modelData.properties["media.name"] || "") : "Click to use")
                                muted: true
                                font.pixelSize: Theme.sizeSmall
                            }
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        icon: row.modelData.audio.muted ? (row.modelData.isSink || row.modelData.isStream ? "volume_off" : "mic_off") : (row.modelData.isSink || row.modelData.isStream ? "volume_up" : "mic")
                        muted: row.modelData.audio.muted
                        value: row.modelData.audio.volume
                        onMoved: v => { row.modelData.audio.muted = false; row.modelData.audio.volume = v; }
                        onIconClicked: row.modelData.audio.muted = !row.modelData.audio.muted
                    }
                }
            }
        }
    }
}
