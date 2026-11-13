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
    Behavior on opacity { NumberAnimation { duration: current ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: current ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: current ? Theme.enterCurve : Theme.exitCurve } }
}
