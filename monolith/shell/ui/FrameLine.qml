import QtQuick
import "../core"

// The Frame's outline: a line along the inside edge of the frame (round the screen's inside,
// `hx, hy, hw × hh`, corners `r`), with a gap where something comes out of the frame (the quick
// access bar: its own outline carries on from the gap's ends, so the frame's line bends round it
// and doesn't run on behind it). `gap`: null, or { edge: left | right | top | bottom, a, b }
// along that edge, in this item's coordinates. Fill the window with it.
Item {
    id: fl
    property real hx: 0
    property real hy: 0
    property real hw: 0
    property real hh: 0
    property real r: 0
    property real lw: 0
    property color lineColor: "white"
    property var gap: null
    visible: lw > 0

    // the line is one rounded rectangle; with a gap it's shown through three windows onto it:
    // everything away from that edge, and the edge's strip before and after the gap
    readonly property real m: lw + 2
    readonly property var parts: {
        const all = [{ x: 0, y: 0, w: width, h: height }];
        const g = gap;
        if (!g || !(g.b > g.a)) return all;
        const X0 = hx, X1 = hx + hw, Y0 = hy, Y1 = hy + hh;
        if (g.edge === "right") return [{ x: 0, y: 0, w: X1 - m, h: height }, { x: X1 - m, y: 0, w: width - X1 + m, h: g.a }, { x: X1 - m, y: g.b, w: width - X1 + m, h: height - g.b }];
        if (g.edge === "left") return [{ x: X0 + m, y: 0, w: width - X0 - m, h: height }, { x: 0, y: 0, w: X0 + m, h: g.a }, { x: 0, y: g.b, w: X0 + m, h: height - g.b }];
        if (g.edge === "top") return [{ x: 0, y: Y0 + m, w: width, h: height - Y0 - m }, { x: 0, y: 0, w: g.a, h: Y0 + m }, { x: g.b, y: 0, w: width - g.b, h: Y0 + m }];
        if (g.edge === "bottom") return [{ x: 0, y: 0, w: width, h: Y1 - m }, { x: 0, y: Y1 - m, w: g.a, h: height - Y1 + m }, { x: g.b, y: Y1 - m, w: width - g.b, h: height - Y1 + m }];
        return all;
    }
    // (three fixed windows, moved as the gap moves: made anew from a list on every change, they
    // were destroyed and built again for every frame of a menu growing out of the bar)
    component Part: Item {
        property int n: 0
        readonly property var r: fl.parts[n] || null
        visible: !!r
        x: r ? r.x : 0; y: r ? r.y : 0
        width: r ? Math.max(0, r.w) : 0; height: r ? Math.max(0, r.h) : 0
        clip: true
        Rectangle {
            x: fl.hx - fl.lw / 2 - parent.x; y: fl.hy - fl.lw / 2 - parent.y
            width: fl.hw + fl.lw; height: fl.hh + fl.lw
            radius: Theme.rnd(fl.r + fl.lw / 2)
            color: "transparent"
            border.width: fl.lw
            border.color: fl.lineColor
        }
    }
    Part { n: 0 }
    Part { n: 1 }
    Part { n: 2 }
}
