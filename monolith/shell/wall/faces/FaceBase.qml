import QtQuick

// The root of every look: fills the widget and reaches its WidgetFace as `ctx`.
Item {
    anchors.fill: parent
    readonly property var ctx: parent && parent.ctx !== undefined ? parent.ctx : null
    readonly property bool live: ctx ? ctx.live : false
    readonly property var clock: ctx ? ctx.clock : null
    readonly property date now: clock ? clock.date : new Date()
    readonly property var player: ctx ? ctx.player : null
    function opt(k, d) { return ctx ? ctx.opt(k, d) : d; }
}
