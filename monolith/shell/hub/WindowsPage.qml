import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Windows: every workspace with its windows as cards (icon, app, title). Click a window to
// go to it, right-click closes it; ←/→/↑/↓ and Enter work from the keyboard. Also the
// window switcher (hub open windows) and a way into niri's own overview.
Page {
    id: page
    pageId: "windows"
    implicitHeight: Math.min(560, col.implicitHeight)

    readonly property var groups: {
        const out = [];
        for (const ws of Niri.workspaces) {
            const wins = [];
            for (const k in Niri.windows) if (Niri.windows[k].workspace_id === ws.id) wins.push(Niri.windows[k]);
            wins.sort((a, b) => {
                const pa = a.layout && a.layout.pos_in_scrolling_layout ? a.layout.pos_in_scrolling_layout : [999, 0];
                const pb = b.layout && b.layout.pos_in_scrolling_layout ? b.layout.pos_in_scrolling_layout : [999, 0];
                return pa[0] - pb[0] || pa[1] - pb[1];
            });
            if (wins.length > 0 || ws.is_active) out.push({ ws: ws, wins: wins });
        }
        return out;
    }
    readonly property var flat: groups.reduce((acc, g) => acc.concat(g.wins), [])
    property int sel: 0
    onCurrentChanged: if (current) sel = Math.max(0, flat.findIndex(w => w.id === Niri.focusedWindowId))

    function iconOf(w) {
        const e = DesktopEntries.byId(w.app_id || "");
        return Quickshell.iconPath(e ? e.icon : (w.app_id || ""), "application-x-executable");
    }
    function go(w) { Niri.action(["focus-window", "--id", String(w.id)]); HubState.close(); }

    Keys.onLeftPressed: sel = Math.max(0, sel - 1)
    Keys.onRightPressed: sel = Math.min(flat.length - 1, sel + 1)
    Keys.onUpPressed: sel = Math.max(0, sel - 4)
    Keys.onDownPressed: sel = Math.min(flat.length - 1, sel + 4)
    Keys.onReturnPressed: if (flat[sel]) go(flat[sel])
    Keys.onDeletePressed: if (flat[sel]) Niri.action(["close-window", "--id", String(flat[sel].id)])

    // scrolls when there's more than fits
    Flickable {
        id: scroller
        SmoothWheel {}
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Label { Layout.leftMargin: 6; text: page.flat.length + (page.flat.length === 1 ? " window" : " windows"); strong: true }
                Item { Layout.fillWidth: true }
                Pressable {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: ovRow.implicitWidth + 24
                    onClicked: { HubState.close(); Niri.action(["toggle-overview"]); }
                    Row {
                        id: ovRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: "grid_view"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: Niri.hyprland ? "Overview (hyprexpo)" : "niri overview"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            Repeater {
                model: page.groups
                Rectangle {
                    id: grp
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: grid.implicitHeight + 46
                    radius: Theme.corner(56, 8)
                    color: Theme.container
                    Row {
                        x: 14; y: 12
                        spacing: 8
                        Rectangle {
                            width: 22; height: 22
                            radius: Theme.corner(22)
                            color: grp.modelData.ws.is_active ? Theme.accent : Theme.control
                            Label { anchors.centerIn: parent; text: grp.modelData.ws.idx; font.pixelSize: Theme.sizeSmall; color: grp.modelData.ws.is_active ? Theme.onAccent : Theme.text; strong: true }
                        }
                        Label { text: (grp.modelData.ws.name && grp.modelData.ws.name !== String(grp.modelData.ws.idx) ? grp.modelData.ws.name + " · " : "") + grp.modelData.ws.output; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                    GridLayout {
                        id: grid
                        x: 8; y: 40
                        width: parent.width - 16
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        Label { visible: grp.modelData.wins.length === 0; text: "Empty"; muted: true; Layout.margins: 6 }
                        Repeater {
                            model: grp.modelData.wins
                            Pressable {
                                id: card
                                required property var modelData
                                readonly property bool isSel: !!page.flat[page.sel] && page.flat[page.sel].id === modelData.id
                                readonly property bool isFocused: modelData.id === Niri.focusedWindowId
                                Layout.fillWidth: true
                                Layout.preferredHeight: 92
                                radius: Theme.corner(92, 2)
                                color: isSel ? Theme.selected : Theme.containerHigh
                                border.width: isFocused ? 2 : 0
                                border.color: Theme.accent
                                onClicked: page.go(modelData)
                                onRightClicked: Niri.action(["close-window", "--id", String(modelData.id)])
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6
                                    Image { width: 32; height: 32; sourceSize: Qt.size(64, 64); source: page.iconOf(card.modelData); smooth: true; mipmap: true }
                                    Label { width: parent.width; text: card.modelData.title || card.modelData.app_id; font.pixelSize: Theme.sizeSmall; maximumLineCount: 2; wrapMode: Text.Wrap }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
