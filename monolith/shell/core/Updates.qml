pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The updater. Looks for a new version of Monolith on GitHub a minute after start and every
// few hours (Settings → About can turn that off, and check by hand), and knows what changed.
// A new version gets one notification (with an Update button) and the bar's update icon.
// update() opens a terminal running the update (so you see it, and it can ask for your
// password if a new package is needed); the shell restarts when it's done.
// The work is scripts/updates.sh.
Singleton {
    id: up
    readonly property string dir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/$/, "")
    readonly property string script: dir + "/scripts/updates.sh"
    // this version (version.txt next to the shell folder)
    property string version: ""
    FileView { id: versionFile; path: up.dir + "/../version.txt"; printErrors: false; onLoaded: up.version = text().trim() }
    property int available: 0
    property var log: []            // what changed, oldest first
    property string newVersion: ""  // the version on GitHub (when newer)
    property string newCommit: ""
    property bool newer: false      // a new version, even when the list of changes couldn't be had
    property string state: "idle"   // idle | checking | updating | offline
    property date checkedAt

    function check() {
        if (state === "checking") return;
        state = "checking";
        checker.running = true;
    }
    function update() {
        state = "updating";
        const cmd = "sh \"$1\" update \"$2\"; echo; echo 'Done. You can close this window.'; read -r _";
        Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh -c '" + cmd.replace(/'/g, "'\\''") + "' _ \"$0\" \"$1\"", up.script, up.dir]);
        // the update restarts the shell; if it hasn't after a while, look again
        afterUpdate.restart();
    }
    Timer { id: afterUpdate; interval: 15 * 60 * 1000; onTriggered: { up.state = "idle"; up.check(); } }

    Process {
        id: checker
        command: ["sh", up.script, "check", up.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                const head = lines.length && lines[0].startsWith("@") ? lines[0].slice(1).split(" ") : null;
                up.newer = !!head;
                up.newVersion = head ? head[0] : "";
                up.newCommit = head ? (head[1] || "") : "";
                up.log = head ? lines.slice(1) : [];
                up.available = up.newer ? Math.max(1, up.log.length) : 0;
                up.checkedAt = new Date();
                if (up.newer) up.announce();
            }
        }
        onExited: code => { up.state = code === 2 ? "offline" : "idle"; }
    }

    // one notification per new version
    function announce() {
        const key = newCommit || newVersion;
        if (key === "" || Store.get("updates.announced", "") === key) return;
        Store.set("updates.announced", key);
        notifier.command = ["notify-send", "-a", "Monolith", "-i", "system-software-update", "-A", "update=Update", "-A", "later=Later", "--wait",
            "A new version of Monolith" + (newVersion && ["new", "git", version].indexOf(newVersion) === -1 ? " (" + newVersion + ")" : ""),
            log.length ? log.length + (log.length === 1 ? " change: " : " changes, the latest: ") + log[log.length - 1] : "Open Settings → About to see it"];
        notifier.running = true;
    }
    Process {
        id: notifier
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "update") up.update() }
    }

    Timer {
        interval: 6 * 3600 * 1000; repeat: true; running: Store.get("updates.check", true) !== false
        triggeredOnStart: true
        onTriggered: startDelay.restart()
    }
    Timer { id: startDelay; interval: 60000; onTriggered: up.check() }

    IpcHandler {
        target: "updates"
        function check(): void { up.check(); }
        function update(): void { up.update(); }
    }
}
