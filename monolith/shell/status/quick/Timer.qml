import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A timer (the same one as Tools and the island: +1 / +5 / +10 min while it runs) and a
// stopwatch with laps (click the time to copy it, or copy all the laps). Both keep going when
// the panel closes (core/Tasks). The history keeps the timers you started (click one to start it
// again) and your stopwatch runs (copy one with its laps). Wide, the history gets its own column.
GridLayout {
    id: tm
    columns: wide ? 2 : 1
    columnSpacing: 14
    rowSpacing: 10
    readonly property bool wide: width > 760
    property string mode: Tasks.swRunning || (Tasks.swMs > 0 && Tasks.total <= 0) ? "stopwatch" : "timer"
    // narrow: the history instead of the timer / stopwatch
    property bool showHistory: false
    function copy(t) { Quickshell.execDetached(["wl-copy", "--", t]); }
    function ago(t) { return Notes.when(t); }

    component CopyBtn: Pressable {
        property string what: ""
        width: 26; height: 26
        color: hovered ? Theme.control : "transparent"
        onClicked: tm.copy(what)
        Icon { anchors.centerIn: parent; name: "content_copy"; size: 14; color: Theme.subtext }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 3
        Layout.maximumWidth: tm.wide ? 640 : -1
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: tm.showHistory && !tm.wide ? "History" : (tm.mode === "timer" ? "Timer" : "Stopwatch"); strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
            Segmented { visible: !(tm.showHistory && !tm.wide); width: 210; height: 34; opts: [["timer", "Timer"], ["stopwatch", "Stopwatch"]]; value: tm.mode; onPicked: v => tm.mode = v }
            // narrow: the history in place of the rest
            Pressable {
                visible: !tm.wide
                width: 34; height: 34
                color: tm.showHistory ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.control)
                onClicked: tm.showHistory = !tm.showHistory
                Icon { anchors.centerIn: parent; name: "history"; size: 18; color: tm.showHistory ? Theme.onAccentContainer : Theme.text }
            }
        }

        // ── timer ──
        ColumnLayout {
            visible: tm.mode === "timer" && !(tm.showHistory && !tm.wide)
            Layout.fillWidth: true
            spacing: 10
            Ring {
                Layout.alignment: Qt.AlignHCenter
                width: 200; height: 200
                thickness: 12
                value: Tasks.total > 0 ? Tasks.remaining / Tasks.total : 0
                text: Tasks.total > 0 ? Tasks.fmtLong(Tasks.remaining) : "—"
                caption: Tasks.total > 0 ? (Tasks.timing ? "running" : (Tasks.remaining > 0 ? "paused" : "done")) : "not set"
            }
            // running: more time, a little at a time
            RowLayout {
                visible: Tasks.total > 0 && Tasks.remaining > 0
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Repeater {
                    model: [1, 5, 10]
                    Pressable {
                        required property int modelData
                        height: 32; width: al.implicitWidth + 22
                        color: Theme.containerHigh
                        onClicked: Tasks.addTime(modelData)
                        Label { id: al; anchors.centerIn: parent; text: "+" + parent.modelData + " min"; font.pixelSize: Theme.sizeSmall; strong: true }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [1, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90]
                    Pressable {
                        required property int modelData
                        height: 34; width: tl.implicitWidth + 24
                        color: Theme.control
                        onClicked: Tasks.startTimer(modelData)
                        Label { id: tl; anchors.centerIn: parent; text: parent.modelData >= 60 ? (parent.modelData / 60) + " h" : parent.modelData + " min"; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
            NumberBox { id: mins; Layout.fillWidth: true; from: 1; to: 600; slideTo: 120; unit: "min"; value: 20; onMoved: v => value = v }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: "Start " + mins.value + " min"; primary: true; onClicked: Tasks.startTimer(mins.value) }
                Button { visible: Tasks.total > 0; text: Tasks.timing ? "Pause" : (Tasks.remaining > 0 ? "Resume" : "Clear"); onClicked: { if (Tasks.remaining <= 0) Tasks.total = 0; else Tasks.timing = !Tasks.timing; } }
                Button { visible: Tasks.total > 0 && Tasks.remaining > 0; text: "Stop"; onClicked: { Tasks.timing = false; Tasks.total = 0; Tasks.remaining = 0; } }
            }
        }

        // ── stopwatch ──
        ColumnLayout {
            visible: tm.mode === "stopwatch" && !(tm.showHistory && !tm.wide)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            // the time (click to copy it)
            Pressable {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                color: hovered ? Theme.containerHigh : Theme.container
                onClicked: tm.copy(Tasks.fmtMs(Tasks.swMs))
                Text {
                    anchors.centerIn: parent
                    text: Tasks.fmtMs(Tasks.swMs)
                    color: Tasks.swRunning ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: 46; font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
                Icon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; name: "content_copy"; size: 16; color: Theme.subtext; visible: parent.hovered }
            }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; primary: true; icon: Tasks.swRunning ? "pause" : "play_arrow"; text: Tasks.swRunning ? "Pause" : (Tasks.swMs > 0 ? "Resume" : "Start"); onClicked: Tasks.swToggle() }
                Button { icon: "flag"; text: "Lap"; enabled: Tasks.swRunning; onClicked: Tasks.swLap() }
                Button { icon: "restart_alt"; text: "Reset"; enabled: Tasks.swMs > 0; onClicked: Tasks.swReset() }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: Tasks.laps.length > 0
                Label { text: Tasks.laps.length + (Tasks.laps.length === 1 ? " lap" : " laps"); muted: true; font.pixelSize: Theme.sizeSmall; Layout.fillWidth: true }
                Pressable {
                    width: lcl.implicitWidth + 40; height: 28
                    color: hovered ? Theme.containerHigh : Theme.control
                    onClicked: tm.copy(Tasks.swText(Tasks.swMs, Tasks.laps))
                    Row { anchors.centerIn: parent; spacing: 4
                        Icon { name: "content_copy"; size: 14; anchors.verticalCenter: parent.verticalCenter }
                        Label { id: lcl; text: "Copy laps"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter } }
                }
            }
            // laps: the time at each, and how long that lap took
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 80
                clip: true
                spacing: 2
                model: Tasks.laps
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: 34
                    radius: Theme.corner(34, -4)
                    color: index % 2 === 0 ? Theme.container : "transparent"
                    readonly property real split: modelData - (index + 1 < Tasks.laps.length ? Tasks.laps[index + 1] : 0)
                    Label { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Lap " + (Tasks.laps.length - index); muted: true; font.pixelSize: Theme.sizeSmall }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; text: "+" + Tasks.fmtMs(parent.split); font.pixelSize: Theme.sizeSmall }
                    Label { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: Tasks.fmtMs(parent.modelData); strong: true; font.pixelSize: Theme.sizeSmall }
                }
                Label { anchors.centerIn: parent; visible: Tasks.laps.length === 0; text: "Laps show up here"; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
        // narrow: the history here
        HistoryList { visible: tm.showHistory && !tm.wide; Layout.fillWidth: true; Layout.fillHeight: true }
        Item { visible: tm.mode === "timer" && !(tm.showHistory && !tm.wide); Layout.fillHeight: true }
    }

    // ── wide: the history beside it ──
    ColumnLayout {
        visible: tm.wide
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        spacing: 6
        Label { text: "History"; strong: true; font.pixelSize: Theme.sizeTitle }
        HistoryList { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    // timers started (click: again) and stopwatch runs (copy with their laps)
    component HistoryList: ColumnLayout {
        spacing: 6
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 4)
            color: Theme.container
            ListView {
                anchors.fill: parent; anchors.margins: 6
                clip: true
                spacing: 2
                model: Tasks.history
                delegate: Pressable {
                    required property var modelData
                    readonly property bool isTimer: modelData.k === "timer"
                    readonly property string txt: isTimer ? Tasks.fmtLong(modelData.s) : Tasks.swText(modelData.ms, modelData.laps)
                    width: ListView.view.width; height: 40
                    color: hovered ? Theme.containerHigh : "transparent"
                    // a timer: start it again; a stopwatch run: copy it
                    onClicked: { if (isTimer) Tasks.startTimer(Math.round(modelData.s / 60)); else tm.copy(txt); }
                    Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: parent.isTimer ? "timer" : "timer_play"; size: 18; color: Theme.accent }
                    Column {
                        x: 38; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        Label { width: parent.width; elide: Text.ElideRight; strong: true; font.pixelSize: Theme.sizeSmall
                            text: parent.parent.isTimer ? Tasks.fmtLong(parent.parent.modelData.s) + " timer" : Tasks.fmtMs(parent.parent.modelData.ms) + (parent.parent.modelData.laps && parent.parent.modelData.laps.length ? " · " + parent.parent.modelData.laps.length + " laps" : "") }
                        Label { width: parent.width; elide: Text.ElideRight; muted: true; font.pixelSize: Theme.sizeSmall - 2
                            text: (parent.parent.isTimer ? "Started " : "Stopwatch, ") + tm.ago(parent.parent.modelData.at) + (parent.parent.isTimer ? " · click to start again" : "") }
                    }
                    CopyBtn { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; what: parent.txt }
                }
                Label { anchors.centerIn: parent; visible: Tasks.history.length === 0; text: "Timers and stopwatch runs show up here"; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
        Pressable {
            visible: Tasks.history.length > 0
            Layout.alignment: Qt.AlignRight
            width: hl.implicitWidth + 20; height: 28
            color: hovered ? Theme.containerHigh : Theme.control
            onClicked: Tasks.clearHistory()
            Label { id: hl; anchors.centerIn: parent; text: "Clear history"; font.pixelSize: Theme.sizeSmall }
        }
    }
}
