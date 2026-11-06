pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AppImages (the AppImages window, Settings → Software): every AppImage in your AppImages folder
// and every one an app entry runs. Adding one (dropping it on the window) moves it into the
// folder, makes it runnable and gives it an app entry with its own name and icon, so Search, the
// dock and menus know it. The folder is watched: an AppImage copied in gets set up by itself.
// The work is scripts/appimages.py.
Singleton {
    id: ai
    readonly property string folder: (Store.get("software.appimages", "") || (Quickshell.env("HOME") + "/Appimages")).replace(/^~/, Quickshell.env("HOME"))
    readonly property bool auto: Store.get("software.appimagesAuto", true) !== false
    readonly property string script: Qt.resolvedUrl("../scripts/appimages.py").toString().replace("file://", "")
    property var items: []
    property var gone: []
    // what's being worked on: [{ file, name, state: "working" | "done" | "failed", error }]
    property var jobs: []
    readonly property bool busy: jobs.some(j => j.state === "working")
    property bool opened: false           // the AppImages window
    property int users: 0                 // pages showing the list (it's loaded while one is)
    function hold() { users++; if (users === 1) refresh(); }
    function release() { users = Math.max(0, users - 1); }

    function refresh() { lister.running = false; lister.running = true; }
    Process {
        id: lister
        command: ["python3", ai.script, "list", ai.folder]
        stdout: StdioCollector { onStreamFinished: { try { const o = JSON.parse(text); ai.items = o.items; ai.gone = o.gone; } catch (e) {} } }
    }

    // queue: one AppImage at a time (each is unpacked for its name and icon)
    property var queue: []
    function setJob(file, changes) { jobs = jobs.map(j => j.file === file ? Object.assign({}, j, changes) : j); }
    function add(paths, keep) {
        for (const p of paths) {
            const f = p.replace(/^file:\/\//, "");
            if (jobs.some(j => j.file === f && j.state === "working")) continue;
            jobs = jobs.filter(j => j.file !== f).concat([{ file: f, name: f.split("/").pop(), state: "working", error: "" }]);
            queue = queue.concat([["add", ai.folder, f].concat(keep ? ["--keep"] : [])]);
        }
        next();
    }
    function remove(file, del) { queue = queue.concat([["remove", file].concat(del ? ["--delete"] : [])]); next(); }
    function sync() { queue = queue.concat([["sync", ai.folder]]); next(); }
    function clearDone() { jobs = jobs.filter(j => j.state === "working"); }
    function next() {
        if (worker.running || queue.length === 0) return;
        worker.args = queue[0];
        queue = queue.slice(1);
        worker.command = ["python3", ai.script].concat(worker.args);
        worker.running = true;
    }
    Process {
        id: worker
        property var args: []
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null;
                try { r = JSON.parse(text); } catch (e) {}
                if (worker.args[0] === "add") {
                    const f = worker.args[2];
                    if (r && r.ok) ai.setJob(f, { state: "done", name: r.name, file: r.file, icon: r.icon });
                    else ai.setJob(f, { state: "failed", error: r ? r.error : "Something went wrong" });
                }
            }
        }
        onExited: code => {
            if (code !== 0 && worker.args[0] === "add") ai.setJob(worker.args[2], { state: "failed", error: "Something went wrong (" + code + ")" });
            ai.refresh();
            ai.next();
        }
    }

    // the folder watcher: anything that lands in it (or leaves it) gets sorted out a moment later
    Process {
        id: watch
        running: ai.auto
        command: ["sh", "-c", "mkdir -p \"$1\" && exec inotifywait -m -q -e close_write,moved_to,moved_from,delete --format %f \"$1\"", "_", ai.folder]
        stdout: SplitParser { onRead: line => { if (/\.appimage$/i.test(line)) settle.restart(); } }
    }
    Timer { id: settle; interval: 1500; onTriggered: { if (ai.queue.length === 0 && !worker.running) ai.sync(); } }
    // once at start: pick up anything copied in while the shell wasn't running
    Timer { interval: 8000; running: ai.auto; onTriggered: ai.sync() }

    IpcHandler {
        target: "appimages"
        function open(): void { ai.opened = true; }
        function close(): void { ai.opened = false; }
        function add(file: string): void { ai.opened = true; ai.add([file], false); }
    }
}
