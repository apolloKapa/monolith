import QtQuick
import "../core"

// A text button: tonal, or filled with the accent when `primary`.
Pressable {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    // the narrowest it gets (an icon-only button can be a square: 40)
    property real minWidth: 96
    // the widest it may get (0: as wide as its text). Past that the text gets smaller (down to
    // 10 px), then loses its middle: a long text can't push into what's next to it
    property real maxWidth: 0
    readonly property real iconW: icon !== "" ? 18 + (text !== "" ? row.spacing : 0) : 0
    // (the text at its full size, to measure: the same kind of item as the one shown, so the two agree)
    Label { id: full; visible: false; strong: true; text: btn.maxWidth > 0 ? btn.text : "" }
    readonly property real textRoom: Math.max(1, width - 32 - iconW)
    readonly property bool tight: maxWidth > 0 && full.implicitWidth > textRoom
    // Its size is its implicit size, so a layout follows when the text changes. With only `width`
    // set, a RowLayout kept the first width it saw: a longer text ("Press a key…", a longer key)
    // widened the button over the one next to it.
    implicitWidth: maxWidth > 0 ? Math.min(Math.max(minWidth, maxWidth), Math.max(minWidth, full.implicitWidth + iconW + 32))
                                : Math.max(minWidth, row.implicitWidth + 32)
    implicitHeight: 40
    width: implicitWidth
    height: implicitHeight
    color: primary ? Theme.accent : Theme.control
    ink: primary ? Theme.onAccent : Theme.text
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { visible: btn.icon !== ""; name: btn.icon; size: 18; color: btn.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Label {
            text: btn.text; strong: true; color: btn.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: btn.tight ? Math.max(10, Math.floor(Theme.sizeBody * btn.textRoom / full.implicitWidth)) : Theme.sizeBody
            width: btn.maxWidth > 0 ? Math.min(implicitWidth, btn.textRoom) : implicitWidth
            elide: Text.ElideMiddle
        }
    }
}
