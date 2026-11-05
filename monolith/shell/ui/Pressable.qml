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
    signal clicked(var mouse)
    signal rightClicked()

    radius: Theme.corner(height)
    color: Theme.containerHigh
    Behavior on color { ColorAnimation { duration: 220 } }

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
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => ink.press(mouse.x, mouse.y)
        onReleased: ink.release()
        onCanceled: ink.release()
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked(mouse); }
    }
}
