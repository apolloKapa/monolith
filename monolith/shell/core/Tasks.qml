pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Things that keep going after their page closes, shared by every screen: the timer (Tools)
// and screen recording (Capture). The island on the status line shows both.
Singleton {
    id: tasks

    // stay awake (control center): an idle inhibitor held by the island's reserve strip
    property bool awake: false

    // ── timer ──
    property int total: 0
    property int remaining: 0
    property bool timing: false
    Timer {
        interval: 1000; repeat: true; running: tasks.timing
        onTriggered: {
            tasks.remaining--;
            if (tasks.remaining <= 0) {
                tasks.timing = false;
                Quickshell.execDetached(["notify-send", "-a", "Monolith", "-u", "critical", "Timer done", Math.round(tasks.total / 60) + " min are up"]);
            }
        }
    }
    function startTimer(min) { total = min * 60; remaining = total; timing = true; }
    function fmt(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // ── screen recording (wf-recorder, to ~/Videos/Recordings) ──
    readonly property string recDir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property bool recording: rec.running
    property int recSeconds: 0
    signal recordingSaved()
    Process {
        id: rec
        onRunningChanged: { tasks.recSeconds = 0; if (!running) tasks.recordingSaved(); }
    }
    Timer { interval: 1000; repeat: true; running: rec.running; onTriggered: tasks.recSeconds++ }
    // the hub gets out of the way first (the caller closes it), then recording starts
    function startRecording(region) {
        const name = recDir + "/Recording_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".mp4";
        rec.command = ["sh", "-c", "mkdir -p \"$1\" && " + (region ? "g=$(slurp) || exit 1; exec wf-recorder -g \"$g\" -f \"$2\"" : "exec wf-recorder -f \"$2\""), "_", recDir, name];
        recDelay.restart();
    }
    function stopRecording() { if (rec.running) rec.signal(2); }
    Timer { id: recDelay; interval: 350; onTriggered: rec.running = true }

    IpcHandler {
        target: "tasks"
        function timer(minutes: int): void { if (minutes > 0) tasks.startTimer(minutes); else { tasks.timing = false; tasks.total = 0; } }
        function record(region: bool): void { if (tasks.recording) tasks.stopRecording(); else tasks.startRecording(region); }
    }
}
