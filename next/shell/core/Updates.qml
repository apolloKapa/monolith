pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The updater: every few hours, how many updates there are (scripts/updates.sh: the new git
// commits in a checkout, or a newer version on GitHub when installed). update() brings it up
// to date and restarts the shell.
Singleton {
    id: up
    readonly property string dir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\/$/, "")
    readonly property string script: dir + "/scripts/updates.sh"
    property int available: 0
    property var log: []          // the new commits' subjects
    property string state: "idle" // idle | checking | updating | error
    property string error: ""
    property date checkedAt

    function check() {
        if (state === "checking" || state === "updating") return;
        state = "checking";
        checker.running = true;
    }
    function update() {
        state = "updating";
        puller.running = true;
    }

    Process {
        id: checker
        command: ["sh", up.script, "check", up.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                up.log = text.split("\n").filter(l => l !== "");
                up.available = up.log.length;
                up.state = "idle";
                up.checkedAt = new Date();
            }
        }
    }
    Process {
        id: puller
        command: ["sh", up.script, "update", up.dir]
        stdout: StdioCollector { id: pullOut }
        onExited: code => {
            if (code === 0) {
                up.available = 0; up.log = []; up.state = "idle";
            } else {
                up.state = "error";
                up.error = pullOut.text.trim() || "git pull failed";
            }
        }
    }
    Timer {
        interval: 6 * 3600 * 1000; repeat: true; running: Store.get("updates.check", true) !== false
        triggeredOnStart: true
        onTriggered: startDelay.restart()
    }
    Timer { id: startDelay; interval: 60000; onTriggered: up.check() }
}
