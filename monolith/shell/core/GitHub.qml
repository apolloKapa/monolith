pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Someone's GitHub contributions (the GitHub widget) over the last year or one calendar year,
// from the public github-contributions-api. The username is set in the widget itself (or the
// editor); refreshed hourly.
Singleton {
    id: gh
    readonly property string user: (Store.get("widgets.github.user", "") || "").trim()
    property var days: []         // [{ date, count, level 0..4 }], oldest first
    property int total: 0
    property string state: "none" // none | loading | ok | error
    property int users: 0
    // 0: the last 12 months; else that calendar year
    property int year: 0
    readonly property int thisYear: new Date().getFullYear()
    function setUser(u) { Store.set("widgets.github.user", (u || "").trim()); }
    function stepYear(d) {
        // back to 2008 (GitHub's start), forward to the last 12 months
        let y = year === 0 ? thisYear + 1 : year;
        y = Math.max(2008, Math.min(thisYear + 1, y + d));
        year = y > thisYear ? 0 : y;
    }
    onYearChanged: if (users > 0) fetch()
    function hold() { users++; if (users === 1 && state !== "ok") fetch(); }
    function release() { users = Math.max(0, users - 1); }

    onUserChanged: { days = []; total = 0; state = "none"; if (users > 0) fetch(); }
    function fetch() {
        if (user === "") { state = "none"; return; }
        state = "loading";
        req.running = false;
        req.running = true;
    }
    Process {
        id: req
        command: ["curl", "-fsSL", "--max-time", "15", "https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(gh.user) + "?y=" + (gh.year === 0 ? "last" : gh.year)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    gh.days = o.contributions || [];
                    gh.total = gh.days.reduce((a, d) => a + (d.count || 0), 0);
                    gh.state = "ok";
                } catch (e) { gh.state = "error"; }
            }
        }
        onExited: code => { if (code !== 0) gh.state = "error"; }
    }
    Timer { interval: 3600000; repeat: true; running: gh.users > 0 && gh.user !== ""; onTriggered: gh.fetch() }
}
