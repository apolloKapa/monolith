import QtQuick
import "../core"

// A hub page: shows while it's the current one, fading in as the card morphs to its size.
// Pages are built when first opened (Hub.qml), so `current` turns true just after creation:
// pages refresh their data in onCurrentChanged and that runs on the first opening too.
FocusScope {
    property string pageId: ""
    property bool ready: false
    Component.onCompleted: ready = true
    readonly property bool current: ready && HubState.page === pageId
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
