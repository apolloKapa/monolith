import QtQuick
import "../core"

// A text field's cursor (its cursorDelegate). The built-in one blinks for as long as the field
// has focus, even when the field can't be seen, and every blink redraws its whole window: an
// invisible field keeping the keys in a menu redrew the menu twice a second while it sat open.
// This one is only there while `shown`, and blinks for a while after you type or move it, then
// holds still (as GTK's does), so a field you've left doesn't keep the screen busy.
Rectangle {
    id: caret
    // the TextInput it belongs to (set by the field: `cursorDelegate: Component { Caret { input: … } }`)
    property Item input: parent
    // whether it should be there at all (the field visible and in use)
    property bool shown: true
    readonly property bool on: shown && !!input && input.activeFocus && input.visible
    width: Math.max(1.5, Math.round((input ? input.font.pixelSize : 14) / 12))
    color: Theme.accent
    property bool lit: true
    visible: on && lit
    // how long it keeps blinking after the last change
    readonly property int blinkFor: 10000
    property real since: 0
    function wake() { since = Date.now(); lit = true; if (on) blink.restart(); }
    Timer {
        id: blink
        interval: 530; repeat: true
        running: caret.on && Theme.animOn
        onTriggered: {
            if (Date.now() - caret.since > caret.blinkFor) { caret.lit = true; stop(); return; }
            caret.lit = !caret.lit;
        }
    }
    onOnChanged: wake()
    Connections {
        target: caret.input
        ignoreUnknownSignals: true
        function onTextChanged() { caret.wake(); }
        function onCursorPositionChanged() { caret.wake(); }
    }
    Component.onCompleted: wake()
}
