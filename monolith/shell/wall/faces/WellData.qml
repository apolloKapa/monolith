import QtQuick
import "../../core"

// What the Wellbeing widgets show, from the screen time the shell keeps (core/Wellbeing):
// today's total, the day before, the busiest apps, this week (Monday first), the daily goal.
QtObject {
    id: d
    property date now: new Date()
    property int apps: 3                               // how many of the busiest apps
    readonly property string today: Wellbeing.key(now)
    readonly property int total: Wellbeing.dayTotal(today)
    readonly property int yesterday: Wellbeing.dayTotal(Wellbeing.key(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)))
    // seconds more (or fewer) than the day before
    readonly property int diff: total - yesterday
    readonly property int goal: Wellbeing.goal * 60    // seconds, 0 = no goal
    // [{ id, name, icon, secs }], busiest first
    readonly property var top: {
        const m = Wellbeing.dayMap(today);
        return Object.keys(m).sort((a, b) => m[b] - m[a]).slice(0, Math.max(0, apps))
            .map(k => ({ id: k, name: Wellbeing.nameOf(k), icon: Wellbeing.iconOf(k), secs: m[k] }));
    }
    readonly property int appCount: Object.keys(Wellbeing.dayMap(today)).length
    // this week, Monday to Sunday: [{ key, label, secs, today, future }]
    readonly property var week: {
        const back = (now.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 7; i++) {
            const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - back + i);
            const k = Wellbeing.key(day);
            out.push({ key: k, label: Qt.formatDate(day, "ddd").slice(0, 2), secs: Wellbeing.dayTotal(k), today: i === back, future: i > back });
        }
        return out;
    }
    readonly property int weekTotal: week.reduce((a, x) => a + x.secs, 0)
    readonly property int weekDays: Math.max(1, week.filter(x => !x.future && x.secs > 0).length)
    readonly property int weekMax: Math.max(1, ...week.map(x => x.secs), goal)
    // what a full ring or bar means: the goal, else the hours picked (seconds)
    function fullAt(choice) { return choice === "goal" || choice === undefined || choice === "" ? (goal > 0 ? goal : 8 * 3600) : Number(choice) * 3600; }
    function fmt(s) { return Wellbeing.fmt(s); }
    function fmtShort(s) { return Wellbeing.fmtShort(s); }
    // "2:05" (hours:minutes) for the dot looks
    function clockText(s) { const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return h + ":" + (m < 10 ? "0" : "") + m; }
    function diffText() {
        if (yesterday === 0) return "";
        const a = Math.abs(diff);
        return a < 60 ? "Same as yesterday" : fmtShort(a) + (diff > 0 ? " more" : " less") + " than yesterday";
    }
}
