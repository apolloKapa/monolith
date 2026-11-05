import QtQuick
import "../core"

// Smooth wheel scrolling for a Flickable / ListView / GridView: put it inside one.
// A mouse wheel moves a fixed distance per notch and glides there; a touchpad moves exactly
// with your fingers. (Qt's own wheel scrolling flicks, which feels slow and floaty.)
WheelHandler {
    id: sw
    // the list it scrolls: inside a Flickable a handler ends up on its content item, so this
    // walks up to the first item that actually scrolls
    readonly property var flick: {
        let p = parent;
        while (p && (p.contentY === undefined || p.flickableDirection === undefined)) p = p.parent;
        return p;
    }
    property real step: 110                 // pixels per wheel notch
    property bool horizontal: false
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    property real target: 0

    function limits() {
        const f = flick;
        return horizontal ? [f.originX, Math.max(f.originX, f.originX + f.contentWidth - f.width)]
                          : [f.originY, Math.max(f.originY, f.originY + f.contentHeight - f.height)];
    }
    onWheel: event => {
        const f = flick;
        if (!f) { event.accepted = false; return; }
        const [lo, hi] = limits();
        if (!(hi > lo)) { event.accepted = false; return; }
        const pos = horizontal ? f.contentX : f.contentY;
        let next;
        if (event.pixelDelta.y !== 0 || event.pixelDelta.x !== 0) {
            // a touchpad: follow it exactly
            anim.stop();
            next = pos - (horizontal ? (event.pixelDelta.x || event.pixelDelta.y) : event.pixelDelta.y);
            next = Math.max(lo, Math.min(hi, next));
            if (horizontal) f.contentX = next; else f.contentY = next;
            target = next;
        } else {
            const d = horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y;
            const base = anim.running ? target : pos;
            next = Math.max(lo, Math.min(hi, base - d / 120 * step));
            target = next;
            anim.property = horizontal ? "contentX" : "contentY";
            anim.to = next;
            anim.restart();
        }
        event.accepted = true;
    }
    property NumberAnimation anim: NumberAnimation {
        target: sw.flick
        duration: Math.max(1, 200 * Theme.animScale)
        easing.type: Easing.OutCubic
    }
}
