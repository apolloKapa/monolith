pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screen time: how long each app has been focused, per day (not while you're idle), kept for
// two weeks in ~/.local/state/monolith/next-wellbeing.json. Optional daily limits per app
// send a notification when they're reached.
Singleton {
    id: wb
    readonly property string file: Quickshell.env("HOME") + "/.local/state/monolith/next-wellbeing.json"
    property var days: ({})            // "yyyy-MM-dd" -> { appId: seconds }
    property bool loaded: false
    property var _warned: ({})
    readonly property string today: Qt.formatDate(clock.date, "yyyy-MM-dd")
    readonly property var todayMap: days[today] || {}
    readonly property int todayTotal: Object.values(todayMap).reduce((a, b) => a + b, 0)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    IdleMonitor { id: idleMon; timeout: 120; respectInhibitors: true }

    function limitOf(app) { return Number(Store.get("wellbeing.limits." + app.replace(/\./g, "_"), 0)); }
    function setLimit(app, minutes) { Store.set("wellbeing.limits." + app.replace(/\./g, "_"), minutes); }

    function tick() {
        if (!loaded || idleMon.isIdle || Store.get("wellbeing.track", true) === false) return;
        const app = Niri.focusedAppId;
        if (app === "") return;
        const d = Object.assign({}, days);
        const t = Object.assign({}, d[today] || {});
        t[app] = (t[app] || 0) + 10;
        d[today] = t;
        // keep two weeks
        const keys = Object.keys(d).sort();
        while (keys.length > 14) delete d[keys.shift()];
        days = d;
        const lim = limitOf(app);
        const key = today + app;
        if (lim > 0 && t[app] >= lim * 60 && !_warned[key]) {
            const w = Object.assign({}, _warned); w[key] = true; _warned = w;
            Quickshell.execDetached(["notify-send", "-a", "Monolith", "-u", "critical", "Time limit reached", "You've used " + app + " for " + lim + " minutes today"]);
        }
    }
    Timer { interval: 10000; repeat: true; running: true; onTriggered: wb.tick() }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: if (wb.loaded) fv.setText(JSON.stringify(wb.days)) }

    FileView {
        id: fv
        path: wb.file
        printErrors: false
        atomicWrites: true
        onLoaded: { try { wb.days = JSON.parse(text()); } catch (e) {} wb.loaded = true; }
        onLoadFailed: wb.loaded = true
    }

    function clear() { days = {}; _warned = {}; fv.setText("{}"); }
    function fmt(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
}
