import QtQuick
import Quickshell

// A blur region cut exactly like an IslandShape: a body (x, y, w × h, in the window) against
// one screen edge, square where it meets the edge and rounded (r) on the inner corners, with
// the concave ears (e) that join it to the edge on both sides. Used so the blur behind the
// bar, its menus and the quick-access panel never shows as a square patch around the drawn
// shape (a square blur showed lighter in the corners of a rounded bar).
Region {
    id: g
    property bool on: true
    property string edge: "top"           // top, bottom, left, right: the edge it hangs from
    property real bx: 0
    property real by: 0
    property real bw: 0
    property real bh: 0
    property real r: 0
    property real e: 0
    readonly property bool vert: edge === "left" || edge === "right"
    readonly property int ee: on ? Math.round(Math.max(0, e)) : 0
    readonly property int rr: Math.round(Math.max(0, r))

    x: Math.round(bx); y: Math.round(by)
    width: on ? Math.round(bw) : 0
    height: on ? Math.round(bh) : 0
    topLeftRadius: edge === "top" || edge === "left" ? 0 : rr
    topRightRadius: edge === "top" || edge === "right" ? 0 : rr
    bottomLeftRadius: edge === "bottom" || edge === "left" ? 0 : rr
    bottomRightRadius: edge === "bottom" || edge === "right" ? 0 : rr

    // the ears: an e × e square at the edge beside the body, less the circle that makes its
    // curve (centred on the square's corner away from the edge and the body)
    component Ear: Region {
        id: ear
        property real cx: 0
        property real cy: 0
        width: g.ee; height: g.ee
        Region {
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
            x: Math.round(ear.cx - g.ee); y: Math.round(ear.cy - g.ee)
            width: 2 * g.ee; height: 2 * g.ee
        }
    }
    // before the body (left of it, or above a side one)
    Ear {
        x: g.vert ? (g.edge === "left" ? g.x : g.x + g.width - g.ee) : g.x - g.ee
        y: g.vert ? g.y - g.ee : (g.edge === "top" ? g.y : g.y + g.height - g.ee)
        cx: g.vert ? (g.edge === "left" ? g.x + g.ee : g.x + g.width - g.ee) : g.x - g.ee
        cy: g.vert ? g.y - g.ee : (g.edge === "top" ? g.y + g.ee : g.y + g.height - g.ee)
    }
    // after it (right of it, or below)
    Ear {
        x: g.vert ? (g.edge === "left" ? g.x : g.x + g.width - g.ee) : g.x + g.width
        y: g.vert ? g.y + g.height : (g.edge === "top" ? g.y : g.y + g.height - g.ee)
        cx: g.vert ? (g.edge === "left" ? g.x + g.ee : g.x + g.width - g.ee) : g.x + g.width + g.ee
        cy: g.vert ? g.y + g.height + g.ee : (g.edge === "top" ? g.y + g.ee : g.y + g.height - g.ee)
    }
}
