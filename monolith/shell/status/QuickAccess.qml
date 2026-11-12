import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Quick access: rest the pointer on a screen edge (any of them, Settings → Desktop → Quick
// access) and a mini bar of tools slides out of the edge right where the pointer is, joined to
// it by soft curves. Drag the mini bar away from the edge (or click a tool) and it opens fully
// into the tool; drag it back towards the edge to fold it, and again to put it away. Scroll on
// the tools (or Tab / the arrow keys) to switch, the pin keeps it out, Escape folds and hides.
// It doesn't come over fullscreen windows (unless allowed) or while Game mode is on.
PanelWindow {
    id: qa
    required property var modelData
    screen: modelData

    // ── settings ──
    readonly property bool enabled: Store.get("quick.enabled", true) !== false
    readonly property var edges: { const e = Store.get("quick.edges", null); return Array.isArray(e) ? e : [Store.get("quick.edge", "right")]; }
    readonly property var tools: { const t = Store.get("quick.tools", ["calc", "convert", "notes", "timer", "draw", "usage"]); return t && t.length ? t : ["notes"]; }
    // its own speed setting, scaled like every other animation (Theme → Effects → speed; 0 when off)
    readonly property int speed: Theme.ms(Number(Store.get("quick.speed", 260)))
    readonly property int showDelay: Number(Store.get("quick.delay", 250))
    readonly property int hideDelay: Number(Store.get("quick.hideDelay", 600))
    readonly property real hit: Math.max(1, Number(Store.get("quick.edgeSize", 2)))
    readonly property bool opensFull: Store.get("quick.touch", "bar") === "full"
    readonly property bool rememberTool: Store.get("quick.remember", true) !== false
    readonly property string sizeName: Store.get("quick.size", "normal")
    // the open tool's size (Settings → Desktop → Quick access), or much bigger with the rail's
    // expand button (remembered): as big as the screen allows, leaving room round it
    // (read from the setting; the buttons write the setting: a property that did both looped)
    readonly property bool big: Store.get("quick.big", false) === true
    // or maximized: the whole screen but the bar and a small margin (the rail's maximize button)
    readonly property bool maxed: Store.get("quick.max", false) === true
    // (along the edge it leaves room for the curves joining the edge: 2 × ear + margins)
    readonly property real roomW: maxed ? (vertical ? width - railT - 40 : width - 2 * ear - 48) : (vertical ? width - railT - 120 : width - 160)
    readonly property real roomH: maxed ? (vertical ? height - topRoom - bottomRoom - 2 * ear - 48 : height - topRoom - bottomRoom - railT - 40)
                                        : (vertical ? height - topRoom - bottomRoom - 60 : height - topRoom - bottomRoom - railT - 120)
    readonly property real contentW: maxed ? Math.max(300, roomW) : (big ? Math.max(400, Math.min(1100, roomW)) : (({ small: 380, normal: 440, large: 540 })[sizeName] || 440))
    readonly property real contentH: maxed ? Math.max(300, roomH) : (big ? Math.max(500, Math.min(860, roomH)) : (({ small: 520, normal: 620, large: 760 })[sizeName] || 620))

    // when it may come out: not in Game mode, not over a fullscreen window, maybe only on an empty workspace
    readonly property var active: ToplevelManager.activeToplevel
    readonly property bool blocked: (GameMode.active && Store.get("quick.offInGameMode", true) !== false)
        || (!!active && active.fullscreen && Store.get("quick.overFullscreen", false) !== true)
        || (Store.get("quick.emptyOnly", false) === true && focusedHasWindows)
    readonly property bool focusedHasWindows: {
        const ws = Niri.workspaces.find(w => w.output === modelData.name && w.is_active);
        return !!ws && Niri.workspaceHasWindows(ws.id);
    }
    onBlockedChanged: if (blocked && !pinned) hide()

    // ── state ──
    property string edge: edges.length ? edges[0] : "right"     // where it is now
    property real pos: 0                                         // its middle, along the edge
    property bool shown: false                                   // the mini bar is out
    property bool expanded: false                                // and open into a tool
    property bool pinned: false
    property string tool: tools[0]
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool out: shown || expanded

    function show(e, p, full) {
        if (blocked && !pinned) return;
        putAway.stop();
        edge = e; pos = p;
        if (!rememberTool || tools.indexOf(tool) === -1) tool = tools[0];
        shown = true;
        if (full) expanded = true;
        hideTimer.stop();
    }
    Connections {
        target: HubState
        function onQuickReqChanged() {
            const r = HubState.quickReq;
            if (r.edge === "hide") { qa.hide(); return; }
            if (r.screen !== qa.modelData.name) return;
            const e = r.edge !== "" ? r.edge : (qa.edges.length ? qa.edges[0] : "right");
            // opened by a keybind: it stays until the pointer has been on it and left (or Escape)
            qa.show(e, (e === "left" || e === "right") ? qa.height / 2 : qa.width / 2, r.full);
        }
    }
    // put away: an open one folds into the mini bar first, then slides into the edge
    function hide() {
        pinned = false;
        if (expanded) { expanded = false; putAway.restart(); }
        else shown = false;
    }
    // (the slide starts while it's still folding: the exit curve starts slowly, so it reads as one move)
    Timer { id: putAway; interval: Math.round(qa.speed * 0.35); onTriggered: if (!qa.expanded) qa.shown = false }
    function fold() { if (expanded) expanded = false; else hide(); }
    function step(d) { const i = tools.indexOf(tool); tool = tools[Math.max(0, Math.min(tools.length - 1, (i < 0 ? 0 : i) + d))]; }

    visible: enabled
    WlrLayershell.namespace: "monolith-quick"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: out ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // the edge strips take the mouse, and the bar (with its panel) while it's out
    mask: Region {
        Region { item: qa.out ? body : null }
        Region { item: strips.lStrip }
        Region { item: strips.rStrip }
        Region { item: strips.tStrip }
        Region { item: strips.bStrip }
    }

    // ── the edges: resting on one for a moment brings the bar out there ──
    // (not along the bar's own edge, and the dock's edge only away from the dock's middle)
    readonly property real topRoom: Theme.barEdge === "top" ? Theme.islandH + Theme.barMargin + 6 : 0
    readonly property real bottomRoom: Theme.barEdge === "bottom" ? Theme.islandH + Theme.barMargin + 6 : 0
    readonly property string dockEdge: Store.get("dock.enabled", true) !== false ? Store.get("dock.position", "bottom") : ""
    function stripOn(e) { return enabled && !out && edges.indexOf(e) !== -1 && e !== Theme.barEdge; }
    function dockGap(e) { return dockEdge === e ? 0.25 : 0; }
    QtObject {
        id: strips
        property Item lStrip: qa.stripOn("left") ? stripL : null
        property Item rStrip: qa.stripOn("right") ? stripR : null
        property Item tStrip: qa.stripOn("top") ? stripT : null
        property Item bStrip: qa.stripOn("bottom") ? stripB : null
    }
    component Strip: Item {
        id: st
        required property string side
        readonly property bool vert: side === "left" || side === "right"
        // the dock sits in the middle of its edge: the strip leaves that part to it
        readonly property real gap: qa.dockGap(side)
        visible: qa.stripOn(side)
        x: side === "right" ? qa.width - qa.hit : 0
        y: side === "bottom" ? qa.height - qa.hit : (vert ? qa.topRoom : 0)
        width: vert ? qa.hit : qa.width
        height: vert ? qa.height - qa.topRoom - qa.bottomRoom : qa.hit
        HoverHandler {
            id: hh
            onHoveredChanged: if (hovered) showTimer.restart(); else showTimer.stop()
            onPointChanged: {
                const p = st.vert ? point.position.y + st.y : point.position.x;
                const ext = st.vert ? qa.height : qa.width;
                if (st.gap > 0 && Math.abs(p - ext / 2) < ext * st.gap) showTimer.stop();
                else if (hovered && !showTimer.running && !qa.out) showTimer.restart();
                showTimer.at = p;
            }
        }
        Timer {
            id: showTimer
            property real at: 0
            interval: qa.showDelay
            onTriggered: qa.show(st.side, at, qa.opensFull)
        }
    }
    Strip { id: stripL; side: "left" }
    Strip { id: stripR; side: "right" }
    Strip { id: stripT; side: "top" }
    Strip { id: stripB; side: "bottom" }

    // ── sizes ──
    readonly property real tab: 44                                // a tool's button
    readonly property real railT: 60                              // the mini bar's thickness
    readonly property real railL: tools.length * (tab + 6) + 3 * (tab + 6) + 24   // its length (the tools, then expand, maximize and the pin)
    readonly property real ear: Theme.islandEar
    // open: the rail plus the tool beside it
    // (out of a side edge the tool is beside the rail; out of the top or bottom, under / over it)
    readonly property real across: vertical ? contentW : contentH
    readonly property real along: vertical ? contentH : contentW
    // (folding waits for the open tool to fade first, so the panel never closes over it)
    readonly property bool roomy: expanded || content.visible
    readonly property real thick: roomy ? railT + across + 16 : railT
    readonly property real span: roomy ? Math.max(railL, along + 24) : railL
    // how far out it is (0: tucked into the edge), and the drag pulling it (a little rubber band)
    property real pull: 0
    Behavior on pull { enabled: !drag.active; NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
    property real slide: shown || expanded ? 0 : railT + ear + 30
    Behavior on slide { NumberAnimation { duration: qa.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: qa.out ? Theme.springCurve : Theme.exitCurve } }

    // the bar's box in the window (its long side along the edge, centred on `pos`)
    readonly property real ext: vertical ? height : width
    readonly property real lo: vertical ? topRoom + 8 : 8
    readonly property real hi: ext - (vertical ? bottomRoom + 8 : 8)
    readonly property real mid: Math.max(lo + bodyLong / 2 + ear, Math.min(hi - bodyLong / 2 - ear, pos))
    property real bodyLong: span
    property real bodyThick: thick
    // opening springs out a little past its size; folding eases in without overshoot (a spring
    // going smaller dipped below the rail and squashed it)
    Behavior on bodyLong { NumberAnimation { duration: qa.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: qa.expanded ? Theme.springCurve : qa.foldCurve } }
    Behavior on bodyThick { NumberAnimation { duration: qa.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: qa.expanded ? Theme.springCurve : qa.foldCurve } }
    readonly property var foldCurve: [0.3, 0.0, 0.1, 1.0, 1, 1]
    readonly property real outBy: Math.max(-railT, Math.min(40, pull)) - slide      // >0: further out

    Item {
        id: body
        // the bar's own box (without the ears), placed against its edge
        readonly property real t: qa.bodyThick + Math.max(0, qa.outBy)
        width: qa.vertical ? t : qa.bodyLong
        height: qa.vertical ? qa.bodyLong : t
        x: qa.edge === "left" ? Math.min(0, qa.outBy) : (qa.edge === "right" ? qa.width - width - Math.min(0, qa.outBy) : qa.mid - width / 2)
        y: qa.edge === "top" ? Math.min(0, qa.outBy) : (qa.edge === "bottom" ? qa.height - height - Math.min(0, qa.outBy) : qa.mid - height / 2)
        visible: qa.out || qa.slide < qa.railT + qa.ear + 29

        // the outline: the island's shape (a body with curves joining the edge), turned to face out of this edge
        Item {
            width: qa.vertical ? body.height + 2 * qa.ear : body.width + 2 * qa.ear
            height: qa.vertical ? body.width : body.height
            anchors.centerIn: parent
            rotation: ({ top: 0, right: 90, bottom: 180, left: -90 })[qa.edge]
            IslandShape {
                anchors.fill: parent
                bodyW: parent.width - 2 * e
                r: Theme.islandRadius
                fill: Theme.frame
            }
        }
        HoverHandler { id: bodyHover; onHoveredChanged: if (hovered) hideTimer.stop(); else if (!qa.pinned) hideTimer.restart() }

        // the rail: the tools (and the pin) along the edge
        Item {
            id: railBox
            x: qa.edge === "right" ? body.width - qa.railT : 0
            y: qa.edge === "bottom" ? body.height - qa.railT : 0
            width: qa.vertical ? qa.railT : body.width
            height: qa.vertical ? body.height : qa.railT
            WheelHandler {
                onWheel: ev => qa.step(ev.angleDelta.y > 0 ? -1 : 1)
            }
            // drag it out (opens), drag it in (folds, then hides): only on the rail (over the open
            // tool it took every drag, so the drawing pad's strokes pulled the panel instead)
            DragHandler {
                id: drag
                target: null
                dragThreshold: 6
                onTranslationChanged: {
                    const t = translation;
                    qa.pull = qa.edge === "left" ? t.x : qa.edge === "right" ? -t.x : qa.edge === "top" ? t.y : -t.y;
                }
                onActiveChanged: {
                    if (active) return;
                    if (qa.pull > 30 && !qa.expanded) qa.expanded = true;
                    else if (qa.pull < -30) qa.fold();
                    qa.pull = 0;
                }
            }

            Grid {
                anchors.centerIn: parent
                columns: qa.vertical ? 1 : qa.tools.length + 3
                rows: qa.vertical ? qa.tools.length + 3 : 1
                spacing: 6
                Repeater {
                    model: qa.tools
                    Pressable {
                        required property string modelData
                        readonly property bool on: qa.tool === modelData && qa.expanded
                        width: qa.tab; height: qa.tab
                        radius: Theme.corner(qa.tab, 0)
                        color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                        onClicked: { qa.tool = modelData; qa.expanded = true; }
                        Icon {
                            anchors.centerIn: parent
                            name: ({ calc: "calculate", convert: "swap_horiz", notes: "sticky_note_2", timer: "timer", draw: "draw", usage: "monitoring" })[parent.modelData] || "help"
                            size: 21; filled: parent.on
                            color: parent.on ? Theme.onAccentContainer : (qa.tool === parent.modelData ? Theme.accent : Theme.text)
                        }
                    }
                }
                // much bigger (the drawing pad likes room), or back to its size
                Pressable {
                    width: qa.tab; height: qa.tab
                    radius: Theme.corner(qa.tab, 0)
                    readonly property bool on: qa.big && !qa.maxed
                    color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                    onClicked: { if (qa.maxed) { Store.set("quick.max", false); Store.set("quick.big", true); } else Store.set("quick.big", !qa.big); qa.expanded = true; }
                    Icon { anchors.centerIn: parent; name: parent.on ? "close_fullscreen" : "open_in_full"; size: 19; color: parent.on ? Theme.onAccentContainer : Theme.subtext }
                }
                // maximized: the whole screen (again: back to the size it was)
                Pressable {
                    width: qa.tab; height: qa.tab
                    radius: Theme.corner(qa.tab, 0)
                    color: qa.maxed ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                    onClicked: { Store.set("quick.max", !qa.maxed); qa.expanded = true; }
                    Icon { anchors.centerIn: parent; name: qa.maxed ? "fullscreen_exit" : "fullscreen"; size: 21; color: qa.maxed ? Theme.onAccentContainer : Theme.subtext }
                }
                // keep it out
                Pressable {
                    width: qa.tab; height: qa.tab
                    radius: Theme.corner(qa.tab, 0)
                    color: qa.pinned ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
                    onClicked: { qa.pinned = !qa.pinned; if (!qa.pinned && !bodyHover.hovered) hideTimer.restart(); }
                    Icon { anchors.centerIn: parent; name: "keep"; size: 20; filled: qa.pinned; color: qa.pinned ? Theme.onAccent : Theme.subtext }
                }
            }
            // the grip: a little line on the outer side, says "pull me"
            Rectangle {
                visible: !qa.expanded
                color: Theme.ringTrack
                radius: 2
                width: qa.vertical ? 4 : 36
                height: qa.vertical ? 36 : 4
                x: qa.edge === "left" ? parent.width - 9 : (qa.edge === "right" ? 5 : (parent.width - width) / 2)
                y: qa.edge === "top" ? parent.height - 9 : (qa.edge === "bottom" ? 5 : (parent.height - height) / 2)
            }
        }

        // the open tool, beside the rail
        Item {
            id: clipBox
            anchors.fill: parent
            clip: true
        Item {
            id: content
            readonly property real gap: 8
            x: qa.edge === "left" ? qa.railT + gap : (qa.edge === "right" ? body.width - qa.railT - gap - width : (body.width - width) / 2)
            y: qa.edge === "top" ? qa.railT + gap : (qa.edge === "bottom" ? body.height - qa.railT - gap - height : (body.height - height) / 2)
            width: qa.contentW
            height: qa.contentH
            // in once the panel is most of the way open; when it folds, gone before the panel
            // closes over it (it fades and shrinks towards the rail instead of being cut off)
            readonly property bool on: qa.expanded && qa.bodyThick > qa.railT + qa.across * 0.7
            opacity: on ? 1 : 0
            scale: on ? 1 : 0.92
            transformOrigin: ({ left: Item.Left, right: Item.Right, top: Item.Top, bottom: Item.Bottom })[qa.edge]
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: content.on ? Math.max(Theme.ms(120), qa.speed * 0.6) : Math.min(Theme.ms(70), qa.speed * 0.25); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: content.on ? Math.max(Theme.ms(120), qa.speed * 0.6) : Math.min(Theme.ms(70), qa.speed * 0.25); easing.type: Easing.OutCubic } }
            Loader {
                anchors.fill: parent
                active: qa.expanded || content.visible
                source: "quick/" + ({ calc: "Calc", convert: "Convert", notes: "Notes", timer: "Timer", draw: "Draw", usage: "Usage" })[qa.tool] + ".qml"
            }
        }
        }
    }

    // leaving it puts it away (unless pinned, or you're typing in it)
    Timer {
        id: hideTimer
        interval: qa.hideDelay
        onTriggered: if (!qa.pinned && !bodyHover.hovered && !drag.active && !qa.typing && !HubState.quickHold) qa.hide()
    }

    // the keyboard, while it's out
    Item {
        id: keys
        focus: qa.out
        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape) { qa.fold(); ev.accepted = true; }
            else if (ev.key === Qt.Key_Tab || ev.key === Qt.Key_Down || ev.key === Qt.Key_Right) { qa.step(1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Backtab || ev.key === Qt.Key_Up || ev.key === Qt.Key_Left) { qa.step(-1); ev.accepted = true; }
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { qa.expanded = true; ev.accepted = true; }
        }
    }
    onOutChanged: if (out) keys.forceActiveFocus()
    // something in a tool has the keyboard (the calculator, notes): leaving doesn't put it away
    readonly property bool typing: { const f = keys.Window.activeFocusItem; return qa.expanded && !!f && f !== keys && (f instanceof TextInput || f instanceof TextEdit); }

    // blur behind it (Theme → Effects)
    // (kept while it slides away: it used to vanish the moment hiding started)
    BackgroundEffect.blurRegion: Theme.blur && body.visible ? blurShape : null
    // cut like its shape: square against the edge, rounded inside, with the ears
    Region {
        id: blurShape
        EdgeBlur {
            readonly property real thick: qa.vertical ? body.width : body.height
            readonly property real long: qa.vertical ? body.height : body.width
            edge: qa.edge
            bx: body.x; by: body.y; bw: body.width; bh: body.height
            e: Math.max(0, Math.min(qa.ear, thick / 2))
            r: Math.max(0, Math.min(Theme.islandRadius, thick - e, long / 2))
        }
    }
}
