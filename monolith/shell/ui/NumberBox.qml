import QtQuick
import "../core"

// A setting's number as a slider: drag or click the track, scroll it, or click the value on
// the right to type an exact one (Enter). Steps of `step` between `from` and `to`. The slider
// itself spans from..`slideTo` (the usual range); typed values can go on to `to`.
// `factor` is how it's shown (value × factor, e.g. 1.25 → 125 for a %), `unit` follows it,
// `zeroText` is what 0 reads as ("Off", "Never") if anything.
Item {
    id: nb
    property real value: 0
    property real from: 0
    property real to: 100
    property real slideTo: to
    property real step: 1
    property int decimals: 0
    property real factor: 1
    property string unit: ""
    property string zeroText: ""
    signal moved(real v)
    width: 300
    height: 36

    function clamp(v) { return Math.max(from, Math.min(to, v)); }
    function snap(v) { const p = Math.pow(10, decimals); return Math.round(Math.round((v - from) / step) * step * p + from * p) / p; }
    function set(v) { const c = clamp(snap(v)); if (Math.abs(c - value) > 1e-9) moved(c); }
    readonly property int shownDecimals: Math.max(0, decimals - Math.round(Math.log10(factor)))
    readonly property string text: zeroText !== "" && value === 0 ? zeroText : (value * factor).toFixed(shownDecimals) + (unit !== "" ? " " + unit : "")

    // while dragging the slider follows the pointer; the setting is written as it moves
    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    readonly property real frac: slideTo > from ? Math.min(1, (clamp(shown) - from) / (slideTo - from)) : 0

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: valueBox.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 10
        radius: 5
        color: Theme.control
        // the fill: up to the handle's middle, so the handle always caps it (sized on its own, its
        // rounded end used to poke out past the handle)
        Rectangle {
            width: Math.max(0, handle.x + handle.width / 2)
            visible: width > 0.5
            height: parent.height
            radius: Math.min(parent.radius, width / 2)
            color: Theme.accent
        }
        // the handle: a pill that stands up from the track
        Rectangle {
            id: handle
            x: Math.max(0, Math.min(parent.width - width, parent.width * nb.frac - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: nb.dragging || area.containsMouse ? 30 : 26
            radius: 3
            color: Theme.accent
            border.width: 2
            border.color: Theme.card
            Behavior on height { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
            Behavior on x { enabled: !nb.dragging; NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -13
            anchors.bottomMargin: -13
            hoverEnabled: true
            // a slider inside something that scrolls keeps its drag
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return nb.clamp(nb.snap(nb.from + Math.max(0, Math.min(1, x / track.width)) * (nb.slideTo - nb.from))); }
            onPressed: mouse => { nb.dragging = true; nb.dragValue = at(mouse.x); nb.set(nb.dragValue); }
            onPositionChanged: mouse => { if (pressed) { const v = at(mouse.x); if (v !== nb.dragValue) { nb.dragValue = v; nb.set(v); } } }
            onReleased: nb.dragging = false
            onCanceled: nb.dragging = false
            onWheel: wheel => nb.set(nb.value + (wheel.angleDelta.y > 0 ? nb.step : -nb.step))
        }
    }

    // the exact value; click it to type one
    Rectangle {
        id: valueBox
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(72, input.contentWidth + 22)
        height: 32
        radius: height / 2
        color: input.activeFocus ? Theme.containerHigh : Theme.container
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            selectionColor: Theme.selected
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sizeSmall + 1
            font.weight: Font.DemiBold
            text: nb.text
            selectByMouse: true
            // typing: the bare number; afterwards it follows the value again
            onActiveFocusChanged: {
                if (activeFocus) { text = (nb.value * nb.factor).toFixed(nb.shownDecimals); selectAll(); }
                else text = Qt.binding(() => nb.text);
            }
            onAccepted: { const v = parseFloat(text.replace(",", ".")); if (!isNaN(v)) nb.set(v / nb.factor); focus = false; }
            Keys.onEscapePressed: focus = false
            Keys.onUpPressed: nb.set(nb.value + nb.step)
            Keys.onDownPressed: nb.set(nb.value - nb.step)
        }
        WheelHandler { onWheel: event => nb.set(nb.value + (event.angleDelta.y > 0 ? nb.step : -nb.step)) }
    }
}
