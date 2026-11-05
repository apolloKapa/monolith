pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and CPU temperature, sampled every two seconds from /proc and hwmon.
Singleton {
    id: stats

    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1
    property real temp: 0         // °C
    property var _prev: null
    property string tempPath: ""

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: tempFile; path: stats.tempPath; blockLoading: true }

    // the CPU package sensor: k10temp / zenpower (AMD) or coretemp (Intel)
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); case $n in k10temp|zenpower|coretemp) echo $d/temp1_input; exit;; esac; done"]
        stdout: StdioCollector { onStreamFinished: stats.tempPath = text.trim() }
    }

    function sample() {
        statFile.reload();
        const line = (statFile.text() || "").split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (line.length >= 4) {
            const idle = line[3] + (line[4] || 0);
            const total = line.reduce((a, b) => a + b, 0);
            if (_prev) {
                const dt = total - _prev.total, di = idle - _prev.idle;
                cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : cpu;
            }
            _prev = { total: total, idle: idle };
        }
        memFile.reload();
        const m = {};
        for (const l of (memFile.text() || "").split("\n")) {
            const p = l.split(/:\s+/);
            if (p.length === 2) m[p[0]] = parseInt(p[1]);
        }
        if (m.MemTotal) mem = 1 - (m.MemAvailable || 0) / m.MemTotal;
        if (tempPath !== "") {
            tempFile.reload();
            const v = parseInt(tempFile.text());
            if (!isNaN(v)) temp = v / 1000;
        }
    }

    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: stats.sample() }
}
