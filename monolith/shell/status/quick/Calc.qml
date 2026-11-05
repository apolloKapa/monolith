import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A calculator: keys or typing; = shows the result (click it to copy).
ColumnLayout {
    id: c
    spacing: 8
    property string expr: ""
    property string result: ""
    function evalNow() {
        try {
            const v = Function('"use strict"; return (' + expr.replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**").replace(/,/g, ".") + ')')();
            result = typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "Error";
        } catch (e) { result = "Error"; }
    }
    function press(k) {
        if (k === "C") { expr = ""; result = ""; }
        else if (k === "⌫") expr = expr.slice(0, -1);
        else if (k === "=") evalNow();
        else expr += k;
    }
    Label { text: "Calculator"; strong: true; font.pixelSize: Theme.sizeTitle }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: Theme.corner(92, 4)
        color: Theme.container
        TextInput {
            id: input
            x: 14; y: 12; width: parent.width - 28
            text: c.expr
            onTextEdited: c.expr = text
            onAccepted: c.evalNow()
            color: Theme.subtext
            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTitle
            horizontalAlignment: TextInput.AlignRight
            clip: true
            focus: true
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: c.result === "" ? "0" : c.result
            color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 6; font.weight: Font.Bold
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (c.result !== "" && c.result !== "Error") Quickshell.execDetached(["wl-copy", "--", c.result]) }
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
