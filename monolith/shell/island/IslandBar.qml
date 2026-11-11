import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "../core"
import "../ui"
import "../wall/faces" as Faces

// The island's bar: three zones (left, centre, right), each a list of modules you arrange in
// Settings → Bar. Every module opens its page in the island.
Item {
    id: bar
    property string screenName: ""
    property var trayWindow: null                       // the window tray menus open from
    // down a side of the screen (SideBar): the zones run top to bottom, modules stack their parts
    property bool vertical: false
    readonly property real gap: Number(Store.get("bar.sectionGap", 14))
    // a zone's length along the bar
    function len(z) { return vertical ? z.height : z.width; }
    readonly property real fitLength: len(leftZone) + len(midZone) + len(rightZone) + (len(midZone) > 0 ? 2 * gap : gap) + 2 * Theme.islandPad
    implicitWidth: vertical ? Theme.islandH : fitLength
    // spread out, the middle stays in the middle: the shortest it can be without the sides running into it
    readonly property real spreadWidth: len(midZone) > 0 ? len(midZone) + 2 * Math.max(len(leftZone), len(rightZone)) + 2 * gap + 2 * Theme.islandPad : fitLength
    // the length the bar needs (its width, or its height when it's vertical)
    readonly property real needWidth: Theme.barSpread ? spreadWidth : fitLength
    implicitHeight: vertical ? fitLength : Theme.islandH
    function open(p) { HubState.toggle(p, bar.screenName); }
    // the point on a module's edge that faces into the screen (where its drop-downs hang from)
    function edgePoint(it) {
        if (vertical) return it.mapToItem(null, Theme.barSide === "right" ? 0 : it.width, it.height / 2);
        return it.mapToItem(null, it.width / 2, Theme.barBottom ? 0 : it.height);
    }

    // the modules in each zone, and every module there is
    readonly property var defaults: ({ left: ["cc", "search", "clock", "workspaces"], center: ["media"], right: ["updates", "live", "gaming", "tray", "stats", "notifications", "network", "sound", "battery", "power"] })
    // previews (Settings → Bar) can show just some modules, in a style of their own
    property var only: null
    property string clockStyleAs: ""
    property string wsStyleAs: ""
    readonly property var zones: only ? { left: only, center: [], right: [] } : (Store.get("bar.modules", null) || defaults)
    readonly property string clockStyle: clockStyleAs || Store.get("bar.clockStyle", "stacked")      // stacked | simple | full | seconds
    readonly property string wsStyle: wsStyleAs || Store.get("bar.workspaces", "pills")              // pills | dots | numbers

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null

    SystemClock { id: clock; precision: bar.clockStyle === "seconds" ? SystemClock.Seconds : SystemClock.Minutes }

    // a row of things, or a column of them on a vertical bar, centred across
    component Line: Grid {
        columns: bar.vertical ? 1 : 0
        rows: bar.vertical ? 0 : 1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }
    // a module: a hover pill with a ripple
    component Mod: Pressable {
        id: m
        default property alias content: inner.data
        property real pad: 9
        // (stacked on a vertical bar: less room above and below)
        readonly property real vpad: Math.round(pad * 0.7)
        height: bar.vertical ? inner.implicitHeight + 2 * vpad : Theme.islandH - 10
        width: bar.vertical ? Theme.islandH - 10 : inner.implicitWidth + 2 * pad
        // on a see-through bar, modules can sit on their own pills
        color: hovered ? Theme.containerHigh : (Theme.barPills ? Qt.alpha(Theme.frame, Math.max(0.85, Theme.frame.a)) : "transparent")
        Line {
            id: inner
            x: bar.vertical ? Math.round((m.width - width) / 2) : m.pad
            y: bar.vertical ? m.vpad : Math.round((m.height - height) / 2)
            spacing: bar.vertical ? 2 : 6
        }
    }
    // a round icon module
    component Glyph: Mod {
        id: g
        property string icon: ""
        property bool on: false
        property color tint: Theme.text
        pad: 7
        Icon { name: g.icon; size: 18; filled: g.on; color: g.tint }
    }

    // ── the zones ──
    component Zone: Line {
        property var keys: []
        spacing: Number(Store.get("bar.gap", 2))
        Repeater {
            model: parent.keys
            Loader {
                required property string modelData
                sourceComponent: bar.mods[modelData] || null
                // a module with nothing to show (`want: false`) takes no room
                visible: !!item && item.want !== false
            }
        }
    }
    // Modular: each section on a floating pill of its own
    component ZonePill: Rectangle {
        property Item zone
        visible: Theme.barStyle === "modular" && !bar.only && bar.len(zone) > 0
        x: bar.vertical ? 0 : zone.x - 8
        y: bar.vertical ? zone.y - 8 : 0
        width: bar.vertical ? bar.width : zone.width + 16
        height: bar.vertical ? zone.height + 16 : bar.height
        radius: Theme.barRound(Math.min(width, height))
        color: Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        // centred, so it doesn't read as a second pill below (hard-shadow styles keep theirs)
        CardShadow { visible: Theme.barOpacity > 0.3; offsetY: Theme.hardShadow > 0 ? Theme.shadowY : 0 }
    }
    ZonePill { zone: leftZone }
    ZonePill { zone: midZone }
    ZonePill { zone: rightZone }
    // (a vertical bar: left is the top, right the bottom)
    readonly property real barLen: vertical ? height : width
    // where a zone starts along the bar, and across it (centred)
    readonly property real leftAt: Theme.islandPad
    readonly property real midAt: Theme.barSpread ? Math.round((barLen - len(midZone)) / 2) : leftAt + len(leftZone) + gap
    readonly property real rightAt: Theme.barSpread ? barLen - len(rightZone) - Theme.islandPad : midAt + len(midZone) + (len(midZone) > 0 ? gap : 0)
    Zone { id: leftZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.leftAt; y: bar.vertical ? bar.leftAt : Math.round((bar.height - height) / 2); keys: bar.zones.left || [] }
    // a full-width bar spreads them: left edge, middle, right edge
    Zone { id: midZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.midAt; y: bar.vertical ? bar.midAt : Math.round((bar.height - height) / 2); keys: bar.zones.center || [] }
    Zone { id: rightZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.rightAt; y: bar.vertical ? bar.rightAt : Math.round((bar.height - height) / 2); keys: bar.zones.right || [] }

    readonly property var mods: ({
        cc: ccC, search: searchC, clock: clockC, weather: weatherC, workspaces: wsC, media: mediaC, title: titleC,
        live: liveC, tray: trayC, stats: statsC, notifications: notifC, network: netC, sound: soundC,
        battery: batC, keyboard: kbC, gaming: gameC, power: powerC, updates: updC,
        bluetooth: btC, visualizer: visC, nightlight: nightC, awake: awakeC, shuffle: shuffleC
    })

    // the control center: a filled accent bubble
    Component {
        id: ccC
        Pressable {
            readonly property bool on: HubState.open && HubState.page === "quick"
            width: 30; height: 30
            color: on ? Theme.accent : Theme.accentContainer
            ink: Theme.onAccent
            radius: Theme.corner(30)
            onClicked: bar.open("quick")
            Icon { anchors.centerIn: parent; name: "page_info"; size: 18; filled: true; color: parent.on ? Theme.onAccent : Theme.onAccentContainer }
        }
    }
    Component { id: searchC; Glyph { icon: "search"; onClicked: bar.open("search") } }

    // the clock, in its style
    Component {
        id: clockC
        Mod {
            onClicked: bar.open("calendar")
            Text {
                // (stacked hours over minutes on a vertical bar)
                text: Qt.formatTime(clock.date, bar.vertical ? (bar.clockStyle === "seconds" ? "HH\nmm\nss" : "HH\nmm") : (bar.clockStyle === "seconds" ? "HH:mm:ss" : "HH:mm"))
                horizontalAlignment: Text.AlignHCenter
                lineHeight: bar.vertical ? 0.9 : 1
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: bar.clockStyle === "stacked" ? 16 : 14; font.weight: Font.Bold
            }
            Column {
                visible: bar.clockStyle === "stacked" && !bar.vertical
                spacing: -2
                Text { text: Qt.formatDate(clock.date, "dddd"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1; font.weight: Font.Medium }
                Text { text: Qt.formatDate(clock.date, "d MMM"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1 }
            }
            Text {
                visible: bar.clockStyle === "full" && !bar.vertical
                text: Qt.formatDate(clock.date, "ddd d MMM")
                color: Theme.subtext
                font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall
            }
        }
    }
    Component {
        id: weatherC
        Mod {
            property bool want: Weather.ready
            onClicked: bar.open("calendar")
            Icon { name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""; size: 16; color: Theme.accent }
            Label { text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; font.pixelSize: Theme.sizeSmall }
        }
    }

    // workspaces on this screen, in their style
    Component {
        id: wsC
        Item {
            width: bar.vertical ? Theme.islandH - 10 : ws.width + 14
            height: bar.vertical ? ws.height + 14 : Theme.islandH - 10
            Line {
                id: ws
                anchors.centerIn: parent
                spacing: bar.wsStyle === "numbers" ? 3 : 5
                Repeater {
                    model: Niri.workspacesOn(bar.screenName)
                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.is_active
                        readonly property bool busy: Niri.workspaceHasWindows(modelData.id)
                        // (the active pill stretches along the bar: down it on a vertical one)
                        readonly property real along: bar.wsStyle === "numbers" ? 22 : (bar.wsStyle === "dots" ? 9 : (active ? 26 : 9))
                        readonly property real across: bar.wsStyle === "numbers" ? 22 : 9
                        width: bar.vertical ? across : along
                        height: bar.vertical ? along : across
                        radius: Theme.corner(height)
                        color: active ? Theme.accent : (bar.wsStyle === "numbers" ? "transparent" : (busy ? Theme.subtext : Theme.control))
                        border.width: bar.wsStyle === "dots" && !active && busy ? 0 : 0
                        Behavior on width { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                        Behavior on color { ColorAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                        Text {
                            visible: bar.wsStyle === "numbers"
                            anchors.centerIn: parent
                            text: parent.modelData.idx
                            color: parent.active ? Theme.onAccent : (parent.busy ? Theme.text : Theme.faint)
                            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall; font.weight: Font.DemiBold
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(parent.modelData.idx) }
                    }
                }
            }
        }
    }

    // now playing (the album art spins while it plays)
    Component {
        id: mediaC
        Mod {
            id: mediaMod
            property bool want: bar.player !== null
            onClicked: { HubState.peekScreen = ""; bar.open("media"); }
            // hovering it a moment shows a small player under it (Settings → Bar → Now playing peek)
            HoverHandler {
                id: mediaHover
                enabled: !bar.only && Store.get("bar.mediaPeek", true) !== false
                onHoveredChanged: { HubState.peekModuleHover = hovered; if (hovered) peekWait.restart(); else peekWait.stop(); }
            }
            Timer {
                id: peekWait
                interval: 350
                onTriggered: {
                    if (!mediaHover.hovered || HubState.open) return;
                    // under it, or over it when the bar is at the bottom
                    const p = bar.edgePoint(mediaMod);
                    HubState.peekX = p.x; HubState.peekY = p.y;
                    HubState.peekScreen = bar.screenName;
                }
            }
            Rectangle {
                width: 22; height: 22; radius: 11
                color: Theme.control
                clip: true
                Image {
                    anchors.fill: parent
                    source: bar.player ? (bar.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                    RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: bar.player !== null }
                }
            }
            Label { visible: !bar.vertical; text: bar.player ? bar.player.trackTitle : ""; font.pixelSize: Theme.sizeSmall; width: Math.min(implicitWidth, 200) }
        }
    }
    Component {
        id: titleC
        Mod {
            property bool want: Niri.focusedTitle !== ""
            onClicked: bar.open("windows")
            Icon { name: "select_window"; size: 16; color: Theme.subtext }
            Label { visible: !bar.vertical; text: Niri.focusedTitle; muted: true; font.pixelSize: Theme.sizeSmall; width: Math.min(implicitWidth, 220) }
        }
    }

    // what's running: a recording (click stops it), the timer, an update
    Component {
        id: liveC
        Mod {
            id: live
            readonly property string mode: Tasks.recording ? "rec" : (Tasks.total > 0 && Tasks.remaining > 0 ? "timer" : (Updates.available > 0 ? "update" : ""))
            property bool want: mode !== ""
            color: mode === "rec" ? Qt.alpha(Theme.danger, hovered ? 0.32 : 0.2) : (hovered ? Theme.selected : Theme.containerHigh)
            onClicked: {
                if (mode === "rec") Tasks.stopRecording();
                else if (mode === "timer") bar.open("tools");
                else HubState.openSettings("about", bar.screenName);
            }
            Rectangle {
                visible: live.mode === "rec"
                width: 9; height: 9; radius: 4.5; color: Theme.danger
                SequentialAnimation on opacity { running: live.mode === "rec"; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
            }
            Icon { visible: live.mode !== "rec"; name: live.mode === "timer" ? "timer" : "upgrade"; size: 16; color: Theme.accent }
            Label {
                text: live.mode === "rec" ? Tasks.fmt(Tasks.recSeconds) : (live.mode === "timer" ? Tasks.fmt(Tasks.remaining) : String(Updates.available))
                font.pixelSize: Theme.sizeSmall; strong: true
            }
        }
    }
    // a new version of Monolith: shows only then; opens Settings → About & updates
    Component { id: updC; Glyph { property bool want: Updates.newer; icon: "upgrade"; on: true; tint: Theme.accent; onClicked: HubState.openSettings("about", bar.screenName) } }
    Component { id: gameC; Glyph { property bool want: GameMode.active; icon: "sports_esports"; on: true; tint: Theme.accent; onClicked: bar.open("gaming") } }

    Component {
        id: trayC
        Line {
            spacing: 2
            Repeater {
                model: SystemTray.items
                Pressable {
                    id: trayItem
                    required property var modelData
                    width: 28; height: 28
                    color: hovered ? Theme.containerHigh : "transparent"
                    Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon; sourceSize: Qt.size(32, 32); smooth: true; mipmap: true }
                    onClicked: modelData.activate()
                    onRightClicked: { if (bar.trayWindow) { const p = bar.vertical ? bar.edgePoint(trayItem) : mapToItem(null, 0, height + 4); modelData.display(bar.trayWindow, p.x, p.y); } }
                }
            }
        }
    }

    // system stats: which ones (Settings → Bar)
    Component {
        id: statsC
        Mod {
            readonly property var which: Store.get("bar.stats", ["cpu", "temp"])
            onClicked: { HubState.ccTab = "monitor"; bar.open("quick"); }
            Repeater {
                model: [["cpu", "memory", Math.round(Stats.cpu * 100) + "%"], ["mem", "data_usage", Math.round(Stats.mem * 100) + "%"],
                        ["temp", "thermostat", Math.round(Stats.temp) + "°"], ["gpu", "videogame_asset", Math.round(Stats.gpu * 100) + "%"]].filter(x => parent.parent.which.indexOf(x[0]) !== -1)
                Line {
                    required property var modelData
                    spacing: bar.vertical ? 0 : 3
                    Icon { name: modelData[1]; size: 15; color: Theme.subtext }
                    Label { text: modelData[2]; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }

    Component {
        id: notifC
        Mod {
            id: notifMod
            pad: 7
            // the list drops down right under the bell (over it when the bar is at the bottom)
            onClicked: {
                const p = bar.edgePoint(notifMod);
                HubState.toggleDrop("notifications", bar.screenName, p.x, p.y);
            }
            Icon {
                name: Notifs.dnd ? "notifications_paused" : (Notifs.list.length > 0 ? "notifications_unread" : "notifications")
                size: 18; filled: Notifs.list.length > 0
                color: Notifs.list.length > 0 && !Notifs.dnd ? Theme.accent : Theme.text
            }
            Label { visible: Notifs.list.length > 0; text: Notifs.list.length; font.pixelSize: Theme.sizeSmall }
        }
    }
    Component { id: netC; Glyph { icon: bar.netIcon; on: true; onClicked: bar.open("network") } }
    Component {
        id: soundC
        Mod {
            id: soundMod
            pad: 7
            // a small sound card drops down right under it (over it when the bar is at the bottom)
            onClicked: {
                const p = bar.edgePoint(soundMod);
                HubState.toggleDrop("sound", bar.screenName, p.x, p.y);
            }
            Icon {
                name: bar.muted || bar.volume === 0 ? "volume_off" : (bar.volume < 0.4 ? "volume_down" : "volume_up")
                size: 18; filled: true; color: bar.muted ? Theme.subtext : Theme.text
            }
            Label { visible: Store.get("bar.soundPercent", true) !== false; text: Math.round(bar.volume * 100); font.pixelSize: Theme.sizeSmall }
        }
    }
    // the battery (laptops; hidden when there's none)
    Component {
        id: batC
        Mod {
            readonly property var dev: UPower.displayDevice
            property bool want: !!dev && dev.isLaptopBattery
            pad: 7
            onClicked: bar.open("quick")
            Icon {
                name: !parent.parent.dev ? "battery_full" : (parent.parent.dev.state === UPowerDeviceState.Charging ? "battery_charging_full" : (parent.parent.dev.percentage < 0.2 ? "battery_alert" : "battery_full"))
                size: 18; filled: true
                color: parent.parent.dev && parent.parent.dev.percentage < 0.2 ? Theme.danger : Theme.text
            }
            Label { text: parent.parent.dev ? Math.round(parent.parent.dev.percentage * 100) + "%" : ""; font.pixelSize: Theme.sizeSmall }
        }
    }
    Component {
        id: kbC
        Mod {
            property bool want: Niri.layoutName !== ""
            onClicked: Niri.action(["switch-layout", "next"])
            Icon { name: "keyboard"; size: 16; color: Theme.subtext }
            Label { text: Niri.layoutName.substring(0, 2).toUpperCase(); font.pixelSize: Theme.sizeSmall; strong: true }
        }
    }
    // Bluetooth: the adapter's state; how many devices are connected beside it
    Component {
        id: btC
        Mod {
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length
            property bool want: !!adapter
            pad: 7
            onClicked: bar.open("network")
            Icon {
                name: !parent.parent.adapter || !parent.parent.adapter.enabled ? "bluetooth_disabled" : (parent.parent.connected > 0 ? "bluetooth_connected" : "bluetooth")
                size: 18; filled: true
                color: parent.parent.adapter && parent.parent.adapter.enabled ? Theme.text : Theme.subtext
            }
            Label { visible: parent.parent.connected > 0; text: parent.parent.connected; font.pixelSize: Theme.sizeSmall }
        }
    }
    // audio bars while something plays (cava runs only while they show)
    Component {
        id: visC
        Mod {
            property bool want: bar.player !== null
            onClicked: bar.open("media")
            Faces.CavaBars {
                width: bar.vertical ? 24 : 46; height: 16
                count: bar.vertical ? 5 : 9; spacing: 2; minLen: 2
                live: bar.player !== null
                color: Theme.accent
            }
        }
    }
    Component { id: nightC; Glyph { icon: "nightlight"; on: NightLight.enabled; tint: NightLight.enabled ? Theme.accent : Theme.text; onClicked: NightLight.toggle() } }
    Component { id: awakeC; Glyph { icon: "coffee"; on: Tasks.awake; tint: Tasks.awake ? Theme.accent : Theme.text; onClicked: Tasks.awake = !Tasks.awake } }
    Component { id: shuffleC; Glyph { icon: "shuffle"; enabled: Wall.images.length > 1; onClicked: Wall.shuffle() } }
    Component { id: powerC; Glyph { icon: "power_settings_new"; tint: Theme.danger; onClicked: { HubState.ccTab = "controls"; bar.open("quick"); } } }

    // the connection, for the network glyph (wired wins over Wi-Fi)
    property string netIcon: "signal_disconnected"
    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                bar.netIcon = l.some(x => x === "ethernet:connected") ? "lan" : (l.some(x => x === "wifi:connected") ? "wifi" : "signal_disconnected");
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: netProc.running = true }
}
