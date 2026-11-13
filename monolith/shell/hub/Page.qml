import QtQuick
import "../core"

// A hub page: shows while it's the current one, fading in as the card morphs to its size.
// Pages are built when first opened (Island.qml) and then kept for a while, so they open at
// once next time: `current` is true while it's the page showing in an open hub (it turns true
// just after creation, and again on every opening), so pages refresh their data in
// onCurrentChanged.
FocusScope {
    property string pageId: ""
    property bool ready: false
    Component.onCompleted: ready = true
    readonly property bool current: ready && HubState.open && HubState.page === pageId
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    height: implicitHeight
    visible: opacity > 0.01
    opacity: current ? 1 : 0
    // fades in with a little zoom, and out the same way (like everything that appears)
    scale: current ? 1 : Theme.popScale
    transformOrigin: Item.Top
    // (skipped when a different menu opens over this one's closing: see HubState.snap)
    // (switching from another open menu: this one waits a moment for the old one to go, and the
    // old one goes quicker)
    Behavior on opacity {
        enabled: !HubState.snap
        SequentialAnimation {
            PauseAnimation { duration: current && HubState.switching ? Theme.ms(90) : 0 }
            NumberAnimation { duration: current ? Theme.popInMs : (HubState.switching ? Theme.ms(110) : Theme.popOutMs); easing.type: Easing.OutCubic }
        }
    }
    // view transition: one open menu turning into another slides along the menus' order (the new
    // one in from the side it sits on, the old one out the other way) as they cross-fade.
    // Interruptible: switching back mid-way carries on from where it is.
    id: pg
    property real shift: 0
    transform: Translate { x: pg.shift }
    readonly property real travel: Math.min(36, width * 0.06)
    onCurrentChanged: {
        slide.stop();
        if (!HubState.switching || HubState.snap || !Theme.animOn) { shift = 0; return; }
        // (coming in from fully gone: from its side; caught mid-way out: from where it is)
        if (current && opacity < 0.05) shift = HubState.dir * travel;
        slide.to = current ? 0 : -HubState.dir * travel;
        slide.duration = current ? Theme.popInMs : Theme.ms(160);
        slide.easing.bezierCurve = current ? Theme.enterCurve : Theme.exitCurve;
        slide.start();
    }
    NumberAnimation { id: slide; target: pg; property: "shift"; to: 0; easing.type: Easing.BezierSpline }
    Behavior on scale { enabled: !HubState.snap; NumberAnimation { duration: current ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: current ? Theme.enterCurve : Theme.exitCurve } }
}
