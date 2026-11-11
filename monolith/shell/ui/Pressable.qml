import QtQuick
import "../core"

// Anything clickable: a rounded tonal shape with a ripple. Children go inside.
Rectangle {
    id: root
    property alias hovered: ma.containsMouse
    property alias pressed: ma.pressed
    property color ink: Theme.text
    property bool enabledInput: true
    property int buttons: Qt.LeftButton
    property int cursor: Qt.PointingHandCursor
    signal clicked(var mouse)
    signal rightClicked()

    radius: Theme.corner(height)
    color: Theme.containerHigh
    Behavior on color { ColorAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
    // the style's outline, on buttons that have a fill
    border.width: color.a > 0.05 ? Math.max(0, Theme.outlineW - 1) : 0
    border.color: Theme.outlineColor
    // gives a little under the pointer (about 6 px, whatever its size)
    scale: ma.pressed && enabledInput ? 1 - Math.min(0.08, 6 / Math.max(40, width)) : 1
    Behavior on scale { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }

    Ripple {
        id: ink
        radius: root.radius
        ink: root.ink
        hovered: ma.containsMouse && root.enabledInput
        pressed: ma.pressed && root.enabledInput
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledInput
        cursorShape: root.cursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => ink.press(mouse.x, mouse.y)
        onReleased: ink.release()
        onCanceled: ink.release()
        onClicked: mouse => { Sounds.play("click"); if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked(mouse); }
    }
}
