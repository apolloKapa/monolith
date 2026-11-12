import QtQuick
import "../../core"
import "../../ui"

// Wellbeing, Dot: today's screen time in dots (h:mm), a row of dots filling towards the daily
// goal (the last lit one red; all red past it) and SCREEN TIME under it.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: 0 }
    DotCard { id: card; ctx: f.ctx }
    readonly property real full: wd.fullAt(String(f.opt("fullAt", "goal")))
    readonly property int count: 16
    readonly property int lit: Math.min(count, Math.round(wd.total / Math.max(1, full) * count))
    readonly property bool over: wd.total > full
    DotText {
        id: num
        text: wd.clockText(wd.total)
        color: card.ink
        cell: fitCell(f.width * 0.74, f.height * 0.36)
        anchors.horizontalCenter: parent.horizontalCenter
        y: f.height * 0.16
    }
    Row {
        id: meter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: num.bottom; anchors.topMargin: f.height * 0.09
        spacing: f.width * 0.74 / f.count * 0.35
        Repeater {
            model: f.count
            Rectangle {
                required property int index
                width: f.width * 0.74 / f.count * 0.65; height: width; radius: width / 2
                color: index < f.lit ? (f.over || index === f.lit - 1 ? card.accent : card.ink) : card.off
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }
    Text {
        text: "SCREEN TIME"
        color: card.dim
        font.family: Theme.fontFamily; font.pixelSize: Math.max(9, f.height * 0.075); font.weight: Font.DemiBold; font.letterSpacing: 1.5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: meter.bottom; anchors.topMargin: f.height * 0.07
    }
    WellOpen { face: f }
}
