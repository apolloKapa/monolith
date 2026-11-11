import QtQuick
import "../../core"
import "../../ui"

// CPU, memory, temperature, disk or battery, Dot: a ring of dots that light up with the value
// (the last lit one red), the number in dots in the middle and its name under it.
FaceBase {
    id: f
    readonly property string kind: f.ctx ? f.ctx.type : "cpu"
    Metric { id: m; type: f.kind === "battery" ? "cpu" : f.kind }
    Battery { id: bat }
    readonly property real value: f.kind === "battery" ? bat.level : m.value
    readonly property string number: f.kind === "temp" ? String(Math.round(Stats.temp)) + "°" : String(Math.round(value * 100))
    readonly property string name: f.kind === "battery" ? (bat.charging ? "CHARGING" : "BATTERY") : ({ cpu: "CPU", ram: "RAM", temp: "TEMP", disk: "DISK" })[f.kind] || ""
    DotCard { id: card; ctx: f.ctx }

    readonly property real side: Math.min(width, height)
    readonly property int count: 32
    readonly property int lit: Math.round(value * count)
    Repeater {
        model: f.count
        Rectangle {
            required property int index
            // from the top, clockwise
            readonly property real a: -Math.PI / 2 + index / f.count * 2 * Math.PI
            readonly property real rr: f.side * 0.39
            width: f.side * 0.045; height: width; radius: width / 2
            x: f.width / 2 + Math.cos(a) * rr - width / 2
            y: f.height / 2 + Math.sin(a) * rr - height / 2
            color: index < f.lit ? (index === f.lit - 1 ? card.accent : card.ink) : card.off
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
    DotText {
        id: num
        text: f.number
        color: card.ink
        cell: fitCell(f.side * 0.52, f.side * 0.3)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -f.side * 0.04
    }
    Text {
        text: f.name
        color: card.dim
        font.family: Theme.fontFamily; font.pixelSize: Math.max(9, f.side * 0.07); font.weight: Font.DemiBold; font.letterSpacing: 1.5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: num.bottom; anchors.topMargin: f.side * 0.04
    }
}
