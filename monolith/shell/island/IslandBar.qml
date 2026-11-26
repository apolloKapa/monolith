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

// The island's bar: its zones, each a list of modules you arrange in Settings → Bar: left,
// centre and right; between left and centre (leftMid) and between centre and right (midRight),
// each sitting in the middle of its gap; free modules, each at its own point along the bar
// ("bar.freeAt": 0 … 1); and outside the bar (outLeft, outRight), on pills of their own beside
// it, drawn by Island.qml (here they join the ends when there's no room outside: `outside`).
// Every module opens its page in the island.
Item {
    id: bar
    property string screenName: ""
    property var trayWindow: null                       // the window tray menus open from
    // down a side of the screen (SideBar): the zones run top to bottom, modules stack their parts
    property bool vertical: false
    readonly property real gap: Number(Store.get("bar.sectionGap", 14))
    // a zone's length along the bar
    function len(z) { return vertical ? z.height : z.width; }
    // a zone and the gap after it, or nothing when it's empty
    function part(z) { return len(z) > 0 ? len(z) + gap : 0; }
    // the free modules: room for them all, wherever they sit
    readonly property real freeLen: { let n = 0; for (let i = 0; i < freeRep.count; i++) { const it = freeRep.itemAt(i); if (it && it.visible) n += (vertical ? it.height : it.width) + gap; } return n; }
    readonly property real fitLength: part(leftZone) + part(leftMidZone) + part(midZone) + part(midRightZone) + len(rightZone) + freeLen + 2 * Theme.islandPad
    // (Desktop mode: its middle (the start button and the apps) right in the middle of the screen,
    // whatever its length setting. Fitting its modules, the middle came right after the left end,
    // wherever that ended)
    readonly property bool centerMid: Desk.on && !only && (zones.center || []).length > 0
    readonly property bool spread: Theme.barSpread || centerMid
    implicitWidth: vertical ? Theme.islandH : (centerMid ? spreadWidth : fitLength)
    // spread out, the middle stays in the middle: the shortest it can be without the sides running into it
    readonly property real spreadWidth: Math.max(fitLength, len(midZone) + 2 * Math.max(part(leftZone) + part(leftMidZone), part(rightZone) + part(midRightZone)) + 2 * Theme.islandPad)
    // the length the bar needs (its width, or its height when it's vertical)
    // how long the modules alone are (0: none of them has anything to show)
    readonly property real contentLen: len(leftZone) + len(leftMidZone) + len(midZone) + len(midRightZone) + len(rightZone) + freeLen
    readonly property real needWidth: spread ? spreadWidth : fitLength
    implicitHeight: vertical ? (centerMid ? spreadWidth : fitLength) : Theme.islandH
    // (the module being clicked is noted first: Dynamic menus grow out of it)
    property var pressedAt: null
    function open(p) {
        HubState.origin = pressedAt && Date.now() - pressedAt.t < 1500 ? pressedAt : null;
        HubState.toggle(p, bar.screenName);
    }
    // the modules that are loaded, by name, and the ones each menu belongs to: a menu opened some
    // other way (a keybind, a command) grows out of its module too when that's on this bar
    property var modItems: ({})
    readonly property var menuMods: ({
        quick: ["cc", "battery", "power"], search: ["start", "search"], calendar: ["clock", "weather"], media: ["media", "visualizer"],
        windows: ["title"], network: ["network", "bluetooth"], gaming: ["gaming"], tools: ["live"]
    })
    function moduleBox(page) {
        if (!bar.visible || bar.still) return null;
        const names = menuMods[page] || [];
        for (let i = 0; i < names.length; i++) {
            const l = modItems[names[i]];
            if (!l || !l.visible || !l.item || l.width < 4 || l.height < 4) continue;
            // (a module can name the part a menu comes out of: the taskbar's start button)
            const it = l.item.menuFrom || l.item;
            const q = it.mapToItem(null, 0, 0);
            if (q.x + it.width < 0 || q.y + it.height < 0) continue;      // (a bar that's tucked away)
            return { screen: bar.screenName, x: q.x, y: q.y, w: it.width, h: it.height, t: Date.now() };
        }
        return null;
    }
    // the point on a module's edge that faces into the screen (where its drop-downs hang from)
    // (the edge this bar is on: the main bar's, or a mini bar's own, island/MiniBars.qml; what drops
    // out of a module drops away from it, HubState.dropEdge)
    property string edge: vertical ? (Theme.barSide || "left") : (Theme.barBottom ? "bottom" : "top")
    function edgePoint(it) {
        HubState.dropEdge = edge;
        if (vertical) return it.mapToItem(null, edge === "right" ? 0 : it.width, it.height / 2);
        return it.mapToItem(null, it.width / 2, edge === "bottom" ? 0 : it.height);
    }

    // the modules in each zone, and every module there is
    readonly property var defaults: ({ left: ["cc", "search", "clock", "workspaces"], center: ["media"], right: ["updates", "live", "gaming", "tray", "stats", "notifications", "network", "sound", "battery", "power"] })
    // previews (Settings → Bar) can show just some modules, in a style of their own
    property var only: null
    // the visualiser shown even with nothing playing, as a still curve (its settings' preview)
    property bool visPreview: false
    // a preview (Settings): nothing moves on its own. The time stays at when it was made, the
    // visualiser is a still curve, nothing spins, blinks or polls; it still follows your settings
    property bool still: false
    property date frozen: new Date()
    readonly property date now: still ? frozen : clock.date
    // a module's own setting (Settings → Bar → Layout & modules → Module settings): "bar.<k>"
    function mopt(k, d) { const v = Store.get("bar." + k, d); return v === undefined || v === null || v === "" ? d : v; }
    property string clockStyleAs: ""
    property string clockThemeAs: ""
    property string wsStyleAs: ""
    // previews show made-up workspaces (four, the second one open, the first and third with
    // windows), so every style has something to show whatever your screen has
    property bool wsSample: false
    readonly property var sampleWorkspaces: [{ id: -1, idx: 1, is_active: false, busy: true }, { id: -2, idx: 2, is_active: true, busy: true },
                                             { id: -3, idx: 3, is_active: false, busy: true }, { id: -4, idx: 4, is_active: false, busy: false }]
    // whether the outside modules are drawn outside (Island.qml); not: they join the bar's ends
    property bool outside: false
    // the longest the bar can be (the screen's room; 0: no limit). When the modules don't fit even
    // then, the visualiser gives up length (down to a few bars) instead of being drawn over
    property real maxLen: 0
    // and when they still don't fit (a small screen, many modules), the whole row is drawn a little
    // smaller so it fits, down to 72%, instead of its far end being cut off by the screen's edge
    readonly property real squeeze: !vertical && maxLen > 0 && needWidth > maxLen + 0.5 ? Math.max(0.72, maxLen / needWidth) : 1
    property real visCap: 100000
    property real visNow: 0                 // the visualiser's length as drawn
    function settleVis() {
        if (maxLen <= 0 || visNow <= 0) { visCap = 100000; return; }
        const over = fitLength - maxLen;
        if (over > 0.5) visCap = Math.max(24, visNow - over);
        else if (over < -0.5 && visCap < 100000) visCap = visCap - over > 4000 ? 100000 : visCap - over;
    }
    onFitLengthChanged: Qt.callLater(settleVis)
    onMaxLenChanged: Qt.callLater(settleVis)
    readonly property var stored: Store.get("bar.modules", null) || defaults
    readonly property var zones: only ? { left: only, leftMid: [], center: [], midRight: [], right: [], free: [] } : ({
        left: outside ? (stored.left || []) : (stored.outLeft || []).concat(stored.left || []),
        leftMid: stored.leftMid || [],
        center: stored.center || [],
        midRight: stored.midRight || [],
        right: outside ? (stored.right || []) : (stored.right || []).concat(stored.outRight || []),
        free: stored.free || []
    })
    readonly property var freeAt: Store.get("bar.freeAt", null) || ({})
    readonly property string clockStyle: clockStyleAs || Store.get("bar.clockStyle", "stacked")      // stacked | simple | full | seconds (the old presets)
    // the clock's parts (Settings → Bar → Clock), each a toggle; unset, they follow the old preset
    function clockOpt(k, d) { const v = Store.get("bar.clock." + k, null); return v === null || v === undefined ? d : v; }
    readonly property bool clockSeconds: clockOpt("seconds", clockStyle === "seconds") === true
    readonly property bool clockDate: clockOpt("date", clockStyle === "stacked" || clockStyle === "full") === true
    readonly property string clockDateLayout: String(clockOpt("dateLayout", clockStyle === "full" ? "inline" : "stacked"))   // stacked | inline
    readonly property bool clockWeekday: clockOpt("weekday", true) === true
    readonly property bool clockStackTime: clockOpt("stackTime", false) === true      // hours over minutes
    readonly property bool clock12: clockOpt("hour12", false) === true
    // how the time is drawn (Settings → Bar → Clock → Theme): digital (plain text), pill, segment,
    // flip, dots, analog, words, binary
    readonly property string clockTheme: { const t = clockThemeAs || String(clockOpt("theme", "digital"));
        return ["digital", "pill", "segment", "flip", "dots", "analog", "words", "binary"].indexOf(t) >= 0 ? t : "digital"; }
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
        // (empty ones: a see-through tint of the text, not Theme.control, which on some palettes
        // is the bar's own colour, so empty workspaces vanished into it)
        const A = Theme.accent, faint = Qt.alpha(Theme.text, 0.22), mid = Theme.subtext;
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

    SystemClock { id: clock; enabled: !bar.still; precision: bar.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

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
        onPressedChanged: if (pressed) { const p = m.mapToItem(null, 0, 0); bar.pressedAt = { screen: bar.screenName, x: p.x, y: p.y, w: m.width, h: m.height, t: Date.now() }; }
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

    // ── a module moved (Settings → Bar: another zone, another place in one, along the bar) ──
    // Its new copy starts where the old one was and glides to its place (it jumped there).
    // `lastAt`: where each module was on the bar when it went, and when
    // (noted a few times a second while Settings is open, the only place modules are moved:
    // noting it as the old copy went didn't always happen, and was a call into something
    // already being taken apart)
    property var lastAt: ({})
    function noteAll() {
        const now = Date.now(), m = {};
        for (const k in modItems) {
            const it = modItems[k];
            if (!it || !it.visible || it.flipX !== 0 || it.flipY !== 0) { if (lastAt[k]) m[k] = lastAt[k]; continue; }
            const p = it.mapToItem(bar, 0, 0);
            m[k] = { x: p.x, y: p.y, t: now };
        }
        lastAt = m;
    }
    Timer { interval: 200; repeat: true; running: !bar.still && !bar.only && HubState.open && HubState.page === "settings"; onTriggered: bar.noteAll() }
    // (new copies wait for the bar's own timer, once they're laid out: a delayed call of their
    // own outlived them when the bar was rebuilt, a call into something already gone)
    property var glideQueue: []
    function queueGlide(key, it) { glideQueue.push({ key: key, it: it }); glideTick.restart(); }
    Timer {
        id: glideTick
        interval: 1
        onTriggered: {
            const q = bar.glideQueue;
            bar.glideQueue = [];
            for (const g of q) {
                if (bar.modItems[g.key] !== g.it) continue;      // gone again already
                if (g.it.settled !== undefined) g.it.settled = true;
                bar.glideIn(g.key, g.it);
            }
        }
    }
    function glideIn(key, it) {
        const was = lastAt[key];
        if (still || !Theme.animOn || !was || Date.now() - was.t > 1500 || !it) return;
        const p = it.mapToItem(bar, 0, 0);
        it.flipX = was.x - p.x; it.flipY = was.y - p.y;
        it.startGlide();
    }
    component Glide: ParallelAnimation {
        property Item who
        NumberAnimation { target: who; property: "flipX"; to: 0; duration: Theme.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springyCurve }
        NumberAnimation { target: who; property: "flipY"; to: 0; duration: Theme.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springyCurve }
    }

    // ── the zones ──
    component Zone: Line {
        property var keys: []
        spacing: Number(Store.get("bar.gap", 2))
        Repeater {
            model: parent.keys
            Loader {
                id: zl
                required property string modelData
                sourceComponent: bar.mods[modelData] || null
                property real flipX: 0
                property real flipY: 0
                function startGlide() { zlGlide.restart(); }
                transform: Translate { x: zl.flipX; y: zl.flipY }
                Glide { id: zlGlide; who: zl }
                Component.onCompleted: { bar.modItems[modelData] = this; bar.queueGlide(modelData, this); }
                Component.onDestruction: if (bar.modItems[modelData] === this) delete bar.modItems[modelData]
                // a module with nothing to show (`want: false`) takes no room
                visible: !!item && item.want !== false
            }
        }
    }
    // Modular: each section on a floating pill of its own
    component ZonePill: SmoothRect {
        property Item zone
        visible: Theme.barStyle === "modular" && !bar.only && !!zone && bar.len(zone) > 0
        x: bar.vertical || !zone ? 0 : zone.x - 8
        y: bar.vertical && zone ? zone.y - 8 : 0
        width: bar.vertical ? bar.width : (zone ? zone.width + 16 : 0)
        height: bar.vertical ? (zone ? zone.height + 16 : 0) : bar.height
        radius: Theme.barRound(Math.min(width, height))
        color: Theme.barOpacity >= 0.99 ? Theme.barFill : Qt.alpha(Theme.barFill, Theme.barFill.a * Theme.barOpacity)
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        // centred, so it doesn't read as a second pill below (hard-shadow styles keep theirs)
        CardShadow { visible: Theme.barOpacity > 0.3; offsetY: Theme.hardShadow > 0 ? Theme.shadowY : 0 }
    }
    ZonePill { id: leftPillR; zone: leftZone }
    ZonePill { id: midPillR; zone: midZone }
    ZonePill { id: rightPillR; zone: rightZone }
    ZonePill { zone: leftMidZone }
    ZonePill { zone: midRightZone }
    // (free modules: one each)
    Repeater {
        model: freeRep.count
        ZonePill {
            required property int index
            zone: freeRep.itemAt(index)
            visible: Theme.barStyle === "modular" && !bar.only && !!zone && zone.visible
        }
    }
    // (the island's blur is cut to these in Modular)
    readonly property Item leftPill: leftPillR
    readonly property Item midPill: midPillR
    readonly property Item rightPill: rightPillR
    // (a vertical bar: left is the top, right the bottom)
    readonly property real barLen: vertical ? height : width
    // where a zone starts along the bar, and across it (centred)
    readonly property real leftAt: Theme.islandPad
    // (spread: in the middle, unless a side has grown into it, a long tray on a bar the screen
    // caps: then it moves aside, between the two, instead of the sides drawing over it)
    readonly property real midAt: spread
        ? Math.round(Math.max(leftAt + part(leftZone) + part(leftMidZone),
                              Math.min((barLen - len(midZone)) / 2, barLen - Theme.islandPad - part(rightZone) - part(midRightZone) - len(midZone))))
        : leftAt + part(leftZone) + part(leftMidZone)
    readonly property real rightAt: spread ? barLen - len(rightZone) - Theme.islandPad : midAt + part(midZone) + part(midRightZone)
    // the in-between zones: in the middle of their gap (kept clear of what's either side)
    readonly property real leftMidAt: spread
        ? Math.round(Math.max(leftAt + part(leftZone), Math.min((leftAt + len(leftZone) + midAt - len(leftMidZone)) / 2, midAt - part(leftMidZone))))
        : leftAt + part(leftZone)
    readonly property real midRightAt: spread
        ? Math.round(Math.max(midAt + part(midZone), Math.min((midAt + len(midZone) + rightAt - len(midRightZone)) / 2, rightAt - part(midRightZone))))
        : midAt + part(midZone)
    Zone { id: leftZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.leftAt; y: bar.vertical ? bar.leftAt : Math.round((bar.height - height) / 2); keys: bar.zones.left || [] }
    // a full-width bar spreads them: left edge, middle, right edge
    Zone { id: midZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.midAt; y: bar.vertical ? bar.midAt : Math.round((bar.height - height) / 2); keys: bar.zones.center || [] }
    Zone { id: rightZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.rightAt; y: bar.vertical ? bar.rightAt : Math.round((bar.height - height) / 2); keys: bar.zones.right || [] }
    Zone { id: leftMidZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.leftMidAt; y: bar.vertical ? bar.leftMidAt : Math.round((bar.height - height) / 2); keys: bar.zones.leftMid || [] }
    Zone { id: midRightZone; x: bar.vertical ? Math.round((bar.width - width) / 2) : bar.midRightAt; y: bar.vertical ? bar.midRightAt : Math.round((bar.height - height) / 2); keys: bar.zones.midRight || [] }
    // free modules: each centred on its own point along the bar, kept inside it
    Repeater {
        id: freeRep
        model: bar.zones.free || []
        Loader {
            id: fl
            required property string modelData
            sourceComponent: bar.mods[modelData] || null
            property real flipX: 0
            property real flipY: 0
            function startGlide() { flGlide.restart(); }
            transform: Translate { x: fl.flipX; y: fl.flipY }
            Glide { id: flGlide; who: fl }
            Component.onCompleted: { bar.modItems[modelData] = this; bar.queueGlide(modelData, this); }
            Component.onDestruction: if (bar.modItems[modelData] === this) delete bar.modItems[modelData]
            visible: !!item && item.want !== false
            readonly property real at: Math.max(0, Math.min(1, Number(bar.freeAt[modelData] !== undefined ? bar.freeAt[modelData] : 0.5)))
            readonly property real along: bar.vertical ? height : width
            readonly property real pos: Math.round(Math.max(Theme.islandPad, Math.min(bar.barLen - Theme.islandPad - along, bar.barLen * at - along / 2)))
            x: bar.vertical ? Math.round((bar.width - width) / 2) : pos
            y: bar.vertical ? pos : Math.round((bar.height - height) / 2)
            // moved along the bar (Settings → Bar): it glides to its new place, the same way as in
            // the settings' lane. Not as the bar is first laid out, and not in a still preview
            property bool settled: false
            Behavior on x { enabled: settled && !bar.vertical && !bar.still && Theme.animOn; NumberAnimation { duration: Theme.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springyCurve } }
            Behavior on y { enabled: settled && bar.vertical && !bar.still && Theme.animOn; NumberAnimation { duration: Theme.ms(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springyCurve } }
        }
    }

    readonly property var mods: ({
        cc: ccC, search: searchC, clock: clockC, weather: weatherC, workspaces: wsC, media: mediaC, title: titleC,
        live: liveC, tray: trayC, stats: statsC, notifications: notifC, network: netC, sound: soundC,
        battery: batC, keyboard: kbC, gaming: gameC, power: powerC, updates: updC,
        bluetooth: btC, visualizer: visC, nightlight: nightC, awake: awakeC, shuffle: shuffleC,
        taskbar: taskC, start: startC
    })
    // the start button and your apps, two modules (Desktop mode puts them in the middle unless you
    // place them: core/Desk.qml)
    Component { id: taskC; TaskStrip { host: bar; withStart: false } }
    Component { id: startC; TaskStrip { host: bar; withApps: false } }
    // the room it has: the bar, less the other zones (it's alone in its own, the middle or the left)
    // (of the screen's room: the bar's own length grows as it's squeezed smaller to fit)
    // (an island's curved ends hang outside its body: room for them too)
    // (a bar that fits its modules has no length of its own to go by: it would shrink with the
    // taskbar, and the taskbar with it, down to the smallest icons. The screen's room then)
    // (a set length, % or px: that length, not the bar's as it is now, which the taskbar itself
    // made longer: the apps fit in the length you set instead of stretching the bar)
    readonly property real setLen: maxLen > 0 ? Theme.barWidth(maxLen + 2 * Theme.barMargin, 0) : barLen
    // (a mini bar (`only`) has no length of its own: as long as its modules need)
    readonly property real taskRoom: only ? 100000
        : (Theme.barSpread ? setLen : (maxLen > 0 ? maxLen : 100000)) - 2 * Theme.islandPad - freeLen - 2 * gap
          - (Theme.barStyle === "island" ? 2 * Theme.islandEar + 24 : 0) - taskOthers
    // (what the taskbar's apps leave to the rest: every zone but its own, and the start button)
    readonly property real taskOthers: {
        // (the middle centred, Desktop mode: as much room taken on each side as the wider side needs)
        if (centerMid && (zones.center || []).indexOf("taskbar") !== -1)
            return 2 * Math.max(part(leftZone) + part(leftMidZone), part(rightZone) + part(midRightZone))
                + ((zones.center || []).length - 1) * (Theme.islandH + Number(Store.get("bar.gap", 2)));
        const zs = [[leftZone, "left"], [leftMidZone, "leftMid"], [midZone, "center"], [midRightZone, "midRight"], [rightZone, "right"]];
        let n = 0;
        for (const z of zs) {
            const keys = zones[z[1]] || [];
            if (keys.indexOf("taskbar") === -1) n += part(z[0]);
            else n += (keys.length - 1) * (Theme.islandH + Number(Store.get("bar.gap", 2)));
        }
        return n;
    }

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
            BarClock {
                visible: bar.clockTheme !== "digital"
                theme: bar.clockTheme
                now: bar.now
                seconds: bar.clockSeconds
                h12: bar.clock12
                vertical: bar.vertical
                still: bar.still
                room: Theme.islandH - 14
            }
            Text {
                visible: bar.clockTheme === "digital"
                text: bar.timeText(bar.now)
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
                Text { visible: bar.clockWeekday; text: Qt.formatDate(bar.now, "dddd"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1; font.weight: Font.Medium }
                Text { text: Qt.formatDate(bar.now, "d MMM"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1 }
            }
            Text {
                visible: bar.clockDate && bar.clockDateLayout === "inline" && !bar.vertical
                text: Qt.formatDate(bar.now, bar.clockWeekday ? "ddd d MMM" : "d MMM")
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
            // the pills' model, kept in step with the list by id: a pill stays when the others
            // change and only a workspace that came or went is added or taken away. (A count for a
            // model rebuilt every pill whenever it changed, which on Hyprland is every switch to or
            // from an empty workspace: each one popped in again, all at once, for over a second)
            readonly property var byId: { const m = {}; for (const w of list) m[w.id] = w; return m; }
            property int activeIndex: -1
            property int rev: 0
            ListModel { id: wsModel }
            function syncWs() {
                const want = list.map(w => w.id);
                for (let i = wsModel.count - 1; i >= 0; i--) if (want.indexOf(wsModel.get(i).wid) < 0) wsModel.remove(i);
                for (let i = 0; i < want.length; i++) {
                    if (i < wsModel.count && wsModel.get(i).wid === want[i]) continue;
                    let at = -1;
                    for (let j = i + 1; j < wsModel.count; j++) if (wsModel.get(j).wid === want[i]) { at = j; break; }
                    if (at >= 0) wsModel.move(at, i, 1); else wsModel.insert(i, { wid: want[i] });
                }
                activeIndex = list.findIndex(w => w.is_active);
                rev++;
            }
            onListChanged: syncWs()
            Component.onCompleted: syncWs()
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

            // the open workspace's highlight: its two ends follow the open pill, timed; the one
            // on the side it's heading leads, the other trails, so it stretches over and settles
            SmoothRect {
                smoothing: 0
                id: hi
                readonly property Item at: wsBox.rev >= 0 && wsBox.activeIndex >= 0 ? reps.itemAt(wsBox.activeIndex) : null
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
                // how long each end takes (the end it's heading to, the other one): worm stretches
                // (the leading end quick, the other slow), the rest move in one piece; bouncy goes a
                // little past and back. Timed, so they follow Animations → Speed and are done when
                // they say: springs here ignored the speed and took the best part of a second to
                // settle, and the bar (a window the size of the screen) redrew all that time
                readonly property int lead: Theme.ms(({ worm: 240, slide: 320, bouncy: 460, hop: 340 })[bar.wsAnim] || 320)
                readonly property int trail: Theme.ms(({ worm: 420, slide: 320, bouncy: 460, hop: 340 })[bar.wsAnim] || 320)
                readonly property int curve: bar.wsAnim === "bouncy" ? Easing.OutBack : (bar.wsAnim === "hop" ? Easing.InOutCubic : Easing.OutCubic)
                readonly property bool moves: hi.ready && ["worm", "slide", "bouncy", "hop"].indexOf(bar.wsAnim) >= 0
                Behavior on a { enabled: hi.moves; NumberAnimation { duration: hi.dir > 0 ? hi.trail : hi.lead; easing.type: hi.curve; easing.overshoot: 1.6 } }
                Behavior on b { enabled: hi.moves; NumberAnimation { duration: hi.dir > 0 ? hi.lead : hi.trail; easing.type: hi.curve; easing.overshoot: 1.6 } }
                // hop: up and over in an arc, highest halfway
                readonly property real hop: bar.wsAnim !== "hop" || Math.abs(toA - fromA) < 1 ? 0
                    : Math.sin(Math.PI * Math.max(0, Math.min(1, (a - fromA) / (toA - fromA)))) * Math.min(9, Math.abs(toA - fromA) * 0.25)
                // fade: out where it was, in where it's going (it doesn't travel)
                NumberAnimation { id: fadeIn; target: hi; property: "opacity"; from: 0; to: 1; duration: Theme.ms(240); easing.type: Easing.OutCubic }
                x: bar.vertical ? (wsBox.width - thick) / 2 - hop : a
                y: bar.vertical ? a : (wsBox.height - thick) / 2 - hop
                width: bar.vertical ? thick : Math.max(1, b - a)
                height: bar.vertical ? Math.max(1, b - a) : thick
                radius: Theme.rnd(at ? at.radius : 0)
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
                    // (by id, not the list itself: a new list on every switch rebuilt every pill,
                    // and a pill made just now has nothing to animate from, so nothing moved)
                    model: wsModel
                    SmoothRect {
                        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                        id: pill
                        required property int index
                        required property var wid
                        readonly property var modelData: wsBox.byId[wid] || ({ idx: 0, is_active: false, busy: false, id: -1 })
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
                        border.color: busy ? Theme.subtext : Qt.alpha(Theme.text, 0.3)
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
                        // (a short bounce, timed: a spring here wobbled on for over a second)
                        Behavior on scale { enabled: Theme.animOn; NumberAnimation { duration: Theme.ms(280); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
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
            SmoothRect {
                smoothing: 0
                visible: bar.mopt("media.art", true) === true || bar.vertical
                width: 22; height: 22; radius: Theme.rnd(bar.mopt("media.round", true) === true ? 11 : 5)
                color: Theme.control
                clip: true
                Image {
                    anchors.fill: parent
                    source: bar.player ? (bar.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                    rotation: 0
                    RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: !bar.still && bar.player !== null && bar.mopt("media.spin", true) === true }
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
            Image { visible: titleMod.iconMode === "app" && !bar.vertical; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: (titleMod.entry ? titleMod.entry.icon : Niri.focusedAppId) ? Quickshell.iconPath(titleMod.entry ? titleMod.entry.icon : Niri.focusedAppId, "application-x-executable") : "" }
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
                width: 9; height: 9; radius: (Theme.chamfer || Theme.square) ? 0 : 4.5; color: Theme.danger
                SequentialAnimation on opacity { running: !bar.still && live.mode === "rec"; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
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
    // game mode: always there once it's on the bar (it only showed while game mode was on, so
    // a bar with it looked as if it had lost it); lit up in the accent while game mode is on.
    // Click: the Gaming menu; right-click: game mode on or off
    Component { id: gameC; Glyph { icon: "sports_esports"; on: GameMode.active; tint: GameMode.active ? Theme.accent : Theme.text
                                   onClicked: bar.open("gaming"); onRightClicked: GameMode.toggle() } }

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
                id: statRep
                model: [["cpu", "memory", Math.round(Stats.cpu * 100) + "%"], ["mem", "data_usage", Math.round(Stats.mem * 100) + "%"],
                        ["temp", "thermostat", Math.round(Stats.temp) + "°"], ["gpu", "videogame_asset", Math.round(Stats.gpu * 100) + "%"],
                        ["vram", "developer_board", Math.round(Stats.vram * 100) + "%"], ["gtemp", "device_thermostat", Math.round(Stats.gpuTemp) + "°"]].filter(x => parent.parent.which.indexOf(x[0]) !== -1)
                Line {
                    required property var modelData
                    spacing: bar.vertical ? 0 : 3
                    // (what it's short of its widest value, 100 %: made up at the end of the module)
                    readonly property real slack: bar.vertical ? 0 : Math.max(0, widest.width - statText.implicitWidth)
                    Icon { visible: bar.mopt("stats.icons", true) === true; name: modelData[1]; size: 15; color: Theme.subtext }
                    Label {
                        id: statText
                        renderType: bar.only ? Text.QtRendering : Text.NativeRendering
                        text: modelData[2]; font.pixelSize: Theme.sizeSmall
                        TextMetrics { id: widest; font: statText.font; text: "100" + modelData[2].slice(-1) }
                    }
                }
            }
            // the room the values are short of 100 %, all together after the last one: the module
            // stays one width (a number changing width moved everything after it, and a bar that
            // fits its modules changed length), without a gap before every short number
            Item {
                visible: !bar.vertical
                width: { let w = 0; for (let i = 0; i < statRep.count; i++) { const it = statRep.itemAt(i); if (it) w += it.slack; } return w; }
                height: 1
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
    // the battery (laptops; hidden when there's none). Its look (Settings → Bar → Battery):
    // "icon" the battery icon, "cell" a little battery drawn filling up, "ring" a ring round
    // a bolt or the number, "text" only the number. (Its settings' preview shows one at 72 %
    // on a computer without a battery: there was nothing to see there before)
    Component {
        id: batC
        Mod {
            id: bm
            readonly property var dev: UPower.displayDevice
            readonly property bool real: !!dev && dev.isLaptopBattery
            property bool want: real || bar.still
            readonly property real level: real ? dev.percentage : 0.72
            readonly property bool charging: real && dev.state === UPowerDeviceState.Charging
            readonly property bool low: level < Number(bar.mopt("battery.low", 20)) / 100
            readonly property string look: { const v = String(bar.mopt("battery.look", "icon")); return ["icon", "cell", "ring", "text"].indexOf(v) !== -1 ? v : "icon"; }
            readonly property color tone: low && !charging ? Theme.danger : (charging ? Theme.accent : Theme.text)
            readonly property bool showPct: look === "text" || bar.mopt("battery.percent", true) === true
            // the number in the battery or the ring instead of beside it (Settings → Battery → Percentage)
            readonly property bool inside: showPct && (look === "cell" || look === "ring") && bar.mopt("battery.pctPlace", "beside") === "inside"
            readonly property string pct: Math.round(level * 100) + ""
            pad: 7
            onClicked: bar.open("quick")
            Icon {
                visible: bm.look === "icon"
                name: bm.charging ? "battery_charging_full" : (bm.low ? "battery_alert" : "battery_full")
                size: 18; filled: true
                color: bm.low && !bm.charging ? Theme.danger : Theme.text
            }
            // a battery: an outline with a nub, filled to the level
            Item {
                visible: bm.look === "cell"
                width: cellBody.width + 3; height: cellBody.height
                Rectangle {
                    id: cellBody
                    // (bigger with the number in it)
                    width: bm.inside ? 32 : 23; height: bm.inside ? 17 : 14
                    radius: (Theme.chamfer || Theme.square) ? 0 : 4
                    color: "transparent"
                    border.width: 1.6; border.color: Qt.alpha(bm.tone, 0.85)
                    Rectangle {
                        x: 2.5; y: 2.5
                        width: Math.max(2, (parent.width - 5) * Math.max(0, Math.min(1, bm.level)))
                        height: parent.height - 5
                        radius: (Theme.chamfer || Theme.square) ? 0 : 2
                        color: bm.tone
                        Behavior on width { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutCubic } }
                    }
                    Icon { visible: bm.charging && !bm.inside; anchors.centerIn: parent; name: "bolt"; size: 12; filled: true; color: Theme.frame }
                    // the number: the bar's colour where the fill is under it, the fill's colour where it isn't
                    Text {
                        id: cellPct
                        visible: bm.inside
                        anchors.centerIn: parent
                        text: bm.pct
                        color: bm.tone
                        font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Black
                    }
                    Item {
                        visible: bm.inside
                        x: 2.5; y: 2.5
                        width: Math.max(2, (parent.width - 5) * Math.max(0, Math.min(1, bm.level))); height: parent.height - 5
                        clip: true
                        Text {
                            x: cellPct.x - 2.5; y: cellPct.y - 2.5
                            text: bm.pct
                            color: Theme.frame.a > 0.5 ? Qt.rgba(Theme.frame.r, Theme.frame.g, Theme.frame.b, 1) : "#000000"
                            font: cellPct.font
                        }
                    }
                }
                Rectangle { x: 24; anchors.verticalCenter: cellBody.verticalCenter; width: 2; height: 6; radius: (Theme.chamfer || Theme.square) ? 0 : 1; color: Qt.alpha(bm.tone, 0.85) }
            }
            // a ring round a bolt (charging) or a dot, filled round to the level
            Canvas {
                id: ring
                visible: bm.look === "ring"
                width: bm.inside ? 24 : 18; height: width
                onWidthChanged: requestPaint()
                readonly property real lv: bm.level
                readonly property color c: bm.tone
                readonly property color track: Qt.alpha(Theme.text, 0.18)
                onLvChanged: requestPaint(); onCChanged: requestPaint(); onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const g = getContext("2d"); g.reset();
                    const r = width / 2 - 1.8;
                    g.lineWidth = 2.6; g.lineCap = "round";
                    g.strokeStyle = track; g.beginPath(); g.arc(width / 2, height / 2, r, 0, 2 * Math.PI); g.stroke();
                    g.strokeStyle = c; g.beginPath(); g.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, Math.min(1, lv))); g.stroke();
                }
                Icon { visible: bm.charging && !bm.inside; anchors.centerIn: parent; name: "bolt"; size: 11; filled: true; color: bm.tone }
                Text { visible: bm.inside; anchors.centerIn: parent; text: bm.pct; color: bm.tone; font.family: Theme.fontFamily; font.pixelSize: bm.pct.length > 2 ? 7 : 9; font.weight: Font.Black }
            }
            Label { renderType: bar.only ? Text.QtRendering : Text.NativeRendering; visible: bm.showPct && !bm.inside; text: Math.round(bm.level * 100) + "%"; font.pixelSize: Theme.sizeSmall; color: bm.look === "text" ? bm.tone : Theme.text }
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
            readonly property real gap: Number(opt("spacing", 2))
            // wide enough for its bars (2 px each and the gaps): more bars than the width took
            // spilled out over the modules beside it
            readonly property real fitW: Math.max(wantW, wantN * 2 + Math.max(0, wantN - 1) * gap)
            property bool want: bar.visPreview || bar.player !== null || opt("always", false) === true
            onClicked: bar.open("media")
            Faces.CavaBars {
                // (down a side bar: as wide as the bar allows, with fewer bars to match)
                width: bar.vertical ? Math.min(vm.wantW, Theme.islandH - 26) : Math.min(vm.fitW, bar.visCap)
                height: vm.wantH
                // (down a side bar, or squeezed on a full one, the width can't grow: fewer bars, as
                // many as fit)
                count: bar.vertical || width < vm.fitW ? Math.max(3, Math.min(vm.wantN, Math.floor((width + vm.gap) / (2 + vm.gap)))) : vm.wantN
                onWidthChanged: if (!bar.vertical) bar.visNow = width
                Component.onCompleted: if (!bar.vertical) bar.visNow = width
                Component.onDestruction: if (!bar.vertical) bar.visNow = 0
                spacing: vm.gap
                clip: true
                minLen: Number(vm.opt("rest", 2))
                continuous: vm.opt("style", "bars") === "smooth"
                mirror: vm.opt("anchor", "bottom") === "middle"
                flip: vm.opt("anchor", "bottom") === "top"
                roundness: Number(vm.opt("roundness", 1))
                scaleY: Number(vm.opt("scale", 1))
                fade: vm.opt("fade", true) === true
                dynamic: vm.opt("dynamic", true) === true
                smoothMs: Number(vm.opt("smoothing", 70))
                live: !bar.still && (bar.player !== null || (vm.opt("always", false) === true && !bar.visPreview))
                preview: bar.visPreview || bar.still
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
    // (a preview looks once)
    Timer { interval: 10000; running: true; repeat: !bar.still; triggeredOnStart: true; onTriggered: netProc.running = true }
}
