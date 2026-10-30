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
    property int duration: 180

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
        // a touchpad (or a free-spinning wheel sending pixels): follow the fingers exactly
        const px = horizontal ? (event.pixelDelta.y || event.pixelDelta.x) : event.pixelDelta.y;
        if (px !== 0) {
            root.glide.stop();
            const to = Math.max(lo, Math.min(hi, position() - px));
            if (horizontal) f.contentX = to; else f.contentY = to;
            return;
        }
        const notches = event.angleDelta.y / 120;
        if (notches === 0) return;
        f.cancelFlick();
        // keep adding to where the last glide was heading, so fast spins don't lose distance
        const from = root.glide.running ? goal : position();
        goal = Math.max(lo, Math.min(hi, from - notches * step));
        root.glide.property = horizontal ? "contentX" : "contentY";
        root.glide.to = goal;
        root.glide.restart();
    }

    // (a handler takes no child objects, so these hang off properties)
    readonly property NumberAnimation glide: NumberAnimation {
        target: root.flickable
        duration: root.duration
        easing.type: Easing.OutCubic
    }

    // dragging or flicking the view by hand takes over from a glide in progress
    property Connections _takeOver: Connections {
        target: root.flickable
        ignoreUnknownSignals: true
        function onMovementStarted() { root.glide.stop(); }
    }
}
