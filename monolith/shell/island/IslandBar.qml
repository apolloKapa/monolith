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
    // how long the modules alone are (0: none of them has anything to show)
    readonly property real contentLen: len(leftZone) + len(midZone) + len(rightZone)
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
    // the visualiser shown even with nothing playing, as a still curve (its settings' preview)
    property bool visPreview: false
    // a module's own setting (Settings → Bar → Layout & modules → Module settings): "bar.<k>"
    function mopt(k, d) { const v = Store.get("bar." + k, d); return v === undefined || v === null || v === "" ? d : v; }
    property string clockStyleAs: ""
    property string wsStyleAs: ""
    // previews show made-up workspaces (four, the second one open, the first and third with
    // windows), so every style has something to show whatever your screen has
    property bool wsSample: false
    readonly property var sampleWorkspaces: [{ id: -1, idx: 1, is_active: false, busy: true }, { id: -2, idx: 2, is_active: true, busy: true },
                                             { id: -3, idx: 3, is_active: false, busy: true }, { id: -4, idx: 4, is_active: false, busy: false }]
    readonly property var zones: only ? { left: only, center: [], right: [] } : (Store.get("bar.modules", null) || defaults)
    readonly property string clockStyle: clockStyleAs || Store.get("bar.clockStyle", "stacked")      // stacked | simple | full | seconds (the old presets)
    // the clock's parts (Settings → Bar → Clock), each a toggle; unset, they follow the old preset
    function clockOpt(k, d) { const v = Store.get("bar.clock." + k, null); return v === null || v === undefined ? d : v; }
    readonly property bool clockSeconds: clockOpt("seconds", clockStyle === "seconds") === true
    readonly property bool clockDate: clockOpt("date", clockStyle === "stacked" || clockStyle === "full") === true
    readonly property string clockDateLayout: String(clockOpt("dateLayout", clockStyle === "full" ? "inline" : "stacked"))   // stacked | inline
    readonly property bool clockWeekday: clockOpt("weekday", true) === true
    readonly property bool clockStackTime: clockOpt("stackTime", false) === true      // hours over minutes
    readonly property bool clock12: clockOpt("hour12", false) === true
    // the time's lines: one ("14:05:09"), or stacked (always on a vertical bar)
    readonly property bool timeStacked: vertical || clockStackTime
    function timeText(d) {
        // (Qt counts 12-hour only with AM/PM in the same format: "h" alone gave 0 for 12 AM)
        const parts = [clock12 ? Qt.formatTime(d, "h AP").split(" ")[0] : Qt.formatTime(d, "HH"), Qt.formatTime(d, "mm")];
        if (clockSeconds) parts.push(Qt.formatTime(d, "ss"));
        const t = parts.join(timeStacked ? "\n" : ":");
        return clock12 ? t + (timeStacked ? "\n" : " ") + Qt.formatTime(d, "AP") : t;
    }
    readonly property string wsStyle: wsStyleAs || Store.get("bar.workspaces", "pills")
    // how the open workspace's highlight goes over when you switch (Bar → Workspaces → Switching
    // animation): worm, slide, bouncy, hop, fade; grow (no highlight: the pills change), none
    readonly property string wsAnim: { const a = Theme.animOn ? String(mopt("ws.anim", "worm")) : "none";
                                      return ["worm", "slide", "bouncy", "hop", "fade", "grow", "none"].indexOf(a) >= 0 ? a : "worm"; }
    readonly property bool wsHighlight: ["grow", "none"].indexOf(wsAnim) < 0
    // each workspace style: how long along the bar and how thick across, how round, and how it's
    // filled, edged and numbered when it's open, has windows, or is empty
    function wsLook(st, active, busy) {
        const A = Theme.accent, faint = Theme.control, mid = Theme.subtext;
        switch (st) {
        case "dots":        return { along: active ? 11 : 9, across: active ? 11 : 9, r: 1, fill: active ? A : (busy ? mid : faint), edge: 0, num: false };
        case "numbers":     return { along: 22, across: 22, r: 1, fill: active ? A : "transparent", edge: 0, num: true };
        case "numberPills": return { along: active ? 34 : 20, across: 20, r: 1, fill: active ? A : (busy ? Theme.containerHigh : "transparent"), edge: 0, num: true };
        // (upright strokes, across the bar; the open one taller)
        case "lines":       return { along: 4, across: active ? 22 : 14, r: 1, fill: active ? A : (busy ? mid : faint), edge: 0, num: false };
        case "squares":     return { along: 13, across: 13, r: 0.3, fill: active ? A : (busy ? mid : "transparent"), edge: active || busy ? 0 : 1.5, num: false };
        case "rings":       return { along: active ? 13 : 11, across: active ? 13 : 11, r: 1, fill: active ? A : "transparent", edge: active ? 0 : (busy ? 3 : 1.5), num: false };
        case "bubbles":     return { along: 22, across: 22, r: 1, fill: active ? A : (busy ? Theme.containerHigh : Qt.alpha(Theme.text, 0.04)), edge: 0, num: true };
        default:            return { along: active ? 26 : 9, across: 9, r: 1, fill: active ? A : (busy ? mid : faint), edge: 0, num: false };   // pills
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null

    SystemClock { id: clock; precision: bar.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

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
        property real spacing: bar.vertical ? 2 : 6
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
            spacing: m.spacing
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
    ZonePill { id: leftPillR; zone: leftZone }
    ZonePill { id: midPillR; zone: midZone }
    ZonePill { id: rightPillR; zone: rightZone }
    // (the island's blur is cut to these in Modular)
    readonly property Item leftPill: leftPillR
    readonly property Item midPill: midPillR
    readonly property Item rightPill: rightPillR
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

    // the clock, made of the parts you turned on: the time (with seconds, 12-hour, hours over
    // minutes) and the date beside it (stacked in two small lines, or on one line, with or
    // without the day's name)
    Component {
        id: clockC
        Mod {
            onClicked: bar.open("calendar")
            readonly property bool stackedDate: bar.clockDate && bar.clockDateLayout === "stacked" && !bar.vertical
            Text {
                text: bar.timeText(clock.date)
                horizontalAlignment: Text.AlignHCenter
                // (stacked, the lines sit close; next to a stacked date the time is a bit bigger)
                lineHeight: bar.timeStacked ? 0.82 : 1
                color: Theme.text
                font.family: Theme.fontFamily; font.weight: Font.Bold
                font.pixelSize: bar.timeStacked && !bar.vertical ? (bar.clockSeconds || bar.clock12 ? 9 : 12) : (parent.parent.stackedDate ? 16 : 14)
            }
            Column {
                visible: parent.parent.stackedDate
                spacing: -2
                Text { visible: bar.clockWeekday; text: Qt.formatDate(clock.date, "dddd"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1; font.weight: Font.Medium }
                Text { text: Qt.formatDate(clock.date, "d MMM"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1 }
            }
            Text {
                visible: bar.clockDate && bar.clockDateLayout === "inline" && !bar.vertical
                text: Qt.formatDate(clock.date, bar.clockWeekday ? "ddd d MMM" : "d MMM")
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
            Icon { visible: bar.mopt("weather.icon", true) === true; name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""; size: 16; color: Theme.accent }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; text: Weather.ready ? Math.round(bar.mopt("weather.feels", false) === true ? Weather.current.feels : Weather.current.temp) + (bar.mopt("weather.unit", false) === true ? Weather.unit : "°") : ""; font.pixelSize: Theme.sizeSmall }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: !bar.vertical && bar.mopt("weather.desc", false) === true; text: Weather.ready ? Weather.describe(Weather.current.code) : ""; muted: true; font.pixelSize: Theme.sizeSmall }
        }
    }

    // workspaces on this screen, in their style. Animated: the open one's highlight slides over to
    // the next like a worm (the edge going first leads, the other catches up), pills grow and fade
    // into their new look, swell under the pointer, give on a click, and pop in and out.
    Component {
        id: wsC
        Item {
            id: wsBox
            width: bar.vertical ? Theme.islandH - 10 : ws.width + 14
            height: bar.vertical ? ws.height + 14 : Theme.islandH - 10
            // (only the ones with windows, and the open one, when empty ones are hidden)
            readonly property var list: { const l = bar.wsSample ? bar.sampleWorkspaces : Niri.workspacesOn(bar.screenName);
                                          return bar.mopt("ws.hideEmpty", false) === true ? l.filter(w => w.is_active || (w.busy !== undefined ? w.busy : Niri.workspaceHasWindows(w.id))) : l; }
            readonly property int activeIndex: list.findIndex(w => w.is_active)
            // the wheel over it: the next / previous workspace
            WheelHandler {
                enabled: !bar.wsSample && !bar.only && bar.mopt("ws.scroll", true) === true
                onWheel: event => {
                    const l = Niri.workspacesOn(bar.screenName), i = l.findIndex(w => w.is_active);
                    const d = (event.angleDelta.y || -event.angleDelta.x) > 0 ? -1 : 1;
                    if (i < 0 || i + d < 0 || i + d >= l.length) return;
                    Niri.focusWorkspace(l[i + d].idx);
                }
            }

            // the open workspace's highlight: its two ends follow the open pill on springs; the one
            // on the side it's heading leads, the other trails, so it stretches over and settles
            Rectangle {
                id: hi
                readonly property Item at: wsBox.activeIndex >= 0 ? reps.itemAt(wsBox.activeIndex) : null
                visible: !!at && bar.wsHighlight
                // (over the other pills, so they don't show through it as it slides past them)
                z: 1
                // where the open pill is, along the bar and across it
                readonly property real toA: at ? (bar.vertical ? ws.y + at.y : ws.x + at.x) : 0
                readonly property real toB: at ? toA + (bar.vertical ? at.height : at.width) : 0
                readonly property real thick: at ? (bar.vertical ? at.width : at.height) : 0
                property int dir: 1                  // which way it's going (+1: on along the bar)
                property real a: toA
                property real b: toB
                property real fromA: toA             // where this move started (hop: its arc)
                property bool ready: false
                Component.onCompleted: Qt.callLater(() => hi.ready = true)
                onToAChanged: {
                    dir = toA >= a ? 1 : -1;
                    fromA = a;
                    if (bar.wsAnim === "fade" && ready) fadeIn.restart();
                }
                // each animation's two springs (the end it's heading to, the other one), how much
                // they give: worm stretches (the leading end quick, the other slow), the rest move
                // in one piece; bouncy overshoots and wobbles back
                readonly property var spr: ({ worm: [13, 7, 0.55], slide: [10, 10, 0.6], bouncy: [9, 9, 0.16], hop: [8, 8, 0.75] })[bar.wsAnim] || [10, 10, 0.6]
                readonly property bool moves: hi.ready && ["worm", "slide", "bouncy", "hop"].indexOf(bar.wsAnim) >= 0
                Behavior on a { enabled: hi.moves; SpringAnimation { spring: hi.dir > 0 ? hi.spr[1] : hi.spr[0]; damping: hi.spr[2]; epsilon: 0.2 } }
                Behavior on b { enabled: hi.moves; SpringAnimation { spring: hi.dir > 0 ? hi.spr[0] : hi.spr[1]; damping: hi.spr[2]; epsilon: 0.2 } }
                // hop: up and over in an arc, highest halfway
                readonly property real hop: bar.wsAnim !== "hop" || Math.abs(toA - fromA) < 1 ? 0
                    : Math.sin(Math.PI * Math.max(0, Math.min(1, (a - fromA) / (toA - fromA)))) * Math.min(9, Math.abs(toA - fromA) * 0.25)
                // fade: out where it was, in where it's going (it doesn't travel)
                NumberAnimation { id: fadeIn; target: hi; property: "opacity"; from: 0; to: 1; duration: Theme.ms(240); easing.type: Easing.OutCubic }
                x: bar.vertical ? (wsBox.width - thick) / 2 - hop : a
                y: bar.vertical ? a : (wsBox.height - thick) / 2 - hop
                width: bar.vertical ? thick : Math.max(1, b - a)
                height: bar.vertical ? Math.max(1, b - a) : thick
                radius: at ? at.radius : 0
                color: Theme.accent
                scale: at ? at.scale : 1
                // numbered styles: the open one's number, on the highlight
                Text {
                    visible: !!hi.at && hi.at.look.num
                    anchors.centerIn: parent
                    text: hi.at ? hi.at.modelData.idx : ""
                    color: Theme.onAccent
                    font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall; font.weight: Font.DemiBold
                }
            }

            Line {
                id: ws
                anchors.centerIn: parent
                spacing: Number(bar.mopt("ws.gap", -1)) >= 0 ? Number(bar.mopt("ws.gap", -1)) : (["numbers", "numberPills", "bubbles"].indexOf(bar.wsStyle) !== -1 ? 3 : 5)
                Repeater {
                    id: reps
                    // (a count, not the list itself: a new list on every switch rebuilt every pill,
                    // and a pill made just now has nothing to animate from, so nothing moved)
                    model: wsBox.list.length
                    Rectangle {
                        id: pill
                        required property int index
                        readonly property var modelData: wsBox.list[index] || ({ idx: 0, is_active: false, busy: false, id: -1 })
                        readonly property bool active: modelData.is_active === true
                        readonly property bool busy: modelData.busy !== undefined ? modelData.busy : Niri.workspaceHasWindows(modelData.id)
                        readonly property var look: bar.wsLook(bar.wsStyle, active, busy)
                        // (the open one's own colour comes from the sliding highlight over it)
                        readonly property var idleLook: bar.wsLook(bar.wsStyle, false, busy)
                        // (the open one stretches along the bar: down it on a vertical one)
                        readonly property real along: look.along
                        readonly property real across: look.across
                        width: bar.vertical ? across : along
                        height: bar.vertical ? along : across
                        // round as the theme's corners allow (squares: a little rounded)
                        radius: look.r >= 1 ? Theme.corner(Math.min(width, height)) : Math.min(Math.min(width, height) / 2, Theme.radius * look.r)
                        color: active && bar.wsHighlight ? (idleLook.fill === "transparent" ? "transparent" : Qt.alpha(idleLook.fill, 0)) : look.fill
                        border.width: active && bar.wsHighlight ? 0 : look.edge
                        border.color: busy ? Theme.subtext : Theme.control
                        Behavior on width { enabled: bar.wsAnim !== "none"; NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                        Behavior on height { enabled: bar.wsAnim !== "none"; NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                        Behavior on color { enabled: bar.wsAnim !== "none"; ColorAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
                        Behavior on border.width { enabled: bar.wsAnim !== "none"; NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                        // swells under the pointer, gives a little when clicked, pops in when it appears
                        property bool born: false
                        property real press: 1
                        Component.onCompleted: born = true
                        scale: (born ? 1 : 0.2) * (mouse.containsMouse && !bar.wsSample ? 1.18 : 1) * press
                        opacity: born ? 1 : 0
                        Behavior on scale { enabled: Theme.animOn; SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.005 } }
                        Behavior on opacity { enabled: Theme.animOn; NumberAnimation { duration: Theme.ms(180) } }
                        SequentialAnimation {
                            id: tap
                            NumberAnimation { target: pill; property: "press"; to: 0.78; duration: Theme.ms(70); easing.type: Easing.OutQuad }
                            NumberAnimation { target: pill; property: "press"; to: 1; duration: Theme.ms(260); easing.type: Easing.OutBack; easing.overshoot: 3 }
                        }
                        Text {
                            visible: pill.look.num && !(pill.active && bar.wsHighlight)
                            anchors.centerIn: parent
                            text: pill.modelData.idx
                            color: pill.active ? Theme.onAccent : (pill.busy ? Theme.text : Theme.faint)
                            Behavior on color { enabled: Theme.animOn; ColorAnimation { duration: Theme.ms(220) } }
                            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent; anchors.margins: -4
                            enabled: !bar.wsSample; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (Theme.animOn) tap.restart(); Niri.focusWorkspace(pill.modelData.idx); }
                        }
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
                visible: bar.mopt("media.art", true) === true || bar.vertical
                width: 22; height: 22; radius: bar.mopt("media.round", true) === true ? 11 : 5
                color: Theme.control
                clip: true
                Image {
                    anchors.fill: parent
                    source: bar.player ? (bar.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                    rotation: 0
                    RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: bar.player !== null && bar.mopt("media.spin", true) === true }
                }
            }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering;
                readonly property string what: String(bar.mopt("media.text", "title"))
                visible: !bar.vertical && what !== "none"
                text: !bar.player ? "" : what === "artist" ? (bar.player.trackArtist || "") : what === "both" ? bar.player.trackTitle + (bar.player.trackArtist ? "  ·  " + bar.player.trackArtist : "") : bar.player.trackTitle
                font.pixelSize: Theme.sizeSmall
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Number(bar.mopt("media.maxWidth", 200)))
            }
        }
    }
    Component {
        id: titleC
        Mod {
            id: titleMod
            property bool want: Niri.focusedTitle !== ""
            onClicked: bar.open("windows")
            readonly property string iconMode: String(bar.mopt("title.icon", "generic"))       // generic | app | none
            readonly property var entry: Niri.focusedAppId !== "" ? DesktopEntries.heuristicLookup(Niri.focusedAppId) : null
            Icon { visible: titleMod.iconMode === "generic" || bar.vertical; name: "select_window"; size: 16; color: Theme.subtext }
            Image { visible: titleMod.iconMode === "app" && !bar.vertical; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: Quickshell.iconPath(titleMod.entry ? titleMod.entry.icon : Niri.focusedAppId, "application-x-executable") }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering;
                readonly property string what: String(bar.mopt("title.text", "title"))     // title | app | both
                readonly property string app: titleMod.entry ? titleMod.entry.name : Niri.focusedAppId
                visible: !bar.vertical
                text: what === "app" ? app : what === "both" ? app + "  ·  " + Niri.focusedTitle : Niri.focusedTitle
                muted: true; font.pixelSize: Theme.sizeSmall
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Number(bar.mopt("title.maxWidth", 220)))
            }
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
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering;
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
            spacing: Number(bar.mopt("tray.gap", 2))
            Repeater {
                model: SystemTray.items
                Pressable {
                    id: trayItem
                    required property var modelData
                    readonly property real size: Number(bar.mopt("tray.size", 16))
                    width: size + 12; height: size + 12
                    color: hovered ? Theme.containerHigh : "transparent"
                    Image { anchors.centerIn: parent; width: trayItem.size; height: trayItem.size; source: modelData.icon; sourceSize: Qt.size(32, 32); smooth: true; mipmap: true }
                    onClicked: modelData.activate()
                    // its menu, drawn by Monolith (status/TrayMenu.qml); an icon without one gets
                    // its secondary action
                    onRightClicked: {
                        if (!modelData.hasMenu) { modelData.secondaryActivate(); return; }
                        const p = bar.edgePoint(trayItem);
                        HubState.toggleTray(modelData, bar.screenName, p.x, p.y);
                    }
                }
            }
        }
    }

    // system stats: which ones (Settings → Bar)
    Component {
        id: statsC
        Mod {
            id: statsMod
            spacing: bar.vertical ? 2 : Number(bar.mopt("stats.gap", 6))
            readonly property var which: Store.get("bar.stats", ["cpu", "temp"])
            // the system monitor drops down under it (Settings → System monitor), or the control center's Monitor
            onClicked: {
                if (Store.get("sysmon.dropdown", true) === false) { HubState.ccTab = "monitor"; bar.open("quick"); return; }
                const p = bar.edgePoint(statsMod);
                HubState.toggleDrop("system", bar.screenName, p.x, p.y);
            }
            Repeater {
                model: [["cpu", "memory", Math.round(Stats.cpu * 100) + "%"], ["mem", "data_usage", Math.round(Stats.mem * 100) + "%"],
                        ["temp", "thermostat", Math.round(Stats.temp) + "°"], ["gpu", "videogame_asset", Math.round(Stats.gpu * 100) + "%"],
                        ["vram", "developer_board", Math.round(Stats.vram * 100) + "%"], ["gtemp", "device_thermostat", Math.round(Stats.gpuTemp) + "°"]].filter(x => parent.parent.which.indexOf(x[0]) !== -1)
                Line {
                    required property var modelData
                    spacing: bar.vertical ? 0 : 3
                    Icon { visible: bar.mopt("stats.icons", true) === true; name: modelData[1]; size: 15; color: Theme.subtext }
                    Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; text: modelData[2]; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }

    Component {
        id: notifC
        Mod {
            id: notifMod
            pad: 7
            property bool want: bar.only || bar.mopt("notif.hideEmpty", false) !== true || Notifs.list.length > 0
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
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: Notifs.list.length > 0 && bar.mopt("notif.count", true) === true; text: Notifs.list.length; font.pixelSize: Theme.sizeSmall }
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
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: Store.get("bar.soundPercent", true) !== false; text: Math.round(bar.volume * 100) + (bar.mopt("sound.sign", false) === true ? "%" : ""); font.pixelSize: Theme.sizeSmall }
            // the wheel over it: the volume, a step at a time
            WheelHandler {
                enabled: !bar.only && bar.mopt("sound.scroll", true) === true
                onWheel: event => {
                    if (!bar.sink || !bar.sink.audio) return;
                    const step = Number(bar.mopt("sound.step", 5)) / 100, d = (event.angleDelta.y || event.angleDelta.x) > 0 ? step : -step;
                    bar.sink.audio.volume = Math.max(0, Math.min(1, Math.round((bar.volume + d) * 100) / 100));
                }
            }
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
                name: !parent.parent.dev ? "battery_full" : (parent.parent.dev.state === UPowerDeviceState.Charging ? "battery_charging_full" : (parent.parent.dev.percentage < Number(bar.mopt("battery.low", 20)) / 100 ? "battery_alert" : "battery_full"))
                size: 18; filled: true
                color: parent.parent.dev && parent.parent.dev.percentage < Number(bar.mopt("battery.low", 20)) / 100 ? Theme.danger : Theme.text
            }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: bar.mopt("battery.percent", true) === true; text: parent.parent.dev ? Math.round(parent.parent.dev.percentage * 100) + "%" : ""; font.pixelSize: Theme.sizeSmall }
        }
    }
    Component {
        id: kbC
        Mod {
            property bool want: Niri.layoutName !== ""
            onClicked: Niri.action(["switch-layout", "next"])
            Icon { visible: bar.mopt("kb.icon", true) === true; name: "keyboard"; size: 16; color: Theme.subtext }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; text: bar.mopt("kb.full", false) === true && !bar.vertical ? Niri.layoutName : Niri.layoutName.substring(0, 2).toUpperCase(); font.pixelSize: Theme.sizeSmall; strong: true }
        }
    }
    // Bluetooth: the adapter's state; how many devices are connected beside it
    Component {
        id: btC
        Mod {
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property int connected: Bluetooth.devices.values.filter(d => d.connected).length
            property bool want: !!adapter && (bar.only || bar.mopt("bt.hideOff", false) !== true || adapter.enabled)
            pad: 7
            onClicked: bar.open("network")
            Icon {
                name: !parent.parent.adapter || !parent.parent.adapter.enabled ? "bluetooth_disabled" : (parent.parent.connected > 0 ? "bluetooth_connected" : "bluetooth")
                size: 18; filled: true
                color: parent.parent.adapter && parent.parent.adapter.enabled ? Theme.text : Theme.subtext
            }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: parent.parent.connected > 0 && bar.mopt("bt.count", true) === true; text: parent.parent.connected; font.pixelSize: Theme.sizeSmall }
        }
    }
    // audio bars while something plays (cava runs only while they show)
    // (its look: Settings → Bar → Layout & modules → Visualiser, "bar.vis.*")
    Component {
        id: visC
        Mod {
            id: vm
            function opt(k, d) { const v = Store.get("bar.vis." + k, d); return v === undefined || v === null || v === "" ? d : v; }
            function tint(v, d) {
                const m = { accent: Theme.accent, text: Theme.text, white: "#ffffff", black: "#000000",
                    primary: Theme.m("primary", Theme.accent), secondary: Theme.m("secondary", Theme.subtext), tertiary: Theme.m("tertiary", Theme.accent) };
                return m[v] !== undefined ? m[v] : (String(v).startsWith("#") ? v : d);
            }
            readonly property real wantW: Number(opt("width", 46))
            readonly property real wantH: Math.min(Theme.islandH - 14, Number(opt("height", 16)))
            readonly property int wantN: Number(opt("bars", 9))
            property bool want: bar.visPreview || bar.player !== null || opt("always", false) === true
            onClicked: bar.open("media")
            Faces.CavaBars {
                // (down a side bar: as wide as the bar allows, with fewer bars to match)
                width: bar.vertical ? Math.min(vm.wantW, Theme.islandH - 26) : vm.wantW
                height: vm.wantH
                count: bar.vertical ? Math.max(3, Math.round(vm.wantN * width / Math.max(1, vm.wantW))) : vm.wantN
                spacing: Number(vm.opt("spacing", 2))
                minLen: Number(vm.opt("rest", 2))
                continuous: vm.opt("style", "bars") === "smooth"
                mirror: vm.opt("anchor", "bottom") === "middle"
                flip: vm.opt("anchor", "bottom") === "top"
                roundness: Number(vm.opt("roundness", 1))
                scaleY: Number(vm.opt("scale", 1))
                fade: vm.opt("fade", true) === true
                dynamic: vm.opt("dynamic", true) === true
                smoothMs: Number(vm.opt("smoothing", 70))
                live: bar.player !== null || (vm.opt("always", false) === true && !bar.visPreview)
                preview: bar.visPreview
                color: vm.tint(vm.opt("colour", "accent"), Theme.accent)
                color2: vm.tint(vm.opt("colour2", ""), color)
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
