import QtQuick
import "../../core"

// Cyberpunk: a value (0 … 1) as a row of segments lighting up, the last lit one hot.
Row {
    id: cb
    property var card: null
    property real value: 0
    property int count: 20
    property color on: card ? card.edge : "#00f0ff"
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)
    spacing: Math.max(1, height * 0.25)
    Repeater {
        model: cb.count
        Rectangle {
            required property int index
            width: Math.max(1, (cb.width - cb.spacing * (cb.count - 1)) / cb.count)
            height: cb.height
            color: index < cb.lit ? (index === cb.lit - 1 ? (cb.card ? cb.card.hot : "#ff2a6d") : cb.on) : Qt.alpha(cb.on, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.ms(240) } }
        }
    }
}
