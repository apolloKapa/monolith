import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A unit converter: eleven kinds, the answer as you type, a swap button, copy buttons on the
// answer and on every other unit of the kind, and a history of what you converted (kept a moment
// after you stop typing; click one to bring it back). Wide (the panel made bigger), the units and
// the history get a column of their own.
GridLayout {
    id: cv
    columns: wide ? 2 : 1
    columnSpacing: 14
    rowSpacing: 8
    readonly property bool wide: width > 760
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
    readonly property var history: Store.get("quick.convertHistory", []) || []    // [{ k, a, f, t }], newest first
    function conv(a, f, t, k) {
        const kk = k || kind, u = units[kk];
        if (kk === "Temperature") {
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
    function unitName(k, i) { return units[k] && units[k][i] ? units[k][i][0] : ""; }
    function copy(t) { Quickshell.execDetached(["wl-copy", "--", t]); }
    readonly property real out: conv(amount, fromI, toI)
    // a moment after it settles, it goes in the history (not on every key)
    function remember() {
        const e = { k: kind, a: amount, f: fromI, t: toI };
        const same = h => h.k === e.k && h.a === e.a && h.f === e.f && h.t === e.t;
        if (history.length && same(history[0])) return;
        Store.set("quick.convertHistory", [e].concat(history.filter(h => !same(h))).slice(0, 60));
    }
    Timer { id: settle; interval: 1500; onTriggered: cv.remember() }
    onAmountChanged: settle.restart()
    onFromIChanged: settle.restart()
    onToIChanged: settle.restart()
    function recall(h) { kind = h.k; fromI = h.f; toI = h.t; amount = h.a; amt.text = String(h.a); settle.stop(); }

    // a small copy button
    component CopyBtn: Pressable {
        property string what: ""
        width: 26; height: 26
        color: hovered ? Theme.control : "transparent"
        onClicked: cv.copy(what)
        Icon { anchors.centerIn: parent; name: "content_copy"; size: 14; color: Theme.subtext }
    }

    // ── the converter ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 3
        Layout.maximumWidth: cv.wide ? 720 : -1
        spacing: 8
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
                onAccepted: cv.remember()
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
            Layout.preferredHeight: 64
            color: hovered ? Theme.containerHigh : Theme.container
            onClicked: { cv.copy(cv.nice(cv.out)); cv.remember(); }
            Column {
                anchors.centerIn: parent
                width: parent.width - 60
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cv.nice(cv.out) + " " + cv.units[cv.kind][cv.toI][0]
                    color: Theme.accent
                    font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 2; font.weight: Font.Bold
                }
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cv.nice(cv.amount) + " " + cv.units[cv.kind][cv.fromI][0] + " is"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
            }
            Icon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "content_copy"; size: 18; color: parent.hovered ? Theme.text : Theme.subtext }
        }
        // narrow: the other units and the history share what's left, in tabs
        Segmented {
            visible: !cv.wide
            Layout.fillWidth: true; height: 32
            opts: [["units", "Every unit"], ["history", "History"]]
            value: listTabs.tab
            onPicked: v => listTabs.tab = v
        }
        Item {
            id: listTabs
            property string tab: "units"
            visible: !cv.wide
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            UnitList { anchors.fill: parent; visible: listTabs.tab === "units" }
            HistoryList { anchors.fill: parent; visible: listTabs.tab === "history" }
        }
    }

    // ── wide: the other units and the history, side by side with it ──
    ColumnLayout {
        visible: cv.wide
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        spacing: 6
        Label { text: "Every unit"; strong: true; font.pixelSize: Theme.sizeTitle }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 4)
            color: Theme.container
            UnitList { anchors.fill: parent; anchors.margins: 6 }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "History"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
            Pressable {
                visible: cv.history.length > 0
                width: ccl.implicitWidth + 20; height: 30
                color: hovered ? Theme.containerHigh : Theme.control
                onClicked: Store.set("quick.convertHistory", [])
                Label { id: ccl; anchors.centerIn: parent; text: "Clear"; font.pixelSize: Theme.sizeSmall }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 4)
            color: Theme.container
            HistoryList { anchors.fill: parent; anchors.margins: 6 }
        }
    }

    // the amount in every other unit: click one to convert to it, or copy it
    component UnitList: ListView {
        SmoothWheel {}
        clip: true
        spacing: 2
        model: cv.units[cv.kind].map((u, i) => i).filter(i => i !== cv.fromI && i !== cv.toI)
        delegate: Pressable {
            required property int modelData
            readonly property string val: cv.nice(cv.conv(cv.amount, cv.fromI, modelData))
            width: ListView.view.width; height: 32
            color: hovered ? Theme.containerHigh : "transparent"
            onClicked: cv.toI = modelData
            Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: cv.units[cv.kind][parent.modelData][0]; muted: true; font.pixelSize: Theme.sizeSmall }
            Label { anchors.right: ucp.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.val; font.pixelSize: Theme.sizeSmall; strong: true }
            CopyBtn { id: ucp; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; what: parent.val }
        }
    }
    // what you converted: click to bring it back, or copy the answer
    component HistoryList: ListView {
        SmoothWheel {}
        clip: true
        spacing: 2
        model: cv.history
        delegate: Pressable {
            required property var modelData
            readonly property string ans: cv.nice(cv.conv(modelData.a, modelData.f, modelData.t, modelData.k)) + " " + cv.unitName(modelData.k, modelData.t)
            width: ListView.view.width; height: 32
            color: hovered ? Theme.containerHigh : "transparent"
            onClicked: cv.recall(modelData)
            Label { x: 10; width: parent.width * 0.5 - 10; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: cv.nice(parent.modelData.a) + " " + cv.unitName(parent.modelData.k, parent.modelData.f); muted: true; font.pixelSize: Theme.sizeSmall }
            Label { anchors.right: hcp.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5 - 44; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: "→ " + parent.ans; strong: true; font.pixelSize: Theme.sizeSmall }
            CopyBtn { id: hcp; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; what: parent.ans }
        }
        Label { anchors.centerIn: parent; visible: cv.history.length === 0; text: "What you convert shows up here"; muted: true; font.pixelSize: Theme.sizeSmall }
    }
}
