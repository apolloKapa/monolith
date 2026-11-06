import QtQuick
import "../../core"

// Text that scrolls sideways (with a gap, round and round) when it's wider than its room.
Item {
    id: mq
    property alias text: a.text
    property alias font: a.font
    property alias color: a.color
    property bool active: true
    property real gap: 30
    readonly property bool over: a.implicitWidth > width
    implicitHeight: a.implicitHeight
    clip: true
    property real off: 0
    NumberAnimation on off {
        id: run
        from: 0; to: a.implicitWidth + mq.gap
        duration: Math.max(1, (a.implicitWidth + mq.gap) * 28)
        loops: Animation.Infinite
        running: mq.active && mq.over && mq.visible
        onRunningChanged: if (!running) mq.off = 0
    }
    Text { id: a; x: mq.over ? -mq.off : 0; elide: mq.over ? Text.ElideNone : Text.ElideRight; width: mq.over ? implicitWidth : mq.width }
    Text { visible: mq.over; x: a.x + a.implicitWidth + mq.gap; text: a.text; font: a.font; color: a.color }
}
