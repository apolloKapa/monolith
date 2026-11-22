import QtQuick
import "../core"

// A one-line text field; `accepted(text)` on Enter, and when it loses focus (not with
// `acceptOnBlur: false`: a search box, where Enter opens the first result and clicking away
// shouldn't).
SmoothRect {
    id: fld
    property alias text: entry.text
    property string placeholder: ""
    property bool acceptOnBlur: true
    readonly property alias editing: entry.activeFocus
    signal accepted(string v)
    function forceInput() { entry.forceActiveFocus(); }
    function selectAll() { entry.selectAll(); }
    width: 240
    height: 40
    radius: Theme.corner(height)
    color: Theme.container
    border.width: entry.activeFocus ? 2 : Theme.outlineW
    border.color: entry.activeFocus ? Theme.accent : Theme.outlineColor
    Behavior on border.color { ColorAnimation { duration: Theme.fastMs } }
    TextInput {
        Keys.onPressed: e => Sounds.key(e)   // (a sound for each key; never takes it)
        // (not `input`: that's the name of the Caret's own property, and `Caret { input: input }`
        // pointed it at itself, so no field made from this one ever showed a cursor)
        id: entry
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        // drag over the text, double-click a word, Shift+arrows, Ctrl+A: the selection in the
        // accent, the text over it still readable in any theme
        selectByMouse: true
        selectionColor: Qt.alpha(Theme.accent, 0.38)
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sizeSmall + 1
        clip: true
        cursorDelegate: Component { Caret { input: entry } }
        onAccepted: fld.accepted(text)
        onActiveFocusChanged: if (!activeFocus && fld.acceptOnBlur) fld.accepted(text)
        HoverHandler { cursorShape: Qt.IBeamCursor }
        Label {
            anchors.fill: parent; verticalAlignment: Text.AlignVCenter; text: fld.placeholder; muted: true; font.pixelSize: Theme.sizeSmall
            // (it fades as you start typing instead of blinking out)
            opacity: entry.text === "" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
        }
    }
}
