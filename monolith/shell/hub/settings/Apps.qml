import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Software → Apps: which apps show in the launcher. Every installed app with a switch (off: hidden
// from the launcher, still installed), a search box, a Hidden filter, Show all, and a button to
// open any of them (a hidden one too).
ColumnLayout {
    id: sec
    spacing: 8
    // ── hidden apps: still installed, just not in the launcher ──
    readonly property var hiddenIds: Store.get("search.hidden", []) || []
    property string appFilter: ""
    property bool onlyHidden: false
    readonly property var allApps: { let _ = Store.revision; return DesktopEntries.applications.values.filter(a => !a.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name)); }
    readonly property var listedApps: allApps.filter(a => (!onlyHidden || hiddenIds.indexOf(a.id) !== -1)
        && (appFilter.trim() === "" || a.name.toLowerCase().indexOf(appFilter.trim().toLowerCase()) !== -1))
    function setShown(id, on) { Store.set("search.hidden", on ? hiddenIds.filter(x => x !== id) : hiddenIds.concat([id])); }
    SettingRow {
        key: "search.hidden";
        icon: "visibility_off"; title: "Apps in the launcher"
        desc: sec.hiddenIds.length === 0 ? "All shown. Switch one off to hide it (it stays installed), or right-click it in the launcher → Hide"
                                          : sec.hiddenIds.length + (sec.hiddenIds.length === 1 ? " app hidden" : " apps hidden") + ": still installed, just not in the launcher"
        Button { visible: sec.hiddenIds.length > 0; text: "Show all"; onClicked: Store.set("search.hidden", []) }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Field { Layout.fillWidth: true; placeholder: "Find an app"; onTextChanged: sec.appFilter = text }
        Segmented { width: 220; opts: [["all", "All apps"], ["hidden", "Hidden"]]; value: sec.onlyHidden ? "hidden" : "all"; onPicked: v => sec.onlyHidden = v === "hidden" }
    }
    Repeater {
        model: sec.listedApps
        Rectangle {
            required property var modelData
            readonly property bool shown: sec.hiddenIds.indexOf(modelData.id) === -1
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Theme.corner(52, 2)
            color: Theme.containerHigh
            opacity: shown ? 1 : 0.6
            Image { id: hi; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; sourceSize: Qt.size(52, 52); source: Quickshell.iconPath(parent.modelData.icon, "application-x-executable"); asynchronous: true; smooth: true; mipmap: true }
            Column {
                anchors.left: hi.right; anchors.leftMargin: 12; anchors.right: ob.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Label { width: parent.width; elide: Text.ElideRight; text: parent.parent.modelData.name }
                Label {
                    width: parent.width; elide: Text.ElideRight
                    readonly property var e: parent.parent.modelData
                    text: (parent.parent.shown ? "" : "Hidden · ") + (e.comment || e.genericName || e.id)
                    muted: true; font.pixelSize: Theme.sizeSmall - 1
                }
            }
            // open it from here (handy for a hidden one)
            Pressable {
                id: ob
                anchors.right: tg.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                color: hovered ? Theme.control : "transparent"
                onClicked: parent.modelData.execute()
                Icon { anchors.centerIn: parent; name: "open_in_new"; size: 17; color: Theme.subtext }
            }
            Toggle { id: tg; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; checked: parent.shown; onToggled: on => sec.setShown(parent.modelData.id, on) }
        }
    }
    Label { visible: sec.listedApps.length === 0; text: sec.onlyHidden ? "No hidden apps" : "No app matches"; muted: true; Layout.leftMargin: 6 }
}
