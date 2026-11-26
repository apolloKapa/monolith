import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Mini bars (Settings → Bar → Mini bars): little bars of their own, each a pill holding the bar
// modules you put in it, at a spot of the screen's edges: a corner, the middle of an edge, the
// middle of a side (there it runs top to bottom). Several at one spot sit side by side. Their
// modules work as in the bar: their menus open, their drop-downs drop away from the mini bar's edge.
// Hold one (or Settings → Move them) to move them: drag a mini bar anywhere and it goes to the
// spot nearest to where you let go. They keep clear of the bar, and windows can keep clear of them.
// Store bar.minis: [{ place, modules: [...], reserve }]. One full-screen window per screen (taking
// clicks only on the pills): windows of their own would change size as their modules' text did,
// which makes Hyprland's whole screen twitch.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    // (a list, whatever the file holds: anything else is no mini bars)
    readonly property var all: { const v = Store.get("bar.minis", []); return v && typeof v === "object" && v.length !== undefined ? Array.prototype.slice.call(v) : []; }
    // the ones to draw (with something in them), each with its place in the list kept
    readonly property var minis: all.map((m, i) => ({ i: i, place: places.indexOf(m && m.place) !== -1 ? m.place : "top-right", modules: (m && m.modules ? Array.prototype.slice.call(m.modules) : []).filter(k => k !== "taskbar"), reserve: !!(m && m.reserve) }))
        .filter(m => m.modules.length > 0)
    readonly property var places: ["top-left", "top", "top-right", "left", "right", "bottom-left", "bottom", "bottom-right"]
    readonly property bool barHere: (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    readonly property bool editing: HubState.miniEdit === modelData.name
    readonly property bool overFullscreen: Niri.fullscreenOn(modelData.name)
    // auto-hide: they go away with the bar and come back with it (while moving them they stay)
    readonly property bool tucked: Store.get("status.autohide", false) === true && HubState.barTucked[modelData.name] === true && !editing
    visible: barHere && minis.length > 0

    WlrLayershell.namespace: "monolith-minibars"
    WlrLayershell.layer: editing ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {
        item: win.editing ? full : null
        Region { item: !win.editing && rep.count > 0 ? rep.itemAt(0) : null }
        Region { item: !win.editing && rep.count > 1 ? rep.itemAt(1) : null }
        Region { item: !win.editing && rep.count > 2 ? rep.itemAt(2) : null }
        Region { item: !win.editing && rep.count > 3 ? rep.itemAt(3) : null }
        Region { item: !win.editing && rep.count > 4 ? rep.itemAt(4) : null }
        Region { item: !win.editing && rep.count > 5 ? rep.itemAt(5) : null }
        Region { item: !win.editing && rep.count > 6 ? rep.itemAt(6) : null }
        Region { item: !win.editing && rep.count > 7 ? rep.itemAt(7) : null }
    }
    Item { id: full; anchors.fill: parent }

    // how far from each edge: off it a little, past the frame's border, clear of the bar on its edge
    readonly property real gap: 10
    function room(e) {
        let r = gap + (Theme.barStyle === "frame" ? Theme.frameW : 0);
        if (barHere && Theme.barEdge === e) r += (e === "left" || e === "right" ? Theme.sideRoom : Theme.islandH + Theme.barMargin) + 6;
        return r;
    }
    function edgeOf(place) { return place === "left" || place === "right" ? place : (place.startsWith("bottom") ? "bottom" : "top"); }
    // several at one spot: side by side (down a side: one under the other)
    function before(idx, place) {
        let n = 0;
        for (let j = 0; j < idx; j++) { const it = rep.itemAt(j); if (it && it.place === place && !it.dragging) n += it.along + 8; }
        return n;
    }
    function group(place) {
        let n = 0, k = 0;
        for (let j = 0; j < rep.count; j++) { const it = rep.itemAt(j); if (it && it.place === place && !it.dragging) { n += it.along; k++; } }
        return n + Math.max(0, k - 1) * 8;
    }
    // the spot nearest to a point: which third of the screen it's in, each way
    function spotAt(x, y, was) {
        const c = x < width / 3 ? "left" : (x > width * 2 / 3 ? "right" : "mid");
        const r = y < height / 3 ? "top" : (y > height * 2 / 3 ? "bottom" : "mid");
        if (r === "mid") return c === "mid" ? was : c;
        return c === "mid" ? r : r + "-" + c;
    }
    function moveTo(i, place) {
        const l = JSON.parse(JSON.stringify(all));
        if (!l[i] || l[i].place === place) return;
        l[i].place = place;
        Store.set("bar.minis", l);
    }

    // ── moving them: the spots light up, the one you'd land on more ──
    Rectangle { anchors.fill: parent; visible: win.editing; color: Qt.rgba(0, 0, 0, 0.35) }
    MouseArea { anchors.fill: parent; enabled: win.editing; onClicked: HubState.miniEdit = "" }
    Item { id: keys; focus: win.editing; Keys.onEscapePressed: HubState.miniEdit = "" }
    onEditingChanged: if (editing) keys.forceActiveFocus()
    Repeater {
        model: win.editing ? win.places : []
        SmoothRect {
            required property string modelData
            readonly property bool vert: modelData === "left" || modelData === "right"
            readonly property bool hot: win.dragSpot === modelData
            smoothing: 0
            width: vert ? Theme.islandH : 180; height: vert ? 180 : Theme.islandH
            x: modelData.endsWith("left") ? win.room("left") : (modelData.endsWith("right") ? win.width - width - win.room("right") : Math.round((win.width - width) / 2))
            y: modelData.startsWith("top") ? win.room("top") : (modelData.startsWith("bottom") ? win.height - height - win.room("bottom") : Math.round((win.height - height) / 2))
            radius: Theme.barRound(Math.min(width, height))
            color: hot ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.text, 0.08)
            border.width: 2; border.color: hot ? Theme.accent : Qt.alpha(Theme.text, 0.25)
            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
        }
    }
    property string dragSpot: ""
    // (going away and coming back with the bar: the bar's own pace, no spring)
    property bool tuckMoving: false
    onTuckedChanged: { tuckMoving = true; tuckDone.restart(); }
    Timer { id: tuckDone; interval: Theme.moveMs + 100; onTriggered: win.tuckMoving = false }
    // done
    Pressable {
        visible: win.editing
        z: 60
        anchors.centerIn: parent
        width: doneRow.implicitWidth + 32; height: 44
        radius: Theme.corner(44)
        color: Theme.accent; ink: Theme.onAccent
        onClicked: HubState.miniEdit = ""
        Row {
            id: doneRow
            anchors.centerIn: parent; spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 20; color: Theme.onAccent }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Done: drag a mini bar to move it"; color: Theme.onAccent; strong: true }
        }
    }

    // ── the mini bars ──
    Repeater {
        id: rep
        model: win.minis
        SmoothRect {
            id: pill
            required property var modelData
            required property int index
            readonly property string place: modelData.place
            readonly property string edge: win.edgeOf(place)
            readonly property bool vert: place === "left" || place === "right"
            readonly property real along: vert ? height : width
            width: vert ? Theme.islandH : mbar.implicitWidth
            height: vert ? mbar.implicitHeight : Theme.islandH
            // its spot, and its place among others there
            readonly property real off: win.before(index, place)
            readonly property real homeX: vert ? (place === "left" ? win.room("left") : win.width - width - win.room("right"))
                : (place.endsWith("left") ? win.room("left") + off
                : (place.endsWith("right") ? win.width - width - win.room("right") - off
                : Math.round((win.width - win.group(place)) / 2) + off))
            readonly property real homeY: vert ? Math.round((win.height - win.group(place)) / 2) + off
                : (place.startsWith("top") ? win.room("top") : win.height - height - win.room("bottom"))
            property bool dragging: false
            property point grab: Qt.point(0, 0)
            property point at: Qt.point(0, 0)
            // (tucked: off its own edge)
            readonly property real away: win.tucked ? (vert ? width : height) + win.room(edge) + 8 : 0
            x: dragging ? at.x - grab.x : homeX + (edge === "left" ? -away : (edge === "right" ? away : 0))
            y: dragging ? at.y - grab.y : homeY + (edge === "top" ? -away : (edge === "bottom" ? away : 0))
            Behavior on x { enabled: !pill.dragging && Theme.animOn; NumberAnimation { duration: win.tuckMoving ? Theme.moveMs : Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: win.tuckMoving ? Theme.standardCurve : Theme.springyCurve } }
            Behavior on y { enabled: !pill.dragging && Theme.animOn; NumberAnimation { duration: win.tuckMoving ? Theme.moveMs : Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: win.tuckMoving ? Theme.standardCurve : Theme.springyCurve } }
            z: dragging ? 50 : 10
            scale: dragging ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fastMs } }
            // out of sight over a fullscreen window (a game, a video), like the bar
            opacity: win.overFullscreen && !win.editing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }
            radius: Theme.barRound(Math.min(width, height))
            color: Theme.barOpacity >= 0.99 ? Theme.barFill : Qt.alpha(Theme.barFill, Theme.barFill.a * Theme.barOpacity)
            border.width: win.editing ? 2 : Theme.outlineW
            border.color: win.editing ? Theme.accent : Theme.outlineColor
            CardShadow { visible: Theme.barOpacity > 0.3 }
            // hold it a moment: move them
            MouseArea {
                anchors.fill: parent
                pressAndHoldInterval: 600
                onPressAndHold: HubState.miniEdit = win.modelData.name
            }
            IslandBar {
                id: mbar
                only: pill.modelData.modules
                vertical: pill.vert
                edge: pill.edge
                screenName: win.modelData.name
                trayWindow: win
                width: implicitWidth
                height: implicitHeight
                enabled: !win.editing
            }
            // moving: grab it anywhere
            MouseArea {
                anchors.fill: parent
                visible: win.editing
                z: 20
                preventStealing: true
                cursorShape: pill.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: mouse => { pill.grab = Qt.point(mouse.x, mouse.y); pill.at = mapToItem(win.contentItem, mouse.x, mouse.y); pill.dragging = true; }
                onPositionChanged: mouse => {
                    if (!pill.dragging) return;
                    pill.at = mapToItem(win.contentItem, mouse.x, mouse.y);
                    win.dragSpot = win.spotAt(pill.at.x, pill.at.y, pill.place);
                }
                onReleased: {
                    const to = win.spotAt(pill.at.x, pill.at.y, pill.place);
                    pill.dragging = false;
                    win.dragSpot = "";
                    win.moveTo(pill.modelData.i, to);
                }
                onCanceled: { pill.dragging = false; win.dragSpot = ""; }
            }
        }
    }

    // blur behind them (Theme → Effects), shaped like them
    BackgroundEffect.blurRegion: Theme.blur && !win.editing && !win.overFullscreen ? blurShape : null
    Region {
        id: blurShape
        Region { readonly property Item it: rep.count > 0 ? rep.itemAt(0) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 1 ? rep.itemAt(1) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 2 ? rep.itemAt(2) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 3 ? rep.itemAt(3) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 4 ? rep.itemAt(4) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 5 ? rep.itemAt(5) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 6 ? rep.itemAt(6) : null; item: it; radius: it ? it.radius : 0 }
        Region { readonly property Item it: rep.count > 7 ? rep.itemAt(7) : null; item: it; radius: it ? it.radius : 0 }
    }

    // ── windows keeping clear of the ones that want it: a strip along that edge, as thick as the
    // thickest there (made anew when that changes: a strip's new size doesn't reach the compositor) ──
    readonly property var zones: {
        const z = {};
        for (const m of minis) {
            if (!m.reserve) continue;
            const e = edgeOf(m.place);
            z[e] = Math.max(z[e] || 0, Theme.islandH + gap + 4);
        }
        return Object.keys(z).map(e => e + ":" + Math.round(z[e]));
    }
    Variants {
        model: win.visible ? win.zones : []
        PanelWindow {
            required property string modelData
            readonly property string e: modelData.split(":")[0]
            screen: win.modelData
            WlrLayershell.namespace: "monolith-minibar-reserve"
            WlrLayershell.layer: WlrLayer.Bottom
            anchors { top: e !== "bottom"; bottom: e !== "top"; left: e !== "right"; right: e !== "left" }
            implicitWidth: 1; implicitHeight: 1
            exclusiveZone: Number(modelData.split(":")[1])
            color: "transparent"
            mask: Region {}
        }
    }
}
