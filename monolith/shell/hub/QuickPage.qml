import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../ui"

// The control center: three tabs (Controls, Overview, Monitor), each its own file in cc/.
// Notifications have their own page. The island grows to fit the open tab.
Page {
    id: page
    pageId: "quick"
    readonly property var tabs: [["controls", "Controls", "toggle_on"], ["overview", "Overview", "dashboard"], ["monitor", "Monitor", "monitoring"]]
    readonly property string tab: tabs.some(t => t[0] === HubState.ccTab) ? HubState.ccTab : "controls"
    implicitHeight: nav.height + 10 + (body.item ? body.item.implicitHeight : 300)

    // ←/→ switch tabs when nothing else wants them
    Keys.onLeftPressed: HubState.ccTab = tabs[Math.max(0, tabs.findIndex(t => t[0] === tab) - 1)][0]
    Keys.onRightPressed: HubState.ccTab = tabs[Math.min(tabs.length - 1, tabs.findIndex(t => t[0] === tab) + 1)][0]

    // you and the time of day on the left, the tabs on the right
    readonly property string hello: { const h = new Date().getHours(); return h < 5 ? "Good night" : (h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")); }
    RowLayout {
        id: nav
        width: parent.width
        height: 52
        spacing: 12
        Avatar { size: 44; Layout.leftMargin: 4 }
        Column {
            Layout.fillWidth: true
            spacing: 1
            Label { width: parent.width; text: page.hello + ", " + (Quickshell.env("USER") || "you"); strong: true; font.pixelSize: Theme.sizeTitle }
            Label { width: parent.width; text: Qt.formatDateTime(new Date(), "dddd d MMMM") + "  ·  up " + page.uptime; muted: true; font.pixelSize: Theme.sizeSmall + 1 }
        }
        IconTabs {
            Layout.fillWidth: false
            Layout.preferredWidth: 440
            opts: page.tabs
            value: page.tab
            onPicked: v => HubState.ccTab = v
        }
    }
    // how long it's been up, refreshed each minute while the page is open
    property string uptime: ""
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true }
    Timer {
        interval: 60000; repeat: true; running: page.current; triggeredOnStart: true
        onTriggered: { upFile.reload(); const t = Math.floor(parseFloat(upFile.text())); if (!isNaN(t)) page.uptime = Wellbeing.fmt(t); }
    }

    Loader {
        id: body
        y: nav.height + 10
        width: parent.width
        source: "cc/" + page.tab.charAt(0).toUpperCase() + page.tab.slice(1) + ".qml"
    }

}
