import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Bar → Layout & modules: the bar's shape and height, which modules sit in each zone (left,
// centre, right) and in what order, and the modules' own looks.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var names: ({
        cc: ["Control center", "page_info"], search: ["Search", "search"], clock: ["Clock", "schedule"], weather: ["Weather", "partly_cloudy_day"],
        workspaces: ["Workspaces", "view_week"], media: ["Now playing", "music_note"], title: ["Window title", "title"],
        live: ["Running tasks", "radio_button_checked"], tray: ["Tray", "apps"], stats: ["System stats", "memory"],
        notifications: ["Notifications", "notifications"], network: ["Network", "wifi"], sound: ["Sound", "volume_up"],
        battery: ["Battery", "battery_full"], keyboard: ["Keyboard layout", "keyboard"], gaming: ["Game mode", "sports_esports"],
        power: ["Power", "power_settings_new"]
    })
    readonly property var defaults: ({ left: ["cc", "search", "clock", "workspaces"], center: ["media"], right: ["live", "gaming", "tray", "stats", "notifications", "network", "sound", "battery", "power"] })
    readonly property var zones: Store.get("bar.modules", null) || defaults
    readonly property var zoneKeys: [["left", "Left"], ["center", "Centre"], ["right", "Right"]]
    readonly property var used: [].concat(zones.left || [], zones.center || [], zones.right || [])
    readonly property var unused: Object.keys(names).filter(k => used.indexOf(k) === -1)

    function save(z) { Store.set("bar.modules", z); }
    function copy() { return { left: (zones.left || []).slice(), center: (zones.center || []).slice(), right: (zones.right || []).slice() }; }

    SettingRow {
        icon: "toolbar"; title: "Shape"; desc: "The island in the middle, or a bar across the whole top"
        Segmented { width: 260; opts: [["island", "Island"], ["full", "Full width"]]; value: Store.get("bar.shape", "island"); onPicked: v => Store.set("bar.shape", v) }
    }
    SettingRow {
        icon: "height"; title: "Height"
        NumberBox { from: 28; to: 72; slideTo: 60; unit: "px"; value: Theme.islandH; onMoved: v => Store.set("bar.height", v) }
    }

    // ── drag and drop: the bar's three zones, and the modules that aren't on it ──
    property bool dragging: false
    property string dragKey: ""
    property string dragFrom: ""        // left | center | right | tray
    property int dragIndex: -1
    property point dragPos: Qt.point(0, 0)
    property string overZone: ""        // the zone under the pointer while dragging
    readonly property var zoneItems: [zoneL, zoneC, zoneR]

    function zoneAt(p) {
        for (const z of zoneItems) {
            const q = editor.mapToItem(z, p.x, p.y);
            if (q.x >= 0 && q.y >= 0 && q.x <= z.width && q.y <= z.height) return z;
        }
        return null;
    }
    // where in a zone the pointer is: before the first chip whose middle is past it
    function indexIn(z, p) {
        const q = editor.mapToItem(z.flow, p.x, p.y);
        let n = 0;
        for (let i = 0; i < z.rep.count; i++) {
            const it = z.rep.itemAt(i);
            if (!it) continue;
            const cy = it.y + it.height / 2, cx = it.x + it.width / 2;
            if (cy < q.y - it.height / 2 || (Math.abs(cy - q.y) <= it.height / 2 && cx < q.x)) n++;
        }
        return n;
    }
    function dropAt(p) {
        const z = zoneAt(p);
        const c = copy();
        if (dragFrom !== "tray") c[dragFrom].splice(dragIndex, 1);
        if (z) {
            let i = indexIn(z, p);
            if (z.zone === dragFrom && dragIndex < i) i--;
            c[z.zone].splice(Math.max(0, Math.min(i, c[z.zone].length)), 0, dragKey);
        }
        // dropped off the bar: a module from the bar is removed
        if (z || dragFrom !== "tray") save(c);
    }

    // a module chip: grab it and move it
    component Chip: Rectangle {
        id: chip
        property string key: ""
        property string zone: ""
        property int pos: -1            // its place in the zone
        readonly property bool moving: sec.dragging && sec.dragKey === key && sec.dragFrom === zone
        height: 36
        width: Math.min(cr.implicitWidth + 24, parent ? parent.width : 400)
        radius: Theme.corner(36)
        clip: true
        color: zone === "tray" ? Theme.control : Theme.containerHigh
        border.width: 1
        border.color: Theme.ringTrack
        opacity: moving ? 0.3 : 1
        Row {
            id: cr
            anchors.centerIn: parent
            spacing: 6
            Icon { name: (sec.names[chip.key] || ["", "help"])[1]; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { text: (sec.names[chip.key] || [chip.key])[0]; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point start
            onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (!pressed) return;
                if (!sec.dragging && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 6) {
                    sec.dragKey = chip.key; sec.dragFrom = chip.zone; sec.dragIndex = chip.pos; sec.dragging = true;
                }
                if (sec.dragging) {
                    sec.dragPos = mapToItem(editor, mouse.x, mouse.y);
                    const z = sec.zoneAt(sec.dragPos);
                    sec.overZone = z ? z.zone : "";
                }
            }
            onReleased: { if (sec.dragging) { sec.dropAt(sec.dragPos); sec.dragging = false; sec.overZone = ""; } }
            onCanceled: { sec.dragging = false; sec.overZone = ""; }
        }
    }

    // a zone of the bar: its chips in order
    component BarZone: Rectangle {
        id: bz
        property string zone: ""
        property string label: ""
        property alias flow: zflow
        property alias rep: zrep
        readonly property var list: sec.zones[zone] || []
        height: Math.max(64, zflow.implicitHeight + 34)
        radius: Theme.corner(64, 4)
        color: sec.overZone === zone ? Qt.alpha(Theme.accent, 0.14) : Theme.container
        border.width: sec.overZone === zone ? 2 : 1
        border.color: sec.overZone === zone ? Theme.accent : Theme.ringTrack
        Behavior on color { ColorAnimation { duration: 120 } }
        Label { x: 12; y: 6; text: bz.label; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
        Flow {
            id: zflow
            x: 8; y: 24
            width: parent.width - 16
            spacing: 6
            Repeater {
                id: zrep
                model: bz.list
                Chip { required property string modelData; required property int index; key: modelData; zone: bz.zone; pos: index }
            }
        }
        Label { visible: bz.list.length === 0; anchors.centerIn: parent; anchors.verticalCenterOffset: 8; text: "Drop modules here"; muted: true; font.pixelSize: Theme.sizeSmall }
    }

    Item {
        id: editor
        Layout.fillWidth: true
        implicitHeight: ecol.implicitHeight
        Column {
            id: ecol
            width: parent.width
            spacing: 10
            Label { width: parent.width; wrapMode: Text.Wrap; text: "Drag the modules where you want them on the bar. Drag one off the bar to take it away, or from below onto the bar to add it."; muted: true }
            // the bar, as three zones
            Rectangle {
                width: parent.width
                height: zrow.height + 16
                radius: Theme.corner(80, 8)
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW)
                border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                Row {
                    id: zrow
                    x: 8; y: 8
                    width: parent.width - 16
                    spacing: 8
                    readonly property real zw: (width - 16) / 3
                    BarZone { id: zoneL; width: zrow.zw; zone: "left"; label: "Left" }
                    BarZone { id: zoneC; width: zrow.zw; zone: "center"; label: "Middle" }
                    BarZone { id: zoneR; width: zrow.zw; zone: "right"; label: "Right" }
                }
            }
            // what isn't on the bar
            Rectangle {
                width: parent.width
                height: tflow.implicitHeight + 40
                radius: Theme.corner(80, 6)
                color: sec.dragging && sec.dragFrom !== "tray" && sec.overZone === "" ? Qt.alpha(Theme.danger, 0.12) : Theme.containerHigh
                border.width: 1
                border.color: Theme.ringTrack
                Label { x: 12; y: 8; text: sec.dragging && sec.dragFrom !== "tray" ? "Drop here to take it off the bar" : "Not on the bar (drag onto it to add)"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                Flow {
                    id: tflow
                    x: 8; y: 28
                    width: parent.width - 16
                    spacing: 6
                    Repeater {
                        model: sec.unused
                        Chip { required property string modelData; key: modelData; zone: "tray" }
                    }
                }
                Label { visible: sec.unused.length === 0; x: 12; y: 30; text: "Everything is on the bar"; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
        // the chip being carried
        Rectangle {
            visible: sec.dragging
            z: 100
            x: sec.dragPos.x - width / 2
            y: sec.dragPos.y - height / 2
            height: 38
            width: gr.implicitWidth + 26
            radius: Theme.corner(38)
            color: Theme.accentContainer
            border.width: 2
            border.color: Theme.accent
            Row {
                id: gr
                anchors.centerIn: parent
                spacing: 6
                Icon { name: (sec.names[sec.dragKey] || ["", "help"])[1]; size: 17; color: Theme.onAccentContainer; anchors.verticalCenter: parent.verticalCenter }
                Label { text: (sec.names[sec.dragKey] || [sec.dragKey])[0]; strong: true; color: Theme.onAccentContainer; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Button { text: "Back to the default modules"; icon: "restart_alt"; onClicked: Store.set("bar.modules", null) }

    // the modules' looks
    Label { text: "Modules"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        icon: "schedule"; title: "Clock"
        Segmented { width: 340; opts: [["stacked", "Stacked"], ["simple", "Time"], ["full", "Time + date"], ["seconds", "Seconds"]]; value: Store.get("bar.clockStyle", "stacked"); onPicked: v => Store.set("bar.clockStyle", v) }
    }
    SettingRow {
        icon: "view_week"; title: "Workspaces"
        Segmented { width: 280; opts: [["pills", "Pills"], ["dots", "Dots"], ["numbers", "Numbers"]]; value: Store.get("bar.workspaces", "pills"); onPicked: v => Store.set("bar.workspaces", v) }
    }
    SettingRow {
        icon: "memory"; title: "System stats"; desc: "Which ones show"
        Row {
            spacing: 4
            Repeater {
                model: [["cpu", "CPU"], ["mem", "Memory"], ["temp", "Temperature"], ["gpu", "GPU"]]
                Pressable {
                    required property var modelData
                    readonly property var which: Store.get("bar.stats", ["cpu", "temp"])
                    readonly property bool on: which.indexOf(modelData[0]) !== -1
                    height: 32; width: sl.implicitWidth + 24
                    color: on ? Theme.accentContainer : Theme.control
                    onClicked: Store.set("bar.stats", on ? which.filter(x => x !== modelData[0]) : which.concat([modelData[0]]))
                    Label { id: sl; anchors.centerIn: parent; text: parent.modelData[1]; strong: parent.on; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }
    SettingRow {
        icon: "volume_up"; title: "Volume number"; desc: "Beside the sound icon"
        Toggle { checked: Store.get("bar.soundPercent", true) !== false; onToggled: on => Store.set("bar.soundPercent", on) }
    }
}
