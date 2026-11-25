import QtQuick
import "../core"

// Smooth wheel scrolling for a Flickable / ListView / GridView: put it inside one.
// A mouse wheel moves a fixed distance per notch and glides there; a touchpad moves exactly
// with your fingers. (Qt's own wheel scrolling flicks, which feels slow and floaty.)
WheelHandler {
    id: sw
    // the list it scrolls: inside a Flickable a handler ends up on its content item, so this
    // walks up to the first item that actually scrolls. (Or name one: the wheel over something
    // beside a list scrolls that list, `SmoothWheel { flick: theList }`)
    property var flick: {
        let p = parent;
        while (p && (p.contentY === undefined || p.flickableDirection === undefined)) p = p.parent;
        return p;
    }
    // pixels per wheel notch: 110 × Menu scroll speed (Settings → Devices → Keyboard & mouse)
    property real step: 110 * Math.max(0.1, Math.min(5, Number(Store.get("menus.scrollSpeed", 1)) || 1))
    property bool horizontal: false
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    // A list with nothing to scroll lets the wheel through to what's behind it (a list inside a
    // page scrolls the page; the wheel over the launcher's favourites scrolls the apps). A
    // handler keeps the wheel to itself by default, whatever it does with it.
    blocking: {
        const f = flick;
        if (!f) return false;
        const lim = limits();
        return lim[1] > lim[0];
    }
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
        // A mouse wheel's notch is a whole number of 120ths (one notch: 120). Qt 6.12 on Hyprland
        // sends a pixel distance with it too (15, and the device says "touchpad"), and taking that
        // for a touchpad moved the list 15 px a notch: menus crawled. Only a touchpad's own
        // movement (no whole notch) follows the fingers exactly.
        const ad = horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y;
        const notch = ad !== 0 && ad % 120 === 0;
        if (!notch && (event.pixelDelta.y !== 0 || event.pixelDelta.x !== 0)) {
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
    // The glide to the new place is short and always the same length. It's how quickly a list
    // answers the wheel, not a decoration, so it doesn't follow the theme's animation speed: at
    // the default speed it took 200 ms a notch and the menus felt slow next to any app, and
    // only a desktop with its animations sped up scrolled briskly. Animations off: no glide.
    property int glideMs: 70
    property NumberAnimation anim: NumberAnimation {
        target: sw.flick
        duration: Theme.animOn ? sw.glideMs : 1
        easing.type: Easing.OutCubic
    }
}
