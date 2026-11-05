import QtQuick
import "../core"

// A number you set exactly: − and + step it, the wheel does too, or type it and press Enter.
// `shown` is what's displayed (value × factor, e.g. 1.25 → 125 for a %), `unit` follows it.
Rectangle {
    id: nb
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property real factor: 1          // displayed = value × factor
    property string unit: ""
    property string zeroText: ""     // what 0 reads as ("Off", "Never"), if anything
    signal moved(real v)
    width: 190
    height: 40
    radius: height / 2
    color: Theme.container

    function clamp(v) { return Math.max(from, Math.min(to, v)); }
    function round(v) { const p = Math.pow(10, decimals); return Math.round(v * p) / p; }
    function set(v) { const c = round(clamp(v)); if (c !== value) moved(c); }
    readonly property string text: zeroText !== "" && value === 0 ? zeroText : (round(value * factor).toFixed(Math.max(0, decimals - Math.round(Math.log10(factor)))) + (unit !== "" ? " " + unit : ""))

    Pressable {
        id: minus
        x: 4; anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        color: hovered ? Theme.containerHigh : "transparent"
        enabledInput: nb.value > nb.from
        opacity: enabledInput ? 1 : 0.4
        onClicked: nb.set(nb.value - nb.step)
        Icon { anchors.centerIn: parent; name: "remove"; size: 18 }
    }
    TextInput {
        id: input
        anchors.left: minus.right; anchors.right: plus.left
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: TextInput.AlignHCenter
        color: Theme.text
        selectionColor: Theme.selected
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sizeBody
        font.weight: Font.DemiBold
        text: nb.text
        selectByMouse: true
        // typing: the bare number; afterwards it follows the value again
        onActiveFocusChanged: {
            if (activeFocus) { text = String(nb.round(nb.value * nb.factor)); selectAll(); }
            else text = Qt.binding(() => nb.text);
        }
        onAccepted: { const v = parseFloat(text.replace(",", ".")); if (!isNaN(v)) nb.set(v / nb.factor); focus = false; }
        Keys.onEscapePressed: focus = false
        Keys.onUpPressed: nb.set(nb.value + nb.step)
        Keys.onDownPressed: nb.set(nb.value - nb.step)
    }
    Pressable {
        id: plus
        anchors.right: parent.right; anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        color: hovered ? Theme.containerHigh : "transparent"
        enabledInput: nb.value < nb.to
        opacity: enabledInput ? 1 : 0.4
        onClicked: nb.set(nb.value + nb.step)
        Icon { anchors.centerIn: parent; name: "add"; size: 18 }
    }
    WheelHandler { onWheel: event => nb.set(nb.value + (event.angleDelta.y > 0 ? nb.step : -nb.step)) }
}
