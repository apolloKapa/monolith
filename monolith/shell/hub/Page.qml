import QtQuick
import "../core"
import "../ui"

// A hub page: shows while it's the current one, fading in as the card morphs to its size.
// Pages are built when first opened (Island.qml) and then kept, so they open at once next
// time: `current` is true while it's the page showing in an open hub (it turns true
// just after creation, and again on every opening), so pages refresh their data in
// onCurrentChanged.
//
// How it comes and goes (one interruptible animation, always from wherever it is now):
// - the hub opening or closing: a fade with a little zoom, like everything that appears
// - one open menu turning into another (a shared-axis move): the old page slides a little the
//   other way and fades out quickly; the new one comes in just after from the side it sits on
//   in the menus' order and glides into place (no zoom: the card's own change of size is the
//   motion), so the two never sit on top of each other as the card morphs
// - a different menu opened over this one's closing (HubState.snap) or animations off: at once
FocusScope {
    id: pg
    property string pageId: ""
    property bool ready: false
    Component.onCompleted: ready = true
    readonly property bool current: ready && HubState.open && HubState.page === pageId
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    height: implicitHeight
    visible: opacity > 0.01
    opacity: 0
    scale: Theme.popScale
    transformOrigin: Item.Top
    property real shift: 0
    property real lift: 0
    property real tilt: 0
    transform: [
        Translate { x: pg.shift; y: pg.lift },
        Rotation { origin.x: pg.width / 2; origin.y: 0; angle: pg.tilt }
    ]
    readonly property real travel: Math.min(48, width * 0.07)

    onCurrentChanged: move()
    // Cyberpunk: switching menus, the old page is taken by the Blackwall and the new one glitches
    // in (CyberFx); opening or closing the menu, the page stays whole and the card's own glitch
    // or Blackwall takes it along (Island.qml)
    property real cyP: 1
    property bool cyGoing: false
    CyberFx { target: pg; content: true; p: pg.cyP; going: pg.cyGoing }
    SequentialAnimation {
        id: cyIn
        PropertyAction { target: pg; property: "cyGoing"; value: false }
        PropertyAction { target: pg; property: "cyP"; value: 0 }
        PropertyAction { target: pg; property: "opacity"; value: 1 }
        NumberAnimation { target: pg; property: "cyP"; from: 0; to: 1; duration: Theme.fxInMs }
    }
    SequentialAnimation {
        id: cyOut
        PropertyAction { target: pg; property: "cyGoing"; value: true }
        NumberAnimation { target: pg; property: "cyP"; from: 0; to: 1; duration: Math.round(Theme.fxOutMs * 0.6) }
        PropertyAction { target: pg; property: "opacity"; value: 0 }
        PropertyAction { target: pg; property: "cyGoing"; value: false }
    }
    SequentialAnimation {
        id: cyHold
        PauseAnimation { duration: Theme.fxOutMs }
        PropertyAction { target: pg; property: "opacity"; value: 0 }
    }
    // ── one open menu turning into another: each style its own way, by moving and fading only (no
    // shader, nothing drawn off screen). The style's own effect used to run here on the whole page,
    // while the card around it was changing size: half a second of a heavy effect on a page whose
    // size moved under it, which was what made switching look broken. The old page goes quickly,
    // the new one comes just after, so the two never sit on top of each other ──
    // [in ms, out ms, wait before in, in-from {x (× the way it moves), y, rot (× the way), sc},
    //  out-to {x, y, rot, sc}, in easing, out easing, flicker]
    readonly property var switchLooks: ({
        pop:        [300, 120, 70, { x: 24 }, { x: -12 }, Easing.OutCubic, Easing.OutCubic, false],
        liquid:     [360, 140, 60, { sc: 0.965 }, { sc: 1.02 }, Easing.OutCubic, Easing.OutCubic, false],
        cyber:      [220, 110, 40, { x: 10 }, { x: -8 }, Easing.OutQuad, Easing.InQuad, true],
        doodle:     [340, 120, 60, { y: 12, rot: -1.6 }, { y: -6, rot: 1 }, Easing.OutBack, Easing.InQuad, false],
        terminal:   [200, 60, 30, { y: 4 }, {}, Easing.OutQuad, Easing.Linear, true],
        paper:      [380, 180, 40, { x: 60 }, { x: -40 }, Easing.OutQuart, Easing.InQuad, false],
        fjord:      [420, 200, 80, { sc: 1.025 }, {}, Easing.OutSine, Easing.OutSine, false],
        concrete:   [400, 140, 60, { y: -20 }, { y: 14 }, Easing.OutBounce, Easing.InQuad, false],
        industrial: [320, 130, 50, { y: -26 }, { y: -14 }, Easing.OutBack, Easing.InQuad, false],
        luxe:       [460, 220, 90, { y: 10 }, {}, Easing.OutQuint, Easing.OutCubic, false]
    })
    function switchMove() {
        const look = switchLooks[Theme.fxKind] || switchLooks.pop;
        const d = HubState.dir;
        cyGoing = false; cyP = 1;
        if (current) {
            const f = look[3];
            // (caught on its way out: from where it is)
            if (opacity < 0.05) { shift = (f.x || 0) * d; lift = f.y || 0; tilt = (f.rot || 0) * d; scale = f.sc || 1; opacity = 0; }
            swWait.duration = Theme.ms(look[2]);
            for (const a of [swX, swY, swR, swS]) { a.duration = Theme.ms(look[0]); a.easing.type = look[5]; }
            swX.to = 0; swY.to = 0; swR.to = 0; swS.to = 1;
            swOp.to = 1; swOp.duration = Theme.ms(Math.round(look[0] * 0.7));
            (look[7] ? swFlickIn : swFade).start();
            swMotion.start();
        } else {
            const t = look[4];
            for (const a of [swX, swY, swR, swS]) { a.duration = Theme.ms(look[1]); a.easing.type = look[6]; }
            swX.to = shift + (t.x || 0) * d; swY.to = lift + (t.y || 0); swR.to = (t.rot || 0) * d; swS.to = t.sc || scale;
            swWait.duration = 0;
            swOp.to = 0; swOp.duration = Theme.ms(look[1]);
            (look[7] ? swFlickOut : swFade).start();
            swMotion.start();
        }
    }
    ParallelAnimation {
        id: swMotion
        NumberAnimation { id: swX; target: pg; property: "shift" }
        NumberAnimation { id: swY; target: pg; property: "lift" }
        NumberAnimation { id: swR; target: pg; property: "tilt" }
        NumberAnimation { id: swS; target: pg; property: "scale" }
    }
    SequentialAnimation {
        id: swFade
        PauseAnimation { id: swWait }
        NumberAnimation { id: swOp; target: pg; property: "opacity"; easing.type: Easing.OutCubic }
    }
    // (Cyberpunk and Terminal: a flicker, steps of the signal coming and going, not a fade)
    SequentialAnimation {
        id: swFlickIn
        PauseAnimation { duration: swWait.duration }
        PropertyAction { target: pg; property: "opacity"; value: 0.7 }
        PauseAnimation { duration: Theme.ms(40) }
        PropertyAction { target: pg; property: "opacity"; value: 0.1 }
        PauseAnimation { duration: Theme.ms(40) }
        PropertyAction { target: pg; property: "opacity"; value: 0.9 }
        PauseAnimation { duration: Theme.ms(50) }
        PropertyAction { target: pg; property: "opacity"; value: 0.4 }
        PauseAnimation { duration: Theme.ms(30) }
        PropertyAction { target: pg; property: "opacity"; value: 1 }
    }
    SequentialAnimation {
        id: swFlickOut
        PropertyAction { target: pg; property: "opacity"; value: 0.3 }
        PauseAnimation { duration: Theme.ms(35) }
        PropertyAction { target: pg; property: "opacity"; value: 0.8 }
        PauseAnimation { duration: Theme.ms(30) }
        PropertyAction { target: pg; property: "opacity"; value: 0 }
    }
    function stopSwitch() { swMotion.stop(); swFade.stop(); swFlickIn.stop(); swFlickOut.stop(); }

    function move() {
        inAnim.stop(); outAnim.stop(); cyIn.stop(); cyOut.stop(); cyHold.stop(); stopSwitch();
        // switching between open menus: its own transition, whatever the style (above)
        if (HubState.switching && HubState.open && !HubState.snap && Theme.animOn) { switchMove(); return; }
        // anything else (opening, closing): back to rest first
        lift = 0; tilt = 0;
        if (Theme.cyber && !HubState.snap) {
            scale = 1; shift = 0;
            const swc = HubState.switching && HubState.open;
            if (current) {
                if (swc) cyIn.start();
                else { cyGoing = false; cyP = 1; opacity = 1; }
            } else {
                if (swc) cyOut.start();
                else { cyGoing = false; cyP = 1; cyHold.start(); }   // the card's Blackwall takes it
            }
            return;
        }
        if (HubState.snap || !Theme.animOn) {
            opacity = current ? 1 : 0; scale = current ? 1 : Theme.popScale; shift = 0;
            return;
        }
        const sw = HubState.switching && HubState.open;
        if (current) {
            // from fully gone: from its side (switching) or a little zoomed out (opening);
            // caught on its way out: from where it is
            if (opacity < 0.05) { shift = sw ? HubState.dir * travel : 0; scale = sw ? 1 : Theme.popScale; }
            inWait.duration = sw ? Theme.ms(70) : 0;
            inFade.duration = sw ? Theme.ms(300) : Theme.popInMs;
            inZoom.duration = Theme.popInMs;
            inSlide.duration = sw ? Theme.ms(460) : Theme.popInMs;
            inAnim.start();
        } else {
            // switching to another menu: out to the side, quickly. The menu closing: it holds
            // still and goes with its card (the card fades and moves away whole, Theme.menuAnim);
            // it used to fade out on its own in a blink, before the card had moved at all
            const closing = !sw && !HubState.open;
            outWait.duration = closing ? Theme.menuOutMs : 0;
            outFade.duration = sw ? Theme.ms(130) : (closing ? 0 : Theme.popOutMs);
            outZoom.to = sw || closing ? scale : Theme.popScale;
            outZoom.duration = Theme.popOutMs;
            outSlide.to = sw ? -HubState.dir * travel * 0.5 : shift;
            outSlide.duration = sw ? Theme.ms(200) : Theme.popOutMs;
            outAnim.start();
        }
    }
    ParallelAnimation {
        id: inAnim
        SequentialAnimation {
            PauseAnimation { id: inWait }
            NumberAnimation { id: inFade; target: pg; property: "opacity"; to: 1; easing.type: Easing.OutCubic }
        }
        NumberAnimation { id: inZoom; target: pg; property: "scale"; to: 1; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
        NumberAnimation { id: inSlide; target: pg; property: "shift"; to: 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
    }
    ParallelAnimation {
        id: outAnim
        SequentialAnimation {
            PauseAnimation { id: outWait }
            NumberAnimation { id: outFade; target: pg; property: "opacity"; to: 0; easing.type: Easing.OutCubic }
        }
        NumberAnimation { id: outZoom; target: pg; property: "scale"; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
        NumberAnimation { id: outSlide; target: pg; property: "shift"; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
    }
}
