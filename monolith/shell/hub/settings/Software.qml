import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../core"
import "../../ui"

// Startup apps (the standard ~/.config/autostart folder) and AppImages (given an app entry so
// Search and the dock know them).
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/startup.py").toString().replace("file://", "")
    readonly property string appDir: Store.get("software.appimages", Quickshell.env("HOME") + "/Applications")
    property var apps: []
    property var images: []
    property string filter: ""
    property bool showAll: false

    function load() { appsProc.running = true; imgProc.running = true; }
    Component.onCompleted: load()
    Process { id: appsProc; command: ["python3", sec.script, "apps"]; stdout: StdioCollector { onStreamFinished: { try { sec.apps = JSON.parse(text); } catch (e) {} } } }
    Process { id: imgProc; command: ["python3", sec.script, "appimages", sec.appDir]; stdout: StdioCollector { onStreamFinished: { try { sec.images = JSON.parse(text); } catch (e) {} } } }
    Process { id: act; onExited: sec.load() }
    function run(args) { act.command = ["python3", sec.script].concat(args); act.running = true; }

    readonly property var shownApps: {
        const f = filter.toLowerCase();
        const l = apps.filter(a => f === "" ? (showAll || a.on) : a.name.toLowerCase().includes(f));
        return l.slice(0, 40);
    }

    Label { text: "Start at login"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
    SettingRow {
        icon: "rocket_launch"; title: "Startup apps"; desc: sec.apps.filter(a => a.on).length + " start when you log in. Find an app to add it:"
        Field { placeholder: "Find an app"; onAccepted: v => sec.filter = v.trim() }
    }
    Repeater {
        model: sec.shownApps
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Theme.corner(52, 2)
            color: Theme.containerHigh
            IconImage { x: 14; anchors.verticalCenter: parent.verticalCenter; implicitSize: 28; source: Quickshell.iconPath(modelData.icon, "application-x-executable") }
            Label { x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 140; text: modelData.name; strong: modelData.on }
            Toggle { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: modelData.on; onToggled: on => sec.run(["set", modelData.id, on ? "on" : "off"]) }
        }
    }
    Button {
        visible: sec.filter === ""
        text: sec.showAll ? "Only the ones that start" : "Show every app"
        onClicked: sec.showAll = !sec.showAll
    }

    Label { text: "AppImages"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        icon: "folder"; title: "Folder"; desc: "AppImages in here can be added to your apps"
        Field { text: sec.appDir; onAccepted: v => { if (v.trim() !== "" && v.trim() !== sec.appDir) { Store.set("software.appimages", v.trim()); sec.load(); } } }
    }
    Label { visible: sec.images.length === 0; text: "No AppImages in that folder yet."; muted: true; Layout.leftMargin: 6 }
    Repeater {
        model: sec.images
        SettingRow {
            required property var modelData
            icon: "deployed_code"; title: modelData.name
            desc: (modelData.size / 1048576).toFixed(0) + " MB" + (modelData.added ? "  ·  in your apps" : "")
            Row {
                spacing: 6
                Button { text: "Run"; onClicked: Quickshell.execDetached(["sh", "-c", "chmod +x \"$1\" && exec \"$1\"", "_", modelData.file]) }
                Button { text: modelData.added ? "Remove" : "Add to apps"; primary: !modelData.added; onClicked: sec.run(["appimage", modelData.added ? "remove" : "add", modelData.file]) }
            }
        }
    }

    // ── cleanup: what can go (Portage, pacman, AUR, Flatpak, whichever are here) ──
    readonly property string cleanScript: Qt.resolvedUrl("../../scripts/cleanup.sh").toString().replace("file://", "")
    property var checks: []
    Process {
        id: checkProc
        running: true
        command: ["sh", sec.cleanScript, "status"]
        stdout: StdioCollector { onStreamFinished: sec.checks = text.split("\n").filter(l => l).map(l => l.split("\t")) }
    }
    Label { text: "Clean up"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    Repeater {
        model: sec.checks
        SettingRow {
            required property var modelData
            icon: ({ world: "list_alt", depclean: "account_tree", distfiles: "download", orphans: "account_tree", pkgcache: "inventory_2", aurcache: "build", flatunused: "deployed_code", flatdata: "folder_delete" })[modelData[0]] || "cleaning_services"
            title: modelData[1]; desc: modelData[2]
            // the cleaning runs in a terminal and asks before removing anything
            Button {
                text: modelData[0] === "world" ? "Show" : "Clean…"
                onClicked: { HubState.close(); Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh \"$1\" run \"$2\"", "_", sec.cleanScript, modelData[0]]); }
            }
        }
    }
    Button { text: "Check again"; icon: "refresh"; onClicked: checkProc.running = true }
}
