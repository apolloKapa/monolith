pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Settings -> AppImages: an AppImage put into the AppImages folder (~/Appimages unless changed)
// gets an app entry with its own name and icon by itself, and one deleted from it loses its
// entry (scripts/appimages.py sync). inotifywait tells when something lands in the folder.
Item {
    id: root

    readonly property var cfg: (Config.rawSettings && Config.rawSettings.appimages) ? Config.rawSettings.appimages : ({})
    readonly property bool enabled: cfg.watch !== false
    readonly property string folder: {
        const f = String(cfg.folder || "");
        const home = Quickshell.env("HOME") || "";
        if (f === "") return home + "/Appimages";
        return f.startsWith("~/") ? home + f.substring(1) : f;
    }
    property bool started: false

    function start() {
        started = true;
        rewatch();
    }

    // (re)start watching: on start, and when the setting or the folder changes
    property bool restartPending: false
    function rewatch() {
        const want = started && enabled && Caching.monolithDir !== "";
        if (watcher.running) {
            // stop it; onExited starts the new one (if it's still wanted)
            restartPending = want;
            watcher.running = false;
            return;
        }
        if (!want) return;
        watcher.running = true;
        syncSoon.restart();
    }
    onEnabledChanged: rewatch()
    onFolderChanged: rewatch()

    function script() { return Caching.monolithDir + "/scripts/appimages.py"; }

    Process {
        id: watcher
        // the folder is made first, so there's always something to watch
        command: ["bash", "-c", "mkdir -p \"$1\" && exec inotifywait -m -q -e close_write,moved_to,moved_from,delete --format '%f' \"$1\"", "_", root.folder]
        stdout: SplitParser {
            onRead: data => {
                if (/\.appimage$/i.test(data.trim())) syncSoon.restart();
            }
        }
        onExited: {
            if (root.restartPending) {
                root.restartPending = false;
                root.rewatch();
            } else if (root.started && root.enabled) {
                restartWatch.restart();   // it stopped by itself (the folder went away)
            }
        }
    }

    // a download can finish in a few writes: wait for it to settle
    Timer {
        id: syncSoon
        interval: 1500
        onTriggered: {
            if (syncer.running) { syncSoon.restart(); return; }
            syncer.command = ["python3", root.script(), "sync", root.folder];
            syncer.running = true;
        }
    }

    // inotifywait stops if the folder is removed: look again a bit later
    Timer {
        id: restartWatch
        interval: 5000
        onTriggered: root.rewatch()
    }

    Process {
        id: syncer
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(this.text); } catch (e) { return; }
                for (const id of (d.added || [])) {
                    Quickshell.execDetached(["bash", "-c",
                        "n=$(sed -n 's/^Name=//p' \"$HOME/.local/share/applications/$1.desktop\" | head -1); " +
                        "i=$(sed -n 's/^Icon=//p' \"$HOME/.local/share/applications/$1.desktop\" | head -1); " +
                        "notify-send -a Monolith -i \"$i\" \"$n is ready\" \"Added from your AppImages folder: it's in the launcher now\"",
                        "_", id]);
                }
            }
        }
    }
}
