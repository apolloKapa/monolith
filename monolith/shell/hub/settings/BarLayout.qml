import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import "../../island"

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
        power: ["Power", "power_settings_new"], updates: ["Monolith updates", "upgrade"],
        bluetooth: ["Bluetooth", "bluetooth"], visualizer: ["Visualizer", "graphic_eq"], nightlight: ["Night light", "nightlight"],
        awake: ["Stay awake", "coffee"], shuffle: ["Shuffle wallpaper", "shuffle"]
    })
    readonly property var defaults: ({ left: ["cc", "search", "clock", "workspaces"], center: ["media"], right: ["updates", "live", "gaming", "tray", "stats", "notifications", "network", "sound", "battery", "power"] })
    readonly property var zones: Store.get("bar.modules", null) || defaults
    readonly property var zoneKeys: [["left", "Left"], ["center", "Centre"], ["right", "Right"]]
    readonly property var used: [].concat(zones.left || [], zones.center || [], zones.right || [])
    readonly property var unused: Object.keys(names).filter(k => used.indexOf(k) === -1)

    function save(z) { Store.set("bar.modules", z); }
    function copy() { return { left: (zones.left || []).slice(), center: (zones.center || []).slice(), right: (zones.right || []).slice() }; }

    // the bar as it is now, live
    BarPreview { Layout.fillWidth: true; Layout.bottomMargin: 6 }

    // a style choice shown as the module itself, drawn in each style
    component StylePick: Flow {
        id: sp
        property string module: "clock"
        property var opts: []
        property string value: ""
        signal picked(string v)
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: sp.opts
            Pressable {
                id: card
                required property var modelData
                readonly property bool on: sp.value === modelData[0]
                width: Math.max(120, mod.implicitWidth + 28); height: Theme.islandH + 46
                color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.container)
                border.width: on ? 2 : 0; border.color: Theme.accent
                onClicked: sp.picked(modelData[0])
                Rectangle {
                    x: 8; y: 8; width: parent.width - 16; height: Theme.islandH
                    radius: height / 2; color: Theme.frame; clip: true
                    IslandBar {
                        id: mod
                        anchors.centerIn: parent
                        enabled: false
                        // (this screen's workspaces: with no screen it had none, and the cards were blank)
                        screenName: Niri.focusedOutput || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
                        only: [sp.module]
                        clockStyleAs: sp.module === "clock" ? card.modelData[0] : ""
                        wsStyleAs: sp.module === "workspaces" ? card.modelData[0] : ""
                        wsSample: sp.module === "workspaces"
                    }
                }
                Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: card.modelData[1]; strong: card.on; font.pixelSize: Theme.sizeSmall; color: card.on ? Theme.onAccentContainer : Theme.text }
            }
        }
    }

    // the bar's style: five cards, each a little picture of it
    Row {
        Layout.leftMargin: 6
        spacing: 10
        Label { text: "Style"; strong: true; anchors.verticalCenter: parent.verticalCenter }
        // changed from the default (Island): put it back
        Pressable {
            visible: Store.has("bar.style") && Store.get("bar.style", "island") !== "island"
            height: 26; width: rl.implicitWidth + 34
            color: hovered ? Theme.control : "transparent"
            onClicked: { Store.unset("bar.style"); Store.unset("bar.shape"); }
            Row { id: rl; anchors.centerIn: parent; spacing: 4
                Icon { name: "settings_backup_restore"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Back to default"; font.pixelSize: Theme.sizeSmall; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter } }
        }
    }
    BarStyles { Layout.fillWidth: true }
    SettingRow {
        key: "bar.position"; def: "top";
        icon: "vertical_split"; title: "Position"
        desc: Theme.barSide !== "" ? "Down the " + Theme.barSide + " side of the screen (its menus open as cards beside it)" : "Along the " + Theme.barEdge + " of the screen (menus open out of it)"
        Dropdown {
            width: 220
            opts: [["top", "Up (top)", "Along the top edge"], ["bottom", "Down (bottom)", "Along the bottom edge"],
                   ["left", "Left", "Down the left side"], ["right", "Right", "Down the right side"]]
            value: Theme.barEdge
            onPicked: v => Store.set("bar.position", v)
        }
    }
    SettingRow {
        key: "bar.margin";
        visible: Theme.barFloats
        icon: "vertical_align_top"; title: "Space from the edge"; desc: "How far the floating bar sits from the edge of the screen"
        NumberBox { from: 0; to: 40; unit: "px"; value: Theme.barMargin; onMoved: v => Store.set("bar.margin", v) }
    }
    SettingRow {
        key: "bar.frameWidth"; def: 8;
        visible: Theme.barStyle === "frame"
        icon: "border_outer"; title: "Border width"; desc: "The frame round the screen"
        NumberBox { from: 2; to: 40; unit: "px"; value: Number(Store.get("bar.frameWidth", 8)); onMoved: v => Store.set("bar.frameWidth", v) }
    }
    SettingRow {
        key: "bar.frameRadius";
        visible: Theme.barStyle === "frame"
        icon: "rounded_corner"; title: "Border's inside corners"
        NumberBox { from: 0; to: 60; unit: "px"; value: Number(Store.get("bar.frameRadius", Theme.islandRadius)); onMoved: v => Store.set("bar.frameRadius", v) }
    }
    SettingRow {
        key: "bar.height";
        icon: "height"; title: "Height"
        NumberBox { from: 28; to: 72; slideTo: 60; unit: "px"; value: Theme.islandH; onMoved: v => Store.set("bar.height", v) }
    }
    // the bar's length: as long as its modules need, a share of the screen, or an exact size
    SettingRow {
        key: "bar.lengthMode";
        visible: Theme.barStyle !== "frame"
        icon: "width"; title: "Length"
        desc: Theme.barLengthMode === "fit" ? "As long as its modules need" : (Theme.barLengthMode === "percent" ? "A share of the screen's width" : "An exact length, the same on every screen")
        Segmented { width: 300; opts: [["fit", "Fit"], ["percent", "% of screen"], ["px", "Pixels"]]; value: Theme.barLengthMode; onPicked: v => Store.set("bar.lengthMode", v) }
    }
    SettingRow {
        key: "bar.length";
        visible: Theme.barStyle !== "frame" && Theme.barLengthMode === "percent"
        icon: "percent"; title: "Share of the screen"; desc: "Centred; it never gets shorter than its modules"
        NumberBox { from: 0.2; to: 1; step: 0.01; decimals: 2; factor: 100; unit: "%"; value: Theme.barLength; onMoved: v => Store.set("bar.length", v) }
    }
    SettingRow {
        key: "bar.lengthPx";
        visible: Theme.barStyle !== "frame" && Theme.barLengthMode === "px"
        icon: "straighten"; title: "Length in pixels"; desc: "Centred; never shorter than its modules or longer than the screen"
        NumberBox { from: 200; to: 7680; slideTo: 2560; step: 10; unit: "px"; value: Theme.barLengthPx; onMoved: v => Store.set("bar.lengthPx", v) }
    }
    SettingRow {
        key: "bar.minWidth";
        visible: Theme.barStyle !== "frame" && Theme.barLengthMode === "fit"
        icon: "expand"; title: "At least this long"; desc: "It grows from here as modules need more room"
        NumberBox { from: 200; to: 2000; slideTo: 1400; step: 10; unit: "px"; value: Theme.islandMinW; onMoved: v => Store.set("bar.minWidth", v) }
    }
    SettingRow {
        key: "bar.opacity";
        icon: "opacity"; title: "Bar opacity"; desc: "0 %: the bar disappears and only its modules stay"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.barOpacity; onMoved: v => Store.set("bar.opacity", v) }
    }
    SettingRow {
        key: "bar.pills";
        icon: "pill"; title: "Modules on their own pills"; desc: "Each module gets a small background (good with a see-through bar)"
        Toggle { checked: Theme.barPills; onToggled: on => Store.set("bar.pills", on) }
    }
    SettingRow {
        key: "bar.gap"; def: 2;
        icon: "space_bar"; title: "Space between modules"
        NumberBox { from: 0; to: 30; unit: "px"; value: Number(Store.get("bar.gap", 2)); onMoved: v => Store.set("bar.gap", v) }
    }
    SettingRow {
        key: "bar.sectionGap"; def: 14;
        icon: "horizontal_distribute"; title: "Space between left, middle and right"
        NumberBox { from: 0; to: 120; slideTo: 60; unit: "px"; value: Number(Store.get("bar.sectionGap", 14)); onMoved: v => Store.set("bar.sectionGap", v) }
    }
    SettingRow {
        icon: "monitor"; title: "Screens with a bar"; desc: "Bar → Bar & dock per screen"
        Button { text: "Open"; onClicked: HubState.settingsSection = "barscreens" }
    }

    // ── drag and drop: the bar's three zones, and the modules that aren't on it ──
    property bool dragging: false
    property string dragKey: ""
    property string dragFrom: ""        // left | center | right | tray
    property int dragIndex: -1
    property point dragPos: Qt.point(0, 0)
    property string overZone: ""        // the zone under the pointer while dragging
    readonly property var zoneItems: [zoneL, zoneC, zoneR]
    readonly property Item editorItem: editor

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
        // the editor (inline components can't see the file's ids from their handlers)
        property var ed: null
        property string key: ""
        property string zone: ""
        property int pos: -1            // its place in the zone
        readonly property bool moving: chip.ed.dragging && chip.ed.dragKey === key && chip.ed.dragFrom === zone
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
            Icon { name: (chip.ed.names[chip.key] || ["", "help"])[1]; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { text: (chip.ed.names[chip.key] || [chip.key])[0]; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point start
            onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (!pressed) return;
                if (!chip.ed.dragging && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 6) {
                    chip.ed.dragKey = chip.key; chip.ed.dragFrom = chip.zone; chip.ed.dragIndex = chip.pos; chip.ed.dragging = true;
                }
                if (chip.ed.dragging) {
                    chip.ed.dragPos = mapToItem(chip.ed.editorItem, mouse.x, mouse.y);
                    const z = chip.ed.zoneAt(chip.ed.dragPos);
                    chip.ed.overZone = z ? z.zone : "";
                }
            }
            onReleased: { if (chip.ed.dragging) { chip.ed.dropAt(chip.ed.dragPos); chip.ed.dragging = false; chip.ed.overZone = ""; } }
            onCanceled: { chip.ed.dragging = false; chip.ed.overZone = ""; }
        }
    }

    // a zone of the bar: its chips in order
    component BarZone: Rectangle {
        id: bz
        property var ed: null
        property string zone: ""
        property string label: ""
        property alias flow: zflow
        property alias rep: zrep
        readonly property var list: bz.ed.zones[zone] || []
        // what its modules need; the row makes all three as tall as the tallest
        readonly property real need: zflow.implicitHeight + 34
        height: Math.max(64, need)
        radius: Theme.corner(64, 4)
        color: bz.ed.overZone === zone ? Qt.alpha(Theme.accent, 0.14) : Theme.container
        border.width: bz.ed.overZone === zone ? 2 : 1
        border.color: bz.ed.overZone === zone ? Theme.accent : Theme.ringTrack
        Behavior on color { ColorAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
        Label { x: 12; y: 6; text: bz.label; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
        Flow {
            id: zflow
            x: 8; y: 24
            width: parent.width - 16
            spacing: 6
            Repeater {
                id: zrep
                model: bz.list
                Chip { required property string modelData; required property int index; ed: bz.ed; key: modelData; zone: bz.zone; pos: index }
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
                    // (the same height, so the three line up as one bar)
                    readonly property real zh: Math.max(64, zoneL.need, zoneC.need, zoneR.need)
                    BarZone { id: zoneL; ed: sec; width: zrow.zw; height: zrow.zh; zone: "left"; label: "Left" }
                    BarZone { id: zoneC; ed: sec; width: zrow.zw; height: zrow.zh; zone: "center"; label: "Middle" }
                    BarZone { id: zoneR; ed: sec; width: zrow.zw; height: zrow.zh; zone: "right"; label: "Right" }
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
                        Chip { required property string modelData; ed: sec; key: modelData; zone: "tray" }
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

    // the modules' looks: each shown as the module itself
    Label { text: "Modules"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    // the clock: one big live preview, and a toggle for each of its parts
    Label { text: "Clock"; strong: true; Layout.leftMargin: 6 }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(110, clockBox.height + 40)
        radius: Theme.corner(80, 10)
        color: Theme.container
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        // the clock module on a piece of bar, twice its real size
        readonly property real k: 2
        Rectangle {
            id: clockBox
            anchors.centerIn: parent
            width: (clockPrev.implicitWidth + 16) * parent.k
            height: Theme.islandH * parent.k
            radius: Theme.barRound(Theme.islandH) * parent.k
            color: Theme.frame
            Behavior on width { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
            IslandBar {
                id: clockPrev
                enabled: false
                only: ["clock"]
                scale: parent.parent.k
                transformOrigin: Item.Center
                anchors.centerIn: parent
            }
        }
        Label {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
            text: "Twice its real size"; muted: true; font.pixelSize: Theme.sizeSmall - 2
        }
    }
    SettingRow {
        key: "bar.clock.seconds";
        icon: "timer"; title: "Seconds"; desc: "Hours, minutes and seconds"
        Toggle { checked: clockPrev.clockSeconds; onToggled: on => Store.set("bar.clock.seconds", on) }
    }
    SettingRow {
        key: "bar.clock.stackTime";
        icon: "view_agenda"; title: "Hours over minutes"; desc: "The time stacked in lines instead of one row"
        Toggle { checked: clockPrev.clockStackTime; onToggled: on => Store.set("bar.clock.stackTime", on) }
    }
    SettingRow {
        key: "bar.clock.hour12";
        icon: "schedule"; title: "12-hour time"; desc: "With AM / PM"
        Toggle { checked: clockPrev.clock12; onToggled: on => Store.set("bar.clock.hour12", on) }
    }
    SettingRow {
        key: "bar.clock.date";
        icon: "calendar_today"; title: "Date"; desc: "The date beside the time"
        Toggle { checked: clockPrev.clockDate; onToggled: on => Store.set("bar.clock.date", on) }
    }
    SettingRow {
        key: "bar.clock.dateLayout";
        visible: clockPrev.clockDate
        icon: "splitscreen"; title: "Date layout"; desc: clockPrev.clockDateLayout === "stacked" ? "Two small lines beside the time" : "One line beside the time"
        Segmented { width: 240; opts: [["stacked", "Stacked"], ["inline", "One line"]]; value: clockPrev.clockDateLayout; onPicked: v => Store.set("bar.clock.dateLayout", v) }
    }
    SettingRow {
        key: "bar.clock.weekday";
        visible: clockPrev.clockDate
        icon: "event"; title: "Day of the week"; desc: "Its name with the date"
        Toggle { checked: clockPrev.clockWeekday; onToggled: on => Store.set("bar.clock.weekday", on) }
    }
    Label { text: "Workspaces"; strong: true; Layout.leftMargin: 6; Layout.topMargin: 4 }
    Label { text: "Shown with four sample workspaces: the second open, the first three with windows"; Layout.fillWidth: true; wrapMode: Text.WordWrap; muted: true; font.pixelSize: Theme.sizeSmall - 1; Layout.leftMargin: 6 }
    StylePick {
        module: "workspaces"
        opts: [["pills", "Pills"], ["dots", "Dots"], ["lines", "Lines"], ["rings", "Rings"], ["squares", "Squares"],
               ["numbers", "Numbers"], ["numberPills", "Numbered pill"], ["bubbles", "Bubbles"]]
        value: Store.get("bar.workspaces", "pills")
        onPicked: v => Store.set("bar.workspaces", v)
    }
    SettingRow {
        key: "bar.stats";
        icon: "memory"; title: "System stats"; desc: "Which ones show"
        Row {
            spacing: 4
            Repeater {
                model: [["cpu", "CPU"], ["mem", "Memory"], ["temp", "CPU °"], ["gpu", "GPU"], ["vram", "VRAM"], ["gtemp", "GPU °"]]
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
        key: "bar.mediaPeek"; def: true;
        icon: "music_note"; title: "Now playing peek"; desc: "Hovering the Now playing module shows a small player under it"
        Toggle { checked: Store.get("bar.mediaPeek", true) !== false; onToggled: on => Store.set("bar.mediaPeek", on) }
    }
    SettingRow {
        key: "bar.soundPercent"; def: true;
        icon: "volume_up"; title: "Volume number"; desc: "Beside the sound icon"
        Toggle { checked: Store.get("bar.soundPercent", true) !== false; onToggled: on => Store.set("bar.soundPercent", on) }
    }
}
