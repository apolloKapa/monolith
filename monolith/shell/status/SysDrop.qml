import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"
import "../ui"

// The system monitor dropdown: a click on the bar's stats drops it out under them. Live graphs
// of the last two minutes (CPU, GPU, memory, video memory, both temperatures), the GPU's power
// and clock, and the busiest processes by CPU, memory or video memory, each with a button to
// end it (a second click within a few seconds forces it). "More" opens the control center's
// Monitor tab.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "system" && !HubState.open

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-sysmon"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: dd.shown ? full : null }
    Item { id: full; anchors.fill: parent }
    MouseArea { anchors.fill: parent; onClicked: HubState.closeDrop() }
    Item { id: keys; focus: true; Keys.onEscapePressed: HubState.closeDrop() }
    onShownChanged: if (shown) { keys.forceActiveFocus(); top.running = true; }

    // ── the processes, every two seconds while it's open ──
    property string sortBy: Store.get("sysmon.sort", "cpu")
    property var procs: []
    Process {
        id: top
        command: ["python3", Qt.resolvedUrl("../scripts/top.py").toString().replace("file://", ""), dd.sortBy, "8"]
        stdout: StdioCollector { onStreamFinished: { try { dd.procs = JSON.parse(text); } catch (e) {} } }
    }
    Timer { interval: 2000; repeat: true; running: dd.shown; onTriggered: if (!top.running) top.running = true }
    onSortByChanged: { Store.set("sysmon.sort", sortBy); if (!top.running) top.running = true; }

    function gb(b) { return (b / 1073741824).toFixed(1) + " GB"; }
    function mb(b) { return b >= 1073741824 ? gb(b) : Math.round(b / 1048576) + " MB"; }

    Rectangle {
        id: card
        width: 520
        height: Math.min(dd.height - 80, col.implicitHeight + 24)
        Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        clip: true
        opacity: dd.shown ? 1 : 0
        scale: dd.shown ? 1 : Theme.popScale
        transformOrigin: Theme.dropOrigin
        Behavior on opacity { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dd.shown ? Theme.enterCurve : Theme.exitCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }

        Flickable {
            id: scroller
            SmoothWheel {}
            x: 12; y: 12
            width: card.width - 24
            height: card.height - 24
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: col
                width: scroller.width
                spacing: 10

                // ── the graphs: two by three ──
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8; columnSpacing: 8
                    component Tile: Rectangle {
                        id: tile
                        property string icon: ""
                        property string name: ""
                        property string value: ""
                        property string detail: ""
                        property var hist: []
                        property real now: 0          // 0..1, for the colour
                        property real hot: 0.9        // from here on it's red
                        readonly property color tint: now >= hot ? Theme.danger : Theme.accent
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: Theme.corner(80, 6)
                        color: Theme.containerHigh
                        border.width: Theme.outlineW; border.color: Theme.outlineColor
                        clip: true
                        Spark { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 46; values: tile.hist; color: tile.tint }
                        Row {
                            x: 12; y: 10; spacing: 6
                            Icon { name: tile.icon; size: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: tile.name; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Label { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; text: tile.value; strong: true; font.pixelSize: Theme.sizeTitle; color: tile.now >= tile.hot ? Theme.danger : Theme.text }
                        Label { x: 12; y: 30; width: parent.width - 24; text: tile.detail; muted: true; font.pixelSize: Theme.sizeTiny; elide: Text.ElideRight }
                    }
                    Tile { icon: "memory"; name: "CPU"; value: Math.round(Stats.cpu * 100) + "%"; detail: ""; hist: Stats.cpuHist; now: Stats.cpu; hot: 0.95 }
                    Tile { icon: "videogame_asset"; name: "GPU"; value: Math.round(Stats.gpu * 100) + "%"; detail: Stats.gpuDir !== "" ? Math.round(Stats.gpuClock) + " MHz   ·   " + Math.round(Stats.gpuWatts) + " W" : "No AMD GPU found"; hist: Stats.gpuHist; now: Stats.gpu; hot: 1.1 }
                    Tile { icon: "data_usage"; name: "Memory"; value: Math.round(Stats.mem * 100) + "%"; detail: dd.gb(Stats.memUsed) + " of " + dd.gb(Stats.memTotal); hist: Stats.memHist; now: Stats.mem }
                    Tile { icon: "developer_board"; name: "Video memory"; value: Stats.vramTotal > 0 ? Math.round(Stats.vram * 100) + "%" : "—"; detail: Stats.vramTotal > 0 ? dd.gb(Stats.vramUsed) + " of " + dd.gb(Stats.vramTotal) : ""; hist: Stats.vramHist; now: Stats.vram }
                    Tile { icon: "thermostat"; name: "CPU temperature"; value: Math.round(Stats.temp) + "°"; hist: Stats.tempHist; now: Stats.temp / 100; hot: Number(Stats.warn.cpuTemp || 90) / 100 }
                    Tile { icon: "device_thermostat"; name: "GPU temperature"; value: Stats.gpuTemp > 0 ? Math.round(Stats.gpuTemp) + "°" : "—"; hist: Stats.gpuTempHist; now: Stats.gpuTemp / 100; hot: Number(Stats.warn.gpuTemp || 95) / 100 }
                }

                // ── the busiest processes ──
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.leftMargin: 4; text: "Busiest"; strong: true }
                    Item { Layout.fillWidth: true }
                    Segmented { Layout.preferredWidth: 270; height: 32; opts: [["cpu", "CPU"], ["mem", "Memory"], ["vram", "Video mem"]]; value: dd.sortBy; onPicked: v => dd.sortBy = v }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    Row {
                        x: 170; spacing: 14
                        Repeater {
                            model: ["CPU", "Memory", "Video"]
                            Label { required property string modelData; width: index === 0 ? 64 : 72; required property int index; horizontalAlignment: Text.AlignRight; text: modelData; muted: true; font.pixelSize: Theme.sizeTiny }
                        }
                    }
                }
                Repeater {
                    model: dd.procs
                    Rectangle {
                        id: pr
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: Theme.corner(44, 2)
                        color: ph.hovered ? Theme.containerHigh : "transparent"
                        HoverHandler { id: ph }
                        Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 150; text: pr.modelData.name; elide: Text.ElideRight; strong: true; font.pixelSize: Theme.sizeSmall + 1 }
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 170
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Label { width: 64; horizontalAlignment: Text.AlignRight; text: pr.modelData.cpu.toFixed(pr.modelData.cpu < 10 ? 1 : 0) + "%"; font.pixelSize: Theme.sizeSmall; strong: dd.sortBy === "cpu"; muted: dd.sortBy !== "cpu" }
                            Label { width: 72; horizontalAlignment: Text.AlignRight; text: dd.mb(pr.modelData.mem); font.pixelSize: Theme.sizeSmall; strong: dd.sortBy === "mem"; muted: dd.sortBy !== "mem" }
                            Label { width: 72; horizontalAlignment: Text.AlignRight; text: pr.modelData.vram > 0 ? dd.mb(pr.modelData.vram) : "—"; font.pixelSize: Theme.sizeSmall; strong: dd.sortBy === "vram"; muted: dd.sortBy !== "vram" }
                        }
                    }
                }
                Label { visible: dd.procs.length === 0; Layout.alignment: Qt.AlignHCenter; text: "Looking…"; muted: true; font.pixelSize: Theme.sizeSmall }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Button { text: "More"; icon: "monitoring"; onClicked: { HubState.closeDrop(); HubState.ccTab = "monitor"; HubState.show("quick"); } }
                }
            }
        }
    }
}
