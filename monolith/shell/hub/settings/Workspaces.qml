import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Windows → Workspaces: how many workspaces each screen keeps (always there, even empty, and
// back on their screen when it's turned off and on). Written to the compositor's config by
// scripts/workspaces.py: niri's workspaces.kdl, or Monolith's own workspace file on Hyprland.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/workspaces.py").toString().replace("file://", "")
    // the screens, main one first (the one at the top left)
    readonly property var screens: Quickshell.screens.slice().sort((a, b) => (a.x - b.x) || (a.y - b.y))
    property var counts: ({})
    property bool loaded: false
    Process {
        id: reader
        running: true
        command: ["python3", sec.script, "read"]
        stdout: StdioCollector { onStreamFinished: { try { sec.counts = JSON.parse(text); } catch (e) {} sec.loaded = true; } }
    }
    Process { id: writer }
    // written once, a moment after the last change (niri / Hyprland reload on every save)
    function put(name, n) {
        const c = Object.assign({}, counts); c[name] = n; counts = c;
        save.restart();
    }
    Timer {
        id: save; interval: 500
        onTriggered: {
            const list = sec.screens.map(s => [s.name, sec.counts[s.name] !== undefined ? sec.counts[s.name] : 0]);
            writer.command = ["python3", sec.script, "apply", JSON.stringify({ screens: list })];
            writer.running = true;
        }
    }

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: "How many workspaces each screen keeps. They're always there, even when empty, and go back to their screen when it's turned off and on. 0: as many as you use (they come and go)."
            + (Niri.hyprland ? " On Hyprland they're numbered one after another: the first screen's first, then the next screen's." : "")
    }
    Repeater {
        model: sec.loaded ? sec.screens : []
        SettingRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            icon: "monitor"
            title: modelData.name + (index === 0 && sec.screens.length > 1 ? "  (main)" : "")
            desc: ((modelData.manufacturer || "") + " " + (modelData.model || "")).trim() + "  ·  " + modelData.width + " × " + modelData.height
            NumberBox {
                from: 0; to: 20; slideTo: 10
                zeroText: "Auto"
                value: sec.counts[modelData.name] !== undefined ? sec.counts[modelData.name] : 0
                onMoved: v => sec.put(modelData.name, Math.round(v))
            }
        }
    }
}
