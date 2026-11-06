pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Someone's GitHub contributions over the last year (the GitHub widget), from the public
// github-contributions-api. The username is set in Settings → Desktop; refreshed hourly.
Singleton {
    id: gh
    readonly property string user: (Store.get("widgets.github.user", "") || "").trim()
    property var days: []         // [{ date, count, level 0..4 }], oldest first
    property int total: 0
    property string state: "none" // none | loading | ok | error
    property int users: 0
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
        command: ["curl", "-fsSL", "--max-time", "15", "https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(gh.user) + "?y=last"]
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
