import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A unit converter: eleven kinds, the answer as you type, a swap button, the answer copies on a
// click, and the amount in every other unit of the kind underneath.
ColumnLayout {
    id: cv
    spacing: 8
    // [unit, how many of the kind's base unit it is]
    readonly property var units: ({
        "Length": [["m", 1], ["km", 1000], ["cm", 0.01], ["mm", 0.001], ["µm", 1e-6], ["mi", 1609.344], ["yd", 0.9144], ["ft", 0.3048], ["in", 0.0254], ["nmi", 1852]],
        "Weight": [["kg", 1], ["g", 0.001], ["mg", 1e-6], ["t", 1000], ["lb", 0.45359237], ["oz", 0.028349523], ["st", 6.35029318]],
        "Temperature": [["°C", 0], ["°F", 0], ["K", 0]],
        "Area": [["m²", 1], ["km²", 1e6], ["cm²", 1e-4], ["ha", 1e4], ["acre", 4046.8564224], ["ft²", 0.09290304], ["in²", 0.00064516], ["mi²", 2589988.110336]],
        "Volume": [["L", 1], ["mL", 0.001], ["m³", 1000], ["gal (US)", 3.785411784], ["gal (UK)", 4.54609], ["qt", 0.946352946], ["pt", 0.473176473], ["cup", 0.2365882365], ["fl oz", 0.0295735296], ["tbsp", 0.0147867648], ["tsp", 0.00492892159]],
        "Speed": [["km/h", 1], ["m/s", 3.6], ["mph", 1.609344], ["knot", 1.852], ["ft/s", 1.09728]],
        "Time": [["s", 1], ["ms", 0.001], ["min", 60], ["h", 3600], ["day", 86400], ["week", 604800], ["year", 31557600]],
        "Data": [["MB", 1], ["KB", 0.001], ["GB", 1000], ["TB", 1e6], ["KiB", 0.001024], ["MiB", 1.048576], ["GiB", 1073.741824], ["TiB", 1099511.627776], ["Mbit", 0.125], ["Gbit", 125]],
        "Pressure": [["bar", 1], ["Pa", 1e-5], ["kPa", 0.01], ["psi", 0.0689475729], ["atm", 1.01325], ["mmHg", 0.00133322]],
        "Energy": [["J", 1], ["kJ", 1000], ["cal", 4.184], ["kcal", 4184], ["Wh", 3600], ["kWh", 3.6e6], ["eV", 1.602176634e-19]],
        "Angle": [["°", 1], ["rad", 57.29577951308232], ["grad", 0.9], ["turn", 360]]
    })
    property string kind: "Length"
    property int fromI: 0
    property int toI: 1
    property real amount: 1
    function conv(a, f, t) {
        const u = units[kind];
        if (kind === "Temperature") {
            const c = f === 0 ? a : (f === 1 ? (a - 32) * 5 / 9 : a - 273.15);
            return t === 0 ? c : (t === 1 ? c * 9 / 5 + 32 : c + 273.15);
        }
        return a * u[f][1] / u[t][1];
    }
    function nice(v) {
        if (!isFinite(v)) return "—";
        const a = Math.abs(v);
        return a !== 0 && (a >= 1e12 || a < 1e-6) ? v.toExponential(4) : String(Math.round(v * 1e6) / 1e6);
    }
    readonly property real out: conv(amount, fromI, toI)

    Label { text: "Converter"; strong: true; font.pixelSize: Theme.sizeTitle }
    ChipFlow { Layout.fillWidth: true; opts: Object.keys(cv.units).map(k => [k, k]); value: cv.kind; onPicked: v => { cv.kind = v; cv.fromI = 0; cv.toI = 1; } }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Field {
            id: amt
            Layout.fillWidth: true
            text: "1"
            // as you type
            onTextChanged: { const n = parseFloat(text.replace(",", ".")); if (!isNaN(n)) cv.amount = n; }
        }
        // swap the two units
        Pressable {
            width: 40; height: 40
            color: Theme.control
            onClicked: { const f = cv.fromI; cv.fromI = cv.toI; cv.toI = f; }
            Icon { anchors.centerIn: parent; name: "swap_vert"; size: 20 }
        }
    }
    Label { text: "From"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
    ChipFlow { Layout.fillWidth: true; opts: cv.units[cv.kind].map((u, i) => [String(i), u[0]]); value: String(cv.fromI); onPicked: v => cv.fromI = Number(v) }
    Label { text: "To"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
    ChipFlow { Layout.fillWidth: true; opts: cv.units[cv.kind].map((u, i) => [String(i), u[0]]); value: String(cv.toI); onPicked: v => cv.toI = Number(v) }
    // the answer (click to copy)
    Pressable {
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        color: hovered ? Theme.containerHigh : Theme.container
        onClicked: Quickshell.execDetached(["wl-copy", "--", cv.nice(cv.out)])
        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: cv.nice(cv.out) + " " + cv.units[cv.kind][cv.toI][0]
            color: Theme.accent
            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 2; font.weight: Font.Bold
        }
        Icon { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: "content_copy"; size: 16; color: Theme.subtext; visible: parent.hovered }
    }
    // the amount in every other unit
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: cv.units[cv.kind].map((u, i) => i).filter(i => i !== cv.fromI && i !== cv.toI)
        delegate: Pressable {
            required property int modelData
            width: ListView.view.width; height: 30
            color: hovered ? Theme.containerHigh : "transparent"
            onClicked: cv.toI = modelData
            Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: cv.units[cv.kind][parent.modelData][0]; muted: true; font.pixelSize: Theme.sizeSmall }
            Label { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: cv.nice(cv.conv(cv.amount, cv.fromI, parent.modelData)); font.pixelSize: Theme.sizeSmall }
        }
    }
}
