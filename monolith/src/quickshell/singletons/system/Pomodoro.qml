pragma Singleton
import QtQuick
import Quickshell
import "../../"

// Pomodoro timer for the dashboard: focus, short break, and a long break after every
// `longEvery` focus sessions. Lengths (minutes) come from settings.json -> pomodoro.
// A notification marks each switch.
Item {
    id: root

    readonly property var cfg: Config.getSetting("pomodoro", {})
    readonly property int focusMin: cfg.focus || 25
    readonly property int shortMin: cfg.shortBreak || 5
    readonly property int longMin: cfg.longBreak || 15
    readonly property int longEvery: cfg.longEvery || 4

    property string phase: "focus"        // focus | short | long
    property bool running: false
    property int done: 0                   // focus sessions finished today
    property int remaining: focusMin * 60
    readonly property int total: (phase === "focus" ? focusMin : phase === "short" ? shortMin : longMin) * 60
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string label: Math.floor(remaining / 60) + ":" + String(remaining % 60).padStart(2, "0")
    readonly property string phaseName: phase === "focus" ? I18n.t("pomodoro.focus", "Focus")
        : phase === "short" ? I18n.t("pomodoro.short", "Short break") : I18n.t("pomodoro.long", "Long break")

    function toggle() { root.running = !root.running; }
    function reset() {
        root.running = false;
        root.remaining = root.total;
    }
    function skip() { advance(false); }

    function setPhase(p) {
        root.phase = p;
        root.remaining = root.total;
    }

    function advance(notify) {
        let next;
        if (root.phase === "focus") {
            root.done += 1;
            next = (root.done % root.longEvery === 0) ? "long" : "short";
        } else {
            next = "focus";
        }
        setPhase(next);
        if (notify) {
            Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "-i", "alarm-symbolic",
                next === "focus" ? I18n.t("pomodoro.back_to_work", "Break's over, back to focus") : I18n.t("pomodoro.take_break", "Time for a break"),
                root.phaseName + " · " + Math.round(root.total / 60) + " min"]);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 1) {
                root.remaining -= 1;
            } else {
                root.advance(true);
            }
        }
    }

    onFocusMinChanged: if (!root.running && root.phase === "focus") root.remaining = root.total
}
