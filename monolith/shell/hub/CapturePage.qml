import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../ui"

// Capture: screenshots (niri's own tool: region, screen, window), text from a region (OCR,
// copied), screen recording (wf-recorder, to ~/Videos/Recordings), and recent screenshots.
Page {
    id: page
    pageId: "capture"
    implicitHeight: col.implicitHeight
    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property var recent: []
    readonly property int delay: Number(Store.get("capture.delay", 0)) || 0

    onCurrentChanged: if (current) listShots.running = true
    Process {
        id: listShots
        command: ["sh", "-c", "ls -t \"$1\"/*.png 2>/dev/null | head -8", "_", page.shotsDir]
        stdout: StdioCollector { onStreamFinished: page.recent = text.split("\n").filter(l => l) }
    }

    // the hub gets out of the way first, then the action runs
    function later(args) { HubState.close(); runLater.args = args; runLater.restart(); }
    Timer { id: runLater; property var args: []; interval: 350; onTriggered: Quickshell.execDetached(args) }

    // recording lives in Tasks (it keeps going when the hub closes, on every screen)
    readonly property bool recording: Tasks.recording
    Connections { target: Tasks; function onRecordingSaved() { listShots.running = true } }
    function startRecording(region) { HubState.close(); Tasks.startRecording(region); }

    component Action: Pressable {
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        Rise {}
        radius: Theme.corner(96, 4)
        color: on ? Theme.selected : Theme.containerHigh
        Column {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Bubble { size: 38; icon: parent.parent.icon; on: parent.parent.on }
            Label { width: parent.width; text: parent.parent.title; strong: true }
            Label { width: parent.width; text: parent.parent.sub; muted: true; font.pixelSize: Theme.sizeSmall - 1; visible: text !== "" }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label { Layout.leftMargin: 6; text: "Delay"; muted: true; font.pixelSize: Theme.sizeSmall }
            Segmented { Layout.preferredWidth: 240; height: 32; opts: [["0", "None"], ["3", "3 s"], ["5", "5 s"], ["10", "10 s"]]; value: String(page.delay); onPicked: v => Store.set("capture.delay", Number(v)) }
            Item { Layout.fillWidth: true }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            Action { icon: "screenshot_region"; title: "Region"; sub: page.delay > 0 ? "Pick an area, in " + page.delay + " s" : "Pick an area"; onClicked: Capture.startIn(page.delay, { mode: "region" }) }
            Action { icon: "screenshot_monitor"; title: "Screen"; sub: page.delay > 0 ? "The whole screen, in " + page.delay + " s" : "The whole screen"; onClicked: Capture.startIn(page.delay, { mode: "screen" }) }
            // niri's own window screenshot; on Hyprland, the focused window's area through grim,
            // saved to Screenshots and copied (as niri's does)
            Action {
                icon: "select_window"; title: "Window"; sub: "The focused window"
                onClicked: page.later(Niri.hyprland
                    ? ["sh", "-c", "d=\"$HOME/Pictures/Screenshots\"; mkdir -p \"$d\"; f=\"$d/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png\"; "
                       + "g=$(hyprctl activewindow -j | python3 -c 'import json,sys; w=json.load(sys.stdin); print(\"%d,%d %dx%d\" % (w[\"at\"][0], w[\"at\"][1], w[\"size\"][0], w[\"size\"][1]))') || exit; "
                       + "grim -g \"$g\" \"$f\" && wl-copy < \"$f\" && notify-send -a Monolith -i \"$f\" 'Screenshot saved' \"$(basename \"$f\")\""]
                    : ["niri", "msg", "action", "screenshot-window"])
            }
            Action {
                icon: "document_scanner"; title: "Text from region"; sub: "Recognise text, copy it"
                onClicked: page.later(["sh", "-c", "g=$(slurp) || exit; grim -g \"$g\" - | tesseract - - 2>/dev/null | wl-copy && notify-send -a Monolith 'Text copied' \"$(wl-paste | head -c 120)\""])
            }
            Action {
                icon: page.recording ? "stop_circle" : "videocam"; on: page.recording
                title: page.recording ? "Stop recording" : "Record region"; sub: page.recording ? "Saves to ~/Videos/Recordings" : "Pick an area"
                onClicked: page.recording ? Tasks.stopRecording() : Capture.start({ kind: "video", mode: "region" })
            }
            Action {
                icon: "screen_record"; title: "Record screen"; sub: "The whole screen"
                enabledInput: !page.recording
                opacity: page.recording ? 0.5 : 1
                onClicked: Capture.start({ kind: "video", mode: "screen" })
            }
        }

        Label { Layout.leftMargin: 6; Layout.topMargin: 4; visible: page.recent.length > 0; text: "Recent screenshots"; muted: true; font.pixelSize: Theme.sizeSmall }
        Row {
            Layout.fillWidth: true
            spacing: 8
            visible: page.recent.length > 0
            Repeater {
                model: page.recent.slice(0, 4)
                Pressable {
                    required property string modelData
                    width: (col.width - 24) / 4
                    height: width * 0.62
                    radius: Theme.corner(height, 2)
                    color: Theme.container
                    clip: true
                    onClicked: { HubState.close(); Capture.edit(modelData, modelData); }
                    onRightClicked: Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "_", modelData])
                    Image { anchors.fill: parent; source: Wall.url(parent.modelData); sourceSize: Qt.size(320, 200); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
            }
        }
    }
}
