import QtQuick

// Smooth mouse-wheel scrolling for a Flickable, ListView or GridView: put `WheelScroll {}` inside
// one. Qt turns each wheel notch into a little flick that has to coast to a stop, which made
// every list in the shell scroll slowly, lag behind the wheel and stutter at the ends. Here a
// notch moves a fixed distance with a short glide, quick notches add up instead of restarting,
// and a touchpad moves the content 1:1.
WheelHandler {
    id: root

    // the view to scroll: found by walking up from where this is declared (inside a Flickable
    // it lands in its contentItem)
    property Item flickable: null
    // pixels per wheel notch
    property real step: 120
    // how fast the view catches up with where the wheel sent it (per second): ~90% in 150 ms
    property real catchUp: 15

    readonly property bool horizontal: {
        const f = flickable;
        if (!f) return false;
        if (f.orientation !== undefined) return f.orientation === ListView.Horizontal;
        if (f.flow !== undefined) return f.flow === GridView.FlowTopToBottom;
        if (f.flickableDirection === Flickable.AutoFlickDirection)
            return f.contentHeight <= f.height && f.contentWidth > f.width;
        return f.flickableDirection === Flickable.HorizontalFlick;
    }

    // the ordinary wheel scrolls sideways lists too (most mice have no sideways wheel), like Qt's own
    orientation: Qt.Vertical
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    // off when there's nothing to scroll, so a short list inside a long page lets the page scroll
    readonly property bool scrollable: flickable !== null && (horizontal
        ? flickable.contentWidth + flickable.leftMargin + flickable.rightMargin > flickable.width + 1
        : flickable.contentHeight + flickable.topMargin + flickable.bottomMargin > flickable.height + 1)
    enabled: scrollable && flickable.interactive !== false && flickable.visible
    target: null

    Component.onCompleted: {
        if (flickable) return;
        let p = parent;
        while (p && p.contentY === undefined) p = p.parent;
        flickable = p;
    }

    property real goal: 0

    function lowest() {
        const f = flickable;
        return horizontal ? f.originX - f.leftMargin : f.originY - f.topMargin;
    }
    function highest() {
        const f = flickable;
        return horizontal
            ? f.originX + f.contentWidth + f.rightMargin - f.width
            : f.originY + f.contentHeight + f.bottomMargin - f.height;
    }
    function position() { return horizontal ? flickable.contentX : flickable.contentY; }

    onWheel: (event) => {
        const f = flickable;
        const lo = lowest(), hi = Math.max(lo, highest());
        if (hi - lo < 1) return;
        // a touchpad: follow the fingers exactly. On Wayland Qt hands a mouse wheel over with
        // pixelDelta too (15 px a notch) and even calls the mouse a touchpad, so only a gesture
        // with a scroll phase counts as fingers; wheel notches never have one
        const px = horizontal ? (event.pixelDelta.y || event.pixelDelta.x) : event.pixelDelta.y;
        if (px !== 0 && event.phase !== Qt.NoScrollPhase) {
            root.gliding = false;
            const to = Math.max(lo, Math.min(hi, position() - px));
            if (horizontal) f.contentX = to; else f.contentY = to;
            return;
        }
        const notches = event.angleDelta.y / 120;
        if (notches === 0) return;
        // already at the end it's heading for: the view around this one scrolls instead
        const at = root.gliding ? goal : position();
        if ((notches > 0 && at <= lo + 0.5) || (notches < 0 && at >= hi - 0.5)) {
            const outer = root.outerScroller();
            if (outer) outer.scrollNotches(notches);
            return;
        }
        scrollNotches(notches);
    }

    readonly property bool isWheelScroll: true

    function scrollNotches(notches) {
        const f = flickable;
        if (!f) return false;
        const lo = lowest(), hi = Math.max(lo, highest());
        const at = gliding ? goal : position();
        if ((notches > 0 && at <= lo + 0.5) || (notches < 0 && at >= hi - 0.5)) {
            const outer = outerScroller();
            return outer ? outer.scrollNotches(notches) : false;
        }
        f.cancelFlick();
        // keep adding to where the glide is heading, so fast spins don't lose distance
        goal = Math.max(lo, Math.min(hi, at - notches * step));
        gliding = true;
        return true;
    }

    // the WheelScroll of the nearest scrolling view around ours (a wheel handler that turns an
    // event down doesn't hand it to the one outside, so it's passed on by hand)
    function outerScroller() {
        for (let p = flickable ? flickable.parent : null; p; p = p.parent) {
            if (p.contentY === undefined || p.flickableDirection === undefined) continue;
            const lists = [p.data, p.contentItem ? p.contentItem.data : null];
            for (const l of lists) {
                if (!l) continue;
                for (let k = 0; k < l.length; k++) {
                    const h = l[k];
                    if (h && h !== root && h.isWheelScroll === true && h.flickable === p) return h;
                }
            }
        }
        return null;
    }

    // The glide: every frame the view covers a fixed share of what's left to the goal. Unlike an
    // animation restarted on every notch it never starts over, so quick notches just move the goal
    // and the motion stays smooth whatever the frame rate.
    property bool gliding: false
    // (a handler takes no child objects, so these hang off properties)
    readonly property FrameAnimation glide: FrameAnimation {
        running: root.gliding && root.flickable !== null
        onTriggered: {
            const f = root.flickable;
            const lo = root.lowest(), hi = Math.max(lo, root.highest());
            root.goal = Math.max(lo, Math.min(hi, root.goal));
            const pos = root.position();
            const left = root.goal - pos;
            let to;
            if (Math.abs(left) < 0.5) {
                to = root.goal;
                root.gliding = false;
            } else {
                to = pos + left * (1 - Math.exp(-root.catchUp * Math.min(0.05, frameTime)));
            }
            if (root.horizontal) f.contentX = to; else f.contentY = to;
        }
    }

    // dragging or flicking the view by hand takes over from a glide in progress
    property Connections _takeOver: Connections {
        target: root.flickable
        ignoreUnknownSignals: true
        function onMovementStarted() { root.gliding = false; }
    }
}
