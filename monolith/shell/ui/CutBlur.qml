import QtQuick
import Quickshell
import "../core"

// The Cyberpunk style's cut corner, taken out of a blur region: put it inside the Region of a
// cut panel (Theme.chamfer) and give it that panel's rectangle (bx, by, bw, bh, in the window)
// and how big the cut is (c). Regions can only be rectangles with round corners, so the
// triangle outside the cut is taken away as a staircase of thin strips (2 px or so each): the
// blur showed past the cut corner as a lighter wedge. Off (or no cut), it takes nothing away.
Region {
    id: cut
    property bool on: Theme.chamfer
    property real bx: 0
    property real by: 0
    property real bw: 0
    property real bh: 0
    property real c: 0
    readonly property real cc: on ? Math.max(0, Math.min(c, bw, bh)) : 0
    readonly property int n: 8
    readonly property real step: cc / n
    intersection: Intersection.Subtract

    // strip i of n, from the top of the corner down: everything right of where the cut runs
    // through its middle
    component Strip: Region {
        property int i: 0
        readonly property real t: (i + 0.5) * cut.step
        x: Math.round(cut.bx + cut.bw - t)
        y: Math.round(cut.by + cut.bh - cut.cc + i * cut.step)
        width: cut.cc > 0 ? Math.ceil(t) + 1 : 0
        height: cut.cc > 0 ? Math.ceil(cut.step) : 0
    }
    // (the first strip is this region itself; the rest are added to it)
    readonly property real t0: 0.5 * step
    x: Math.round(bx + bw - t0)
    y: Math.round(by + bh - cc)
    width: cc > 0 ? Math.ceil(t0) + 1 : 0
    height: cc > 0 ? Math.ceil(step) : 0
    Strip { i: 1 } Strip { i: 2 } Strip { i: 3 } Strip { i: 4 } Strip { i: 5 } Strip { i: 6 } Strip { i: 7 }
}
