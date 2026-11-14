import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A calculator: keys or typing. The answer shows as you type; = (or Enter) keeps it in the
// history (kept across restarts: click a line to use it again, its copy button copies the
// answer). The scientific keys add powers, roots, trig (in degrees or radians), logs, π, e and
// "ans" (the last answer). Wide (the panel made bigger), the history gets a column of its own.
GridLayout {
    id: c
    columns: wide ? 2 : 1
    columnSpacing: 14
    rowSpacing: 8
    readonly property bool wide: width > 760
    property string expr: ""
    property string result: ""
    property bool sci: Store.get("quick.calcSci", false) === true
    property bool deg: true
    property var history: Store.get("quick.calcHistory", []) || []           // [{ e, r }], newest first
    property string ans: "0"

    // the expression as JavaScript, with the calculator's names as plain functions
    function compute(x) {
        if (x.trim() === "") return "";
        try {
            const src = x.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/\^/g, "**").replace(/π/g, "pi").replace(/√/g, "sqrt")
                         .replace(/(\d+(\.\d+)?)%/g, "($1/100)").replace(/,/g, ".");
            if (/[^0-9a-z+\-*/().\s]/i.test(src)) return "Error";
            const k = c.deg ? Math.PI / 180 : 1;
            const v = Function("sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "ln", "log", "abs", "pi", "e", "ans", "fact", '"use strict"; return (' + src + ")")(
                a => Math.sin(a * k), a => Math.cos(a * k), a => Math.tan(a * k),
                a => Math.asin(a) / k, a => Math.acos(a) / k, a => Math.atan(a) / k,
                Math.sqrt, Math.log, Math.log10, Math.abs, Math.PI, Math.E, Number(c.ans),
                n => { let r = 1; for (let i = 2; i <= Math.min(170, Math.floor(n)); i++) r *= i; return r; });
            if (typeof v !== "number" || !isFinite(v)) return "Error";
            return String(Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-9 && v !== 0) ? v.toPrecision(10) : Math.round(v * 1e10) / 1e10);
        } catch (e) { return "Error"; }
    }
    // shown while you type
    readonly property string live: compute(expr)
    function evalNow() {
        const r = compute(expr);
        if (r === "" ) return;
        result = r;
        if (r !== "Error") { Store.set("quick.calcHistory", [{ e: expr, r: r }].concat(history.filter(h => h.e !== expr)).slice(0, 60)); ans = r; }
    }
    function press(k) {
        if (k === "C") { expr = ""; result = ""; }
        else if (k === "⌫") expr = expr.slice(0, -1);
        else if (k === "=") evalNow();
        else if (["sin", "cos", "tan", "ln", "log", "√", "asin", "acos", "atan", "abs", "fact"].indexOf(k) !== -1) expr += k + "(";
        else if (k === "x²") expr += "^2";
        else if (k === "xʸ") expr += "^";
        else if (k === "1/x") expr = "1/(" + expr + ")";
        else if (k === "±") expr = expr.startsWith("-(") && expr.endsWith(")") ? expr.slice(2, -1) : "-(" + expr + ")";
        else expr += k;
        input.forceActiveFocus();
    }
    function copy(v) { if (v !== "" && v !== "Error") Quickshell.execDetached(["wl-copy", "--", v]); }

    ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: c.wide ? 3 : 1
    Layout.maximumWidth: c.wide ? 760 : -1
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        Label { text: "Calculator"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
        Pressable {
            visible: c.sci
            width: dl.implicitWidth + 18; height: 30
            color: Theme.control
            onClicked: c.deg = !c.deg
            Label { id: dl; anchors.centerIn: parent; text: c.deg ? "DEG" : "RAD"; strong: true; font.pixelSize: Theme.sizeSmall }
        }
        Pressable {
            width: sl.implicitWidth + 18; height: 30
            color: c.sci ? Theme.accentContainer : Theme.control
            onClicked: { c.sci = !c.sci; Store.set("quick.calcSci", c.sci); }
            Label { id: sl; anchors.centerIn: parent; text: "Scientific"; font.pixelSize: Theme.sizeSmall; color: c.sci ? Theme.onAccentContainer : Theme.text }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: Theme.corner(96, 4)
        color: Theme.container
        TextInput {
            id: input
            x: 14; y: 12; width: parent.width - 28
            text: c.expr
            onTextEdited: c.expr = text
            onAccepted: c.evalNow()
            Keys.onEscapePressed: event => { if (text !== "") { c.expr = ""; c.result = ""; } else event.accepted = false; }
            color: Theme.subtext
            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTitle
            horizontalAlignment: TextInput.AlignRight
            clip: true
            focus: true
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            width: parent.width - 28
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            // the kept answer, or what it comes to so far (fainter)
            readonly property bool pending: c.live !== "" && c.live !== "Error" && c.live !== c.result
            text: pending ? "= " + c.live : (c.result === "" ? "0" : c.result)
            color: pending ? Theme.subtext : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 6; font.weight: Font.Bold
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.copy(pending ? c.live : c.result) }
        }
        // copy the answer (or what it comes to so far)
        Pressable {
            x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            width: 30; height: 30
            color: hovered ? Theme.containerHigh : "transparent"
            visible: c.result !== "" || (c.live !== "" && c.live !== "Error")
            onClicked: c.copy(c.live !== "" && c.live !== "Error" ? c.live : c.result)
            Icon { anchors.centerIn: parent; name: "content_copy"; size: 16; color: Theme.subtext }
        }
    }
    // the history: click one to use it again
    // (narrow: the last three, over the keys)
    ListView {
        SmoothWheel {}
        Layout.fillWidth: true
        Layout.preferredHeight: c.history.length === 0 || c.wide ? 0 : Math.min(3, c.history.length) * 30
        visible: c.history.length > 0 && !c.wide
        clip: true
        model: c.history
        delegate: HistoryRow {}
    }
    GridLayout {
        visible: c.sci
        Layout.fillWidth: true
        columns: 5
        rowSpacing: 6; columnSpacing: 6
        Repeater {
            model: ["sin", "cos", "tan", "π", "e", "ln", "log", "√", "x²", "xʸ", "1/x", "±", "%", "fact", "ans"]
            Pressable {
                required property string modelData
                // (fixed height: the number keys below take the rest)
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: Theme.container
                onClicked: c.press(modelData)
                Label { anchors.centerIn: parent; text: parent.modelData === "fact" ? "n!" : parent.modelData; font.pixelSize: Theme.sizeSmall + 1 }
            }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 4
        rowSpacing: 6; columnSpacing: 6
        Repeater {
            model: ["C", "(", ")", "÷", "7", "8", "9", "×", "4", "5", "6", "-", "1", "2", "3", "+", "0", ".", "⌫", "="]
            Pressable {
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: modelData === "=" ? Theme.accent : (/[0-9.]/.test(modelData) ? Theme.containerHigh : Theme.control)
                ink: modelData === "=" ? Theme.onAccent : Theme.text
                onClicked: c.press(modelData)
                Label { anchors.centerIn: parent; text: parent.modelData; strong: true; font.pixelSize: Theme.sizeTitle; color: parent.modelData === "=" ? Theme.onAccent : Theme.text }
            }
        }
    }
    }

    // ── the history (wide) ──
    ColumnLayout {
        visible: c.wide
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label { text: "History"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
            Pressable {
                visible: c.history.length > 0
                width: hcl.implicitWidth + 20; height: 30
                color: hovered ? Theme.containerHigh : Theme.control
                onClicked: Store.set("quick.calcHistory", [])
                Label { id: hcl; anchors.centerIn: parent; text: "Clear"; font.pixelSize: Theme.sizeSmall }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 4)
            color: Theme.container
            ListView {
                SmoothWheel {}
                anchors.fill: parent; anchors.margins: 6
                clip: true
                spacing: 2
                model: c.history
                delegate: HistoryRow {}
            }
            Label { anchors.centerIn: parent; visible: c.history.length === 0; text: "Answers you get with = show up here"; muted: true; font.pixelSize: Theme.sizeSmall }
        }
    }

    // a line of the history: the sum (click to use it again), the answer, and copy
    component HistoryRow: Pressable {
        required property var modelData
        width: ListView.view ? ListView.view.width : 200; height: 30
        color: hovered ? Theme.containerHigh : "transparent"
        onClicked: { c.expr = modelData.e; input.forceActiveFocus(); }
        Label { x: 10; width: parent.width * 0.55; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.e; muted: true; font.pixelSize: Theme.sizeSmall }
        Label { anchors.right: hcp.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.4 - 40; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: "= " + parent.modelData.r; strong: true; font.pixelSize: Theme.sizeSmall }
        Pressable {
            id: hcp
            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            color: hovered ? Theme.control : "transparent"
            onClicked: c.copy(parent.modelData.r)
            Icon { anchors.centerIn: parent; name: "content_copy"; size: 14; color: Theme.subtext }
        }
    }
}
