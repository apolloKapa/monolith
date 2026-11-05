import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// A unit converter: length, weight, temperature, data, time.
ColumnLayout {
    id: cv
    spacing: 8
    readonly property var units: ({
        "Length": [["m", 1], ["km", 1000], ["cm", 0.01], ["mm", 0.001], ["mi", 1609.344], ["ft", 0.3048], ["in", 0.0254], ["yd", 0.9144]],
        "Weight": [["kg", 1], ["g", 0.001], ["lb", 0.45359237], ["oz", 0.028349523], ["t", 1000]],
        "Temperature": [["°C", 0], ["°F", 0], ["K", 0]],
        "Data": [["MB", 1], ["GB", 1000], ["TB", 1e6], ["KB", 0.001], ["MiB", 1.048576], ["GiB", 1073.741824]],
        "Time": [["s", 1], ["min", 60], ["h", 3600], ["day", 86400], ["week", 604800]]
    })
    property string kind: "Length"
    property int fromI: 0
    property int toI: 1
    property real amount: 1
    readonly property real out: {
        const u = units[kind];
        if (kind === "Temperature") {
            const c = fromI === 0 ? amount : (fromI === 1 ? (amount - 32) * 5 / 9 : amount - 273.15);
            return toI === 0 ? c : (toI === 1 ? c * 9 / 5 + 32 : c + 273.15);
        }
        return amount * u[fromI][1] / u[toI][1];
    }
    Label { text: "Converter"; strong: true; font.pixelSize: Theme.sizeTitle }
    Segmented { Layout.fillWidth: true; height: 34; opts: Object.keys(cv.units).map(k => [k, k]); value: cv.kind; onPicked: v => { cv.kind = v; cv.fromI = 0; cv.toI = 1; } }
    Field { Layout.fillWidth: true; text: "1"; onAccepted: v => { const n = parseFloat(v.replace(",", ".")); if (!isNaN(n)) cv.amount = n; } }
    ChipFlow { opts: cv.units[cv.kind].map((u, i) => [String(i), u[0]]); value: String(cv.fromI); onPicked: v => cv.fromI = Number(v) }
    Icon { Layout.alignment: Qt.AlignHCenter; name: "arrow_downward"; size: 20; color: Theme.subtext }
    ChipFlow { opts: cv.units[cv.kind].map((u, i) => [String(i), u[0]]); value: String(cv.toI); onPicked: v => cv.toI = Number(v) }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: (Math.round(cv.out * 1e6) / 1e6) + " " + cv.units[cv.kind][cv.toI][0]
        color: Theme.accent
        font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 4; font.weight: Font.Bold
    }
    Item { Layout.fillHeight: true }
}
