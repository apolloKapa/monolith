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
        live: ["Running (recording, timer, update)", "radio_button_checked"], tray: ["Tray", "apps"], stats: ["System stats", "memory"],
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
    function move(zone, i, d) {
        const z = copy(); const l = z[zone]; const j = i + d;
        if (j < 0 || j >= l.length) return;
        const t = l[i]; l[i] = l[j]; l[j] = t; save(z);
    }
    function toZone(zone, i, d) {
        const order = ["left", "center", "right"];
        const to = order[order.indexOf(zone) + d];
        if (!to) return;
        const z = copy(); const k = z[zone].splice(i, 1)[0];
        if (d > 0) z[to].unshift(k); else z[to].push(k);
        save(z);
    }
    function remove(zone, i) { const z = copy(); z[zone].splice(i, 1); save(z); }
    function add(zone, k) { const z = copy(); z[zone].push(k); save(z); }

    SettingRow {
        icon: "toolbar"; title: "Shape"; desc: "The island in the middle, or a bar across the whole top"
        Segmented { width: 260; opts: [["island", "Island"], ["full", "Full width"]]; value: Store.get("bar.shape", "island"); onPicked: v => Store.set("bar.shape", v) }
    }
    SettingRow {
        icon: "height"; title: "Height"
        NumberBox { from: 28; to: 72; slideTo: 60; unit: "px"; value: Theme.islandH; onMoved: v => Store.set("bar.height", v) }
    }

    // the three zones
    Repeater {
        model: sec.zoneKeys
        Card {
            id: zc
            required property var modelData
            readonly property string zone: modelData[0]
            readonly property var list: sec.zones[zone] || []
            Layout.fillWidth: true
            Layout.preferredHeight: 48 + zcol.implicitHeight + 2 * pad
            icon: zone === "left" ? "align_horizontal_left" : (zone === "center" ? "align_horizontal_center" : "align_horizontal_right")
            title: modelData[1] + "  ·  " + list.length + (list.length === 1 ? " module" : " modules")
            Column {
                id: zcol
                width: parent.width
                spacing: 4
                Repeater {
                    model: zc.list
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: zcol.width
                        height: 42
                        radius: Theme.corner(42, 2)
                        color: Theme.containerHigh
                        Icon { id: mi; x: 12; anchors.verticalCenter: parent.verticalCenter; name: (sec.names[parent.modelData] || ["", "help"])[1]; size: 18; color: Theme.accent }
                        Label { anchors.left: mi.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: (sec.names[parent.modelData] || [parent.modelData])[0] }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            component Btn: Pressable {
                                property string icon: ""
                                width: 32; height: 32
                                color: hovered ? Theme.control : "transparent"
                                Icon { anchors.centerIn: parent; name: parent.icon; size: 17 }
                            }
                            Btn { icon: "arrow_upward"; onClicked: sec.move(zc.zone, index, -1) }
                            Btn { icon: "arrow_downward"; onClicked: sec.move(zc.zone, index, 1) }
                            Btn { visible: zc.zone !== "left"; icon: "arrow_back"; onClicked: sec.toZone(zc.zone, index, -1) }
                            Btn { visible: zc.zone !== "right"; icon: "arrow_forward"; onClicked: sec.toZone(zc.zone, index, 1) }
                            Btn { icon: "close"; onClicked: sec.remove(zc.zone, index) }
                        }
                    }
                }
                // add one that isn't on the bar
                Flow {
                    width: zcol.width
                    spacing: 4
                    visible: sec.unused.length > 0
                    topPadding: 4
                    Repeater {
                        model: sec.unused
                        Pressable {
                            required property string modelData
                            height: 30
                            width: al.implicitWidth + 40
                            color: Theme.control
                            onClicked: sec.add(zc.zone, modelData)
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { name: "add"; size: 15; anchors.verticalCenter: parent.verticalCenter }
                                Label { id: al; text: (sec.names[parent.parent.modelData] || [parent.parent.modelData])[0]; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
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
