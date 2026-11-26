import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import "../../core/barmods.js" as BarMods

// Mini bars (island/MiniBars.qml): little bars of their own, each with the modules you put in it,
// at a corner or the middle of an edge. A module put in one stays in the bar too (it's a copy):
// take it out of the bar in Layout & modules if you want it only here.
ColumnLayout {
    id: page
    spacing: 8
    readonly property var minis: { const v = Store.get("bar.minis", []); return v && typeof v === "object" && v.length !== undefined ? Array.prototype.slice.call(v) : []; }
    function copy() { return JSON.parse(JSON.stringify(minis)); }
    readonly property var places: [["top-left", "Top left corner"], ["top", "Top, in the middle"], ["top-right", "Top right corner"],
                                   ["left", "Left side"], ["right", "Right side"],
                                   ["bottom-left", "Bottom left corner"], ["bottom", "Bottom, in the middle"], ["bottom-right", "Bottom right corner"]]
    function add() {
        const l = copy();
        // (a spot no other one has yet, if there is one)
        const used = l.map(m => m.place);
        const free = ["top-right", "top-left", "bottom-right", "bottom-left", "top", "bottom", "right", "left"].find(p => used.indexOf(p) === -1) || "top-right";
        l.push({ place: free, modules: [], reserve: false });
        Store.set("bar.minis", l);
    }
    function remove(i) { const l = copy(); l.splice(i, 1); Store.set("bar.minis", l); }
    function setOf(i, k, v) { const l = copy(); if (!l[i]) return; l[i][k] = v; Store.set("bar.minis", l); }
    // a module into mini bar i (the bar keeps its own: it took it out before, and a module you
    // wanted in both places vanished from the bar)
    function addModule(i, key) {
        const l = copy();
        if (!l[i]) return;
        l[i].modules = (l[i].modules || []).filter(k => k !== key).concat([key]);
        Store.set("bar.minis", l);
    }
    function removeModule(i, key) { const l = copy(); if (!l[i]) return; l[i].modules = (l[i].modules || []).filter(k => k !== key); Store.set("bar.minis", l); }
    function moveModule(i, from, to) {
        const l = copy(); if (!l[i]) return;
        const m = l[i].modules || [];
        if (to < 0 || to >= m.length) return;
        const it = m.splice(from, 1)[0]; m.splice(to, 0, it); l[i].modules = m;
        Store.set("bar.minis", l);
    }

    SettingRow {
        key: "bar.minis"
        icon: "view_agenda"; title: "Mini bars"
        desc: "Little bars of their own, each with the modules you put in it, in a corner, the middle of an edge or down a side. Modules stay in the bar too (take one out in Layout & modules if you want it only here). Hold a mini bar to move it on the screen"
        Row {
            spacing: 6
            Button { visible: page.minis.length > 0; text: "Move them"; icon: "open_with"; onClicked: HubState.editMinis() }
            Button { text: "Add a mini bar"; icon: "add"; primary: true; onClicked: page.add() }
        }
    }

    Repeater {
        model: page.minis
        SmoothRect {
            id: card
            required property var modelData
            required property int index
            // (lists handed through a Repeater aren't always JS Arrays: read it from the store itself)
            readonly property var mods: { const m = page.minis[index]; const l = m && m.modules ? Array.prototype.slice.call(m.modules) : []; return l.filter(k => k !== "taskbar"); }
            Layout.fillWidth: true
            implicitHeight: col.implicitHeight + 28
            radius: Theme.corner(80, 10)
            color: Theme.container
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            Column {
                id: col
                x: 14; y: 14
                width: card.width - 28
                spacing: 10
                // its name, its spot, windows keeping clear, away with it
                Item {
                    width: col.width; height: 40
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "view_agenda"; size: 18; color: Theme.accent; filled: true }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: "Mini bar " + (card.index + 1); strong: true }
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Dropdown {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 210
                            opts: page.places
                            value: String(card.modelData.place || "top-right")
                            onPicked: v => page.setOf(card.index, "place", v)
                        }
                        Pressable {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36
                            color: hovered ? Qt.alpha(Theme.danger, 0.15) : "transparent"
                            onClicked: page.remove(card.index)
                            Icon { anchors.centerIn: parent; name: "delete"; size: 19; color: Theme.danger }
                        }
                    }
                }
                // its modules, in order: click one to take it out, the arrows move it along
                Flow {
                    width: col.width
                    spacing: 6
                    Repeater {
                        model: card.mods
                        SmoothRect {
                            required property string modelData
                            required property int index
                            readonly property var info: BarMods.names[modelData] || [modelData, "widgets"]
                            smoothing: 0
                            height: 34
                            width: chipRow.implicitWidth + 12
                            radius: Theme.corner(34)
                            color: Theme.accentContainer
                            Row {
                                id: chipRow
                                x: 6; anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Pressable {
                                    visible: index > 0
                                    width: 24; height: 24; radius: 12; color: hovered ? Qt.alpha(Theme.text, 0.12) : "transparent"
                                    onClicked: page.moveModule(card.index, index, index - 1)
                                    Icon { anchors.centerIn: parent; name: "chevron_left"; size: 16; color: Theme.onAccentContainer }
                                }
                                Icon { anchors.verticalCenter: parent.verticalCenter; name: info[1]; size: 16; color: Theme.onAccentContainer }
                                Label { anchors.verticalCenter: parent.verticalCenter; text: info[0]; color: Theme.onAccentContainer; font.pixelSize: Theme.sizeSmall }
                                Pressable {
                                    visible: index < card.mods.length - 1
                                    width: 24; height: 24; radius: 12; color: hovered ? Qt.alpha(Theme.text, 0.12) : "transparent"
                                    onClicked: page.moveModule(card.index, index, index + 1)
                                    Icon { anchors.centerIn: parent; name: "chevron_right"; size: 16; color: Theme.onAccentContainer }
                                }
                                Pressable {
                                    width: 24; height: 24; radius: 12; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"
                                    onClicked: page.removeModule(card.index, modelData)
                                    Icon { anchors.centerIn: parent; name: "close"; size: 15; color: Theme.onAccentContainer }
                                }
                            }
                        }
                    }
                    Label { visible: card.mods.length === 0; height: 34; verticalAlignment: Text.AlignVCenter; text: "Empty: add modules below (an empty one isn't shown)"; muted: true }
                }
                Item {
                    width: col.width; height: 40
                    Dropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 230
                        opts: [["", "Add a module…"]].concat(Object.keys(BarMods.names).filter(k => card.mods.indexOf(k) === -1).map(k => [k, BarMods.names[k][0]]))
                        value: ""
                        onPicked: v => { if (v !== "") page.addModule(card.index, v); }
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Label { anchors.verticalCenter: parent.verticalCenter; text: "Windows keep clear of it"; font.pixelSize: Theme.sizeSmall }
                        Toggle { anchors.verticalCenter: parent.verticalCenter; checked: card.modelData.reserve === true; onToggled: on => page.setOf(card.index, "reserve", on) }
                    }
                }
            }
        }
    }
}
