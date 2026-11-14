pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light: warmer colours, run by the shell. Always on, from sunset to sunrise where you are
// (Settings → General's location), or between two times you pick.
//   niri: wlsunset (it keeps the schedule itself).
//   Hyprland: hyprsunset, Hyprland's own (its colour matrix, faded by Hyprland), switched on and
//   off here by the schedule. wlsunset's gamma tables flickered there: the warmth jumped back
//   and forth while it faded in. Without hyprsunset installed, wlsunset as before.
Singleton {
    id: nl
    readonly property bool enabled: Store.get("nightlight.enabled", false) === true
    readonly property int temp: Number(Store.get("nightlight.temp", 4000))
    readonly property string schedule: Store.get("nightlight.schedule", "always")   // always | sun | custom
    readonly property string from: Store.get("nightlight.from", "21:00")
    readonly property string to: Store.get("nightlight.to", "07:00")
    function toggle() { Store.set("nightlight.enabled", !enabled); }

    // ── which tool ──
    property bool hasHyprsunset: false
    readonly property bool useHyprsunset: Niri.hyprland && hasHyprsunset
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        stdout: StdioCollector { onStreamFinished: nl.hasHyprsunset = text.trim() !== "" }
    }

    // ── wlsunset (niri, or Hyprland without hyprsunset) ──
    readonly property var args: {
        const a = ["wlsunset", "-t", String(temp), "-T", String(Math.max(temp + 1, 6500))];
        if (schedule === "sun" && Weather.loc) return a.concat(["-l", String(Weather.loc.latitude), "-L", String(Weather.loc.longitude)]);
        // custom: warm from `from` to `to`; always: warm all day but one minute
        const set = schedule === "custom" ? from : "00:00";
        const rise = schedule === "custom" ? to : "23:59";
        return a.concat(["-s", set, "-S", rise, "-d", "60"]);
    }
    // (re)start a moment after a change, so a dragged slider restarts it once
    onArgsChanged: if (!useHyprsunset) restart.restart()
    // (switched on: looked for hyprsunset again, so one installed since works at once)
    onEnabledChanged: { if (enabled) probe.running = true; restart.restart(); }
    onUseHyprsunsetChanged: restart.restart()
    Timer {
        id: restart; interval: 600
        onTriggered: {
            proc.running = false;
            if (nl.useHyprsunset) { nl.applyHypr(); return; }
            hypr.running = false;
            if (nl.enabled) startLater.restart();
        }
    }
    Timer { id: startLater; interval: 200; onTriggered: { proc.command = nl.args; proc.running = true; } }
    Process { id: proc }

    // ── hyprsunset (Hyprland): on while the schedule says so ──
    // "HH:MM" -> minutes since midnight
    function mins(t) { const p = String(t || "").split(":"); return p.length < 2 ? -1 : Number(p[0]) * 60 + Number(p[1]); }
    // warm now? between `a` (evening) and `b` (morning), across midnight
    function between(now, a, b) { if (a < 0 || b < 0) return true; return a <= b ? (now >= a && now < b) : (now >= a || now < b); }
    property int now: 0
    function tick() { const d = new Date(); now = d.getHours() * 60 + d.getMinutes(); }
    Timer { interval: 30000; repeat: true; running: nl.useHyprsunset && nl.enabled; triggeredOnStart: true; onTriggered: nl.tick() }
    readonly property bool warmNow: {
        if (!enabled) return false;
        if (schedule === "custom") return between(now, mins(from), mins(to));
        if (schedule === "sun") {
            const d = Weather.days && Weather.days.length ? Weather.days[0] : null;
            // (no sun times yet: evening to morning)
            return between(now, mins(d && d.sunset ? d.sunset : "20:00"), mins(d && d.sunrise ? d.sunrise : "07:00"));
        }
        return true;
    }
    onWarmNowChanged: if (useHyprsunset) applyHypr()
    // a new warmth while it's on: told to the running hyprsunset (no restart, no flash)
    onTempChanged: if (useHyprsunset && hypr.running) tempLater.restart()
    Timer { id: tempLater; interval: 250; onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(nl.temp)]) }
    function applyHypr() {
        if (warmNow && !hypr.running) { hypr.command = ["hyprsunset", "-t", String(temp)]; hypr.running = true; }
        else if (!warmNow && hypr.running) hypr.running = false;      // (Hyprland fades back on its own)
    }
    Process { id: hypr }

    // a wlsunset / hyprsunset started some other way (the old shell, a keybind) would fight with this one
    Component.onCompleted: { Quickshell.execDetached(["pkill", "-x", "wlsunset"]); Quickshell.execDetached(["pkill", "-x", "hyprsunset"]); tick(); restart.restart(); }
}
