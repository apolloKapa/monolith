import QtQuick
import "../core"

// A hub page: shows while it's the current one, fading in as the card morphs to its size.
// Pages are built when first opened (Island.qml) and then kept for a while, so they open at
// once next time: `current` is true while it's the page showing in an open hub (it turns true
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
    transform: Translate { x: pg.shift }
    readonly property real travel: Math.min(48, width * 0.07)

    onCurrentChanged: move()
    function move() {
        inAnim.stop(); outAnim.stop();
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
            outFade.duration = sw ? Theme.ms(130) : Theme.popOutMs;
            outZoom.to = sw ? scale : Theme.popScale;
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
        NumberAnimation { id: outFade; target: pg; property: "opacity"; to: 0; easing.type: Easing.OutCubic }
        NumberAnimation { id: outZoom; target: pg; property: "scale"; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
        NumberAnimation { id: outSlide; target: pg; property: "shift"; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
    }
}
