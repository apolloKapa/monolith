import QtQuick
import "../../core"

// Click a Wellbeing widget: the Wellbeing page opens (not in the editor or on the lock screen;
// its "Click opens Wellbeing" setting turns it off)
MouseArea {
    property var face: null
    anchors.fill: parent
    enabled: !!face && !face.editing && face.live && face.opt("clickOpens", true) !== false && !LockState.locked
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton
    onClicked: HubState.show("wellbeing")
}
