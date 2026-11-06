pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and CPU temperature, and the GPU's load, memory and temperature (AMD, from
// sysfs; zero elsewhere), sampled every two seconds.
Singleton {
    id: stats

    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1
    property real temp: 0         // °C
    property real gpu: 0          // 0..1
    property real vramUsed: 0     // bytes
    property real vramTotal: 0
    property real gpuTemp: 0      // °C
    property string gpuDir: ""    // /sys/class/drm/cardN/device
    property string gpuTempPath: ""
    property real gpuWatts: 0     // the GPU's power draw
    property real gpuClock: 0     // its core clock, MHz
    // the last two minutes, one sample every two seconds (0..1), for the gaming page's graphs
    property real memUsed: 0      // bytes
    property real memTotal: 0
    property real disk: 0         // 0..1, the root filesystem
    property real diskUsed: 0     // bytes
    property real diskTotal: 0
    property var memHist: []
    property var tempHist: []
    property var cpuHist: []
    property var gpuHist: []
    readonly property string gpuHwmon: gpuTempPath.replace(/\/temp1_input$/, "")
    property var _prev: null
    property string tempPath: ""

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: tempFile; path: stats.tempPath; blockLoading: true }
    FileView { id: gpuBusy; path: stats.gpuDir !== "" ? stats.gpuDir + "/gpu_busy_percent" : ""; blockLoading: true; printErrors: false }
    FileView { id: vramUsedF; path: stats.gpuDir !== "" ? stats.gpuDir + "/mem_info_vram_used" : ""; blockLoading: true; printErrors: false }
    FileView { id: gpuTempF; path: stats.gpuTempPath; blockLoading: true; printErrors: false }
    FileView { id: gpuPowF; path: stats.gpuHwmon !== "" ? stats.gpuHwmon + "/power1_average" : ""; blockLoading: true; printErrors: false }
    FileView { id: gpuClkF; path: stats.gpuHwmon !== "" ? stats.gpuHwmon + "/freq1_input" : ""; blockLoading: true; printErrors: false }
    Process {
        running: true
        command: ["sh", "-c", "for c in /sys/class/drm/card*/device; do [ -f $c/gpu_busy_percent ] && { echo $c; cat $c/mem_info_vram_total 2>/dev/null; break; }; done; for d in /sys/class/hwmon/hwmon*; do [ \"$(cat $d/name 2>/dev/null)\" = amdgpu ] && { echo $d/temp1_input; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length >= 2 && l[0].startsWith("/sys/class/drm")) { stats.gpuDir = l[0]; stats.vramTotal = Number(l[1]) || 0; }
                const t = l.find(x => x.endsWith("temp1_input"));
                if (t) stats.gpuTempPath = t;
            }
        }
    }

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
        if (m.MemTotal) {
            mem = 1 - (m.MemAvailable || 0) / m.MemTotal;
            memTotal = m.MemTotal * 1024;
            memUsed = (m.MemTotal - (m.MemAvailable || 0)) * 1024;
        }
        if (gpuDir !== "") {
            gpuBusy.reload(); vramUsedF.reload();
            const b = parseInt(gpuBusy.text()); if (!isNaN(b)) gpu = b / 100;
            const v = Number(vramUsedF.text()); if (!isNaN(v)) vramUsed = v;
        }
        if (gpuTempPath !== "") {
            gpuTempF.reload(); const g = parseInt(gpuTempF.text()); if (!isNaN(g)) gpuTemp = g / 1000;
            gpuPowF.reload(); const pw = Number(gpuPowF.text()); if (!isNaN(pw)) gpuWatts = pw / 1e6;
            gpuClkF.reload(); const f = Number(gpuClkF.text()); if (!isNaN(f)) gpuClock = f / 1e6;
        }
        cpuHist = cpuHist.concat([cpu]).slice(-60);
        gpuHist = gpuHist.concat([gpu]).slice(-60);
        memHist = memHist.concat([mem]).slice(-60);
        if (tempPath !== "") {
            tempFile.reload();
            const v = parseInt(tempFile.text());
            if (!isNaN(v)) temp = v / 1000;
        }
        tempHist = tempHist.concat([Math.min(1, temp / 100)]).slice(-60);
    }

    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: stats.sample() }

    // the root filesystem's use, every half minute
    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (l.length === 2 && l[1] > 0) { stats.diskUsed = l[0]; stats.diskTotal = l[1]; stats.disk = l[0] / l[1]; }
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: df.running = true }
    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
}
