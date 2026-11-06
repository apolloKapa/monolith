pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Audio bars for the visualiser widget, from cava's raw output. cava only runs while something
// shows it: a widget calls hold() when it appears and release() when it goes.
Singleton {
    id: cv
    property int users: 0
    readonly property int count: 36
    property var bars: []          // 0..1 each, low to high frequencies
    readonly property bool available: true
    function hold() { users++; }
    function release() { users = Math.max(0, users - 1); if (users === 0) bars = []; }

    readonly property string conf: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-cava.conf"
    Process {
        id: write
        command: ["sh", "-c", "printf '%s\\n' '[general]' 'bars = " + cv.count + "' 'framerate = 60' 'sensitivity = 100' '[input]' 'method = pipewire' 'source = auto' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 1000' 'bar_delimiter = 59' 'frame_delimiter = 10' '[smoothing]' 'noise_reduction = 60' > \"$1\"", "sh", cv.conf]
        onExited: run.running = cv.users > 0
    }
    onUsersChanged: {
        if (users > 0 && !run.running && !write.running) write.running = true;
        else if (users === 0) run.running = false;
    }
    Process {
        id: run
        command: ["cava", "-p", cv.conf]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 1000);
                if (v.length) cv.bars = v;
            }
        }
    }
}
