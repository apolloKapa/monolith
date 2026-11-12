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
    property var apps: []
    property string filter: ""
    property bool showAll: false

    function load() { appsProc.running = true; }
    Component.onCompleted: { load(); AppImages.hold(); }
    Component.onDestruction: AppImages.release()
    Process { id: appsProc; command: ["python3", sec.script, "apps"]; stdout: StdioCollector { onStreamFinished: { try { sec.apps = JSON.parse(text); } catch (e) {} } } }
    Process { id: act; onExited: sec.load() }
    function run(args) { act.command = ["python3", sec.script].concat(args); act.running = true; }

    readonly property var matching: {
        const f = filter.toLowerCase();
        return apps.filter(a => f === "" ? (showAll || a.on) : a.name.toLowerCase().includes(f));
    }
    readonly property var shownApps: matching.slice(0, 40)

    Label { text: "Start at login"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
    SettingRow {
        icon: "rocket_launch"; title: "Startup apps"
        desc: { const n = sec.apps.filter(a => a.on).length; return (n === 0 ? "Nothing starts" : n === 1 ? "1 app starts" : n + " apps start") + " when you log in. Search for an app (or show them all) and switch it on"; }
        RowLayout {
            spacing: 6
            Field { width: 200; placeholder: "Find an app"; onTextChanged: sec.filter = text.trim() }
            Button { visible: sec.filter === ""; text: sec.showAll ? "Only these" : "All apps"; onClicked: sec.showAll = !sec.showAll }
        }
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
    Label { visible: sec.matching.length > sec.shownApps.length; Layout.leftMargin: 6; text: (sec.matching.length - sec.shownApps.length) + " more: type part of a name to find them"; muted: true; font.pixelSize: Theme.sizeSmall }

    Label { text: "AppImages"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        icon: "upload_file"; title: "The AppImages window"; desc: "Drop an AppImage on it and it's set up like an installed app (Mod+I, or AppImages in the launcher)"
        Button { text: "Open"; primary: true; icon: "open_in_new"; onClicked: { HubState.close(); AppImages.opened = true; } }
    }
    SettingRow {
        key: "software.appimages";
        icon: "folder"; title: "AppImage folder"; desc: "Where dropped AppImages go"
        Field { text: AppImages.folder.replace(Quickshell.env("HOME"), "~"); onAccepted: v => { const p = v.trim().replace(/^~/, Quickshell.env("HOME")); if (p !== "" && p !== AppImages.folder) Store.set("software.appimages", p); } }
    }
    SettingRow {
        key: "software.appimagesAuto";
        icon: "auto_mode"; title: "Set up AppImages put in the folder"; desc: "Copy one into the folder yourself and it's added to your apps; delete it and its entry goes too"
        Toggle { checked: AppImages.auto; onToggled: on => Store.set("software.appimagesAuto", on) }
    }
    Repeater {
        model: AppImages.items
        SettingRow {
            required property var modelData
            icon: "deployed_code"; title: modelData.name
            desc: (modelData.size / 1048576).toFixed(0) + " MB" + (modelData.added ? "  ·  in your apps" : "  ·  not in your apps")
            Row {
                spacing: 6
                Button { text: "Run"; onClicked: Quickshell.execDetached([modelData.file]) }
                Button { text: modelData.added ? "Remove" : "Add to apps"; primary: !modelData.added; onClicked: modelData.added ? AppImages.remove(modelData.file, false) : AppImages.add([modelData.file], true) }
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
