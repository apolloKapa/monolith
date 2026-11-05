pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light: warmer colours through wlsunset, run by the shell. Always on, from sunset to
// sunrise where you are (Settings → General's location), or between two times you pick.
Singleton {
    id: nl
    readonly property bool enabled: Store.get("nightlight.enabled", false) === true
    readonly property int temp: Number(Store.get("nightlight.temp", 4000))
    readonly property string schedule: Store.get("nightlight.schedule", "always")   // always | sun | custom
    readonly property string from: Store.get("nightlight.from", "21:00")
    readonly property string to: Store.get("nightlight.to", "07:00")
    function toggle() { Store.set("nightlight.enabled", !enabled); }

    readonly property var args: {
        const a = ["wlsunset", "-t", String(temp), "-T", String(Math.max(temp + 1, 6500))];
        if (schedule === "sun" && Weather.loc) return a.concat(["-l", String(Weather.loc.latitude), "-L", String(Weather.loc.longitude)]);
        // custom: warm from `from` to `to`; always: warm all day but one minute
        const set = schedule === "custom" ? from : "00:00";
        const rise = schedule === "custom" ? to : "23:59";
        return a.concat(["-s", set, "-S", rise, "-d", "60"]);
    }
    // (re)start a moment after a change, so a dragged slider restarts it once
    onArgsChanged: restart.restart()
    onEnabledChanged: restart.restart()
    Timer { id: restart; interval: 600; onTriggered: { proc.running = false; if (nl.enabled) startLater.restart(); } }
    Timer { id: startLater; interval: 200; onTriggered: { proc.command = nl.args; proc.running = true; } }
    Process { id: proc }
    // a wlsunset started some other way (the old shell, a keybind) would fight with this one
    Component.onCompleted: { Quickshell.execDetached(["pkill", "-x", "wlsunset"]); restart.restart(); }
}
