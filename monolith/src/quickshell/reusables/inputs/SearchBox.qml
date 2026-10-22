import QtQuick
import "../../"

// A plain search field for panels (cheatsheet, overview, switcher...). Arrow keys, Tab, Enter
// and Escape are passed on as navigate()/accepted()/escaped() so the panel can drive its list.
Rectangle {
    id: root
    property alias text: field.text
    readonly property alias field: field
    property string placeholderText: ""
    property string icon: "󰍉"
    signal navigate(int step)
    signal accepted()
    signal escaped()

    function focusField() {
        field.forceActiveFocus();
    }
    function clear() {
        field.text = "";
    }

    implicitHeight: Scaler.s(40)
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, Math.max(0.6, ThemeBackend.elementOpacity))
    border.width: ThemeBackend.outlined ? ThemeBackend.outlineInner : (field.activeFocus ? 1 : 0)
    border.color: ThemeBackend.outlined ? ThemeBackend.outlineColor : Qt.alpha(ThemeBackend.mauve, 0.6)

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Scaler.s(12)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: ThemeBackend.subtext0
        font.family: ThemeBackend.iconFont
        font.pixelSize: Scaler.s(16)
    }

    TextInput {
        id: field
        anchors.left: glyph.right
        anchors.leftMargin: Scaler.s(10)
        anchors.right: parent.right
        anchors.rightMargin: Scaler.s(12)
        anchors.verticalCenter: parent.verticalCenter
        color: ThemeBackend.text
        selectionColor: Qt.alpha(ThemeBackend.mauve, 0.4)
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(14)
        clip: true
        focus: true

        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Down: root.navigate(1); event.accepted = true; break;
            case Qt.Key_Up: root.navigate(-1); event.accepted = true; break;
            case Qt.Key_Tab: root.navigate((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; break;
            case Qt.Key_Backtab: root.navigate(-1); event.accepted = true; break;
            case Qt.Key_Return:
            case Qt.Key_Enter: root.accepted(); event.accepted = true; break;
            case Qt.Key_Escape: root.escaped(); event.accepted = true; break;
            }
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: field.text === ""
            text: root.placeholderText
            color: ThemeBackend.subtext0
            font: field.font
            elide: Text.ElideRight
        }
    }
}
