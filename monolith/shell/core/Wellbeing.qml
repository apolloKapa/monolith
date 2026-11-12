pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screen time: how long each app has been focused (not while you're idle), per day and per hour,
// kept for six weeks in ~/.local/state/monolith/next-wellbeing.json:
//   { v: 2, days: { "yyyy-MM-dd": { appId: seconds } },
//           hours: { "yyyy-MM-dd": [24 × seconds] },               (everything, hour by hour)
//           appHours: { "yyyy-MM-dd": { appId: [24 × seconds] } } } (each app's hours, two weeks)
// An older file (just the days) is read as it is. Optional daily limits per app, and a daily
// goal for all of it, send a notification when they're reached. Its settings are on the
// Wellbeing page itself (the gear).
Singleton {
    id: wb
    readonly property string file: Quickshell.env("HOME") + "/.local/state/monolith/next-wellbeing.json"
    property var days: ({})
    property var hours: ({})
    property var appHours: ({})
    property bool loaded: false
    property var _warned: ({})
    readonly property bool tracking: Store.get("wellbeing.track", true) !== false
    readonly property int goal: Number(Store.get("wellbeing.goal", 0)) || 0      // minutes a day, 0 = none
    readonly property string today: key(clock.date)
    readonly property var todayMap: days[today] || {}
    readonly property int todayTotal: dayTotal(today)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    IdleMonitor { id: idleMon; timeout: 120; respectInhibitors: true }

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function dayMap(k) { return days[k] || {}; }
    function dayTotal(k) { const m = days[k]; return m ? Object.values(m).reduce((a, b) => a + b, 0) : 0; }
    function hoursOf(k) { return hours[k] || null; }
    function appHoursOf(k, app) { const m = appHours[k]; return m && m[app] ? m[app] : null; }

    function limitOf(app) { return Number(Store.get("wellbeing.limits." + app.replace(/\./g, "_"), 0)); }
    function setLimit(app, minutes) { if (minutes > 0) Store.set("wellbeing.limits." + app.replace(/\./g, "_"), minutes); else Store.unset("wellbeing.limits." + app.replace(/\./g, "_")); }
    // the apps with a limit: [{ key, minutes }] (keys have their dots as _)
    readonly property var limits: { const l = Store.get("wellbeing.limits", ({})) || ({}); return Object.keys(l).filter(k => Number(l[k]) > 0).map(k => ({ key: k, minutes: Number(l[k]) })); }

    function keepLast(map, n) {
        const keys = Object.keys(map).sort();
        while (keys.length > n) delete map[keys.shift()];
    }
    function tick() {
        if (!loaded || idleMon.isIdle || !tracking) return;
        const app = Niri.focusedAppId;
        if (app === "") return;
        const h = new Date().getHours();
        const d = Object.assign({}, days);
        const t = Object.assign({}, d[today] || {});
        t[app] = (t[app] || 0) + 10;
        d[today] = t;
        keepLast(d, 42);
        days = d;
        const hs = Object.assign({}, hours);
        const row = (hs[today] || new Array(24).fill(0)).slice();
        row[h] += 10;
        hs[today] = row;
        keepLast(hs, 42);
        hours = hs;
        const ah = Object.assign({}, appHours);
        const am = Object.assign({}, ah[today] || {});
        const ar = (am[app] || new Array(24).fill(0)).slice();
        ar[h] += 10;
        am[app] = ar;
        ah[today] = am;
        keepLast(ah, 14);
        appHours = ah;
        const lim = limitOf(app);
        const k1 = today + app;
        if (lim > 0 && t[app] >= lim * 60 && !_warned[k1]) {
            _warned = Object.assign({}, _warned, { [k1]: true });
            Quickshell.execDetached(["notify-send", "-a", "Monolith", "-u", "critical", "Time limit reached", "You've used " + nameOf(app) + " for " + fmt(lim * 60) + " today"]);
        }
        const k2 = today + " goal";
        if (goal > 0 && todayTotal >= goal * 60 && !_warned[k2]) {
            _warned = Object.assign({}, _warned, { [k2]: true });
            Quickshell.execDetached(["notify-send", "-a", "Monolith", "Daily screen time reached", "You've been at the screen for " + fmt(goal * 60) + " today. Time for a break?"]);
        }
    }
    Timer { interval: 10000; repeat: true; running: true; onTriggered: wb.tick() }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: wb.save() }
    function save() { if (loaded) fv.setText(JSON.stringify({ v: 2, days: days, hours: hours, appHours: appHours })); }

    FileView {
        id: fv
        path: wb.file
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const j = JSON.parse(text());
                if (j && j.v === 2) { wb.days = j.days || {}; wb.hours = j.hours || {}; wb.appHours = j.appHours || {}; }
                else wb.days = j || {};
            } catch (e) {}
            wb.loaded = true;
        }
        onLoadFailed: wb.loaded = true
    }

    function clear() { days = {}; hours = {}; appHours = {}; _warned = {}; fv.setText(JSON.stringify({ v: 2, days: {}, hours: {}, appHours: {} })); }
    function nameOf(id) { const e = DesktopEntries.byId(id); return e ? e.name : id; }
    function iconOf(id) { const e = DesktopEntries.byId(id); return Quickshell.iconPath(e ? e.icon : id, "application-x-executable"); }
    function fmt(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : (m > 0 || s === 0 ? m + " min" : "<1 min");
    }
    function fmtShort(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + "h" + (m > 0 ? " " + m + "m" : "") : m + "m";
    }
}
