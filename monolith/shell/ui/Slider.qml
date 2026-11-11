import QtQuick
import "../core"

// A thick tonal slider with its icon inside the track (the filled part is the accent).
// `value` 0..1; `moved(v)` while dragging or on wheel.
Item {
    id: s
    property real value: 0
    property string icon: ""
    property string label: ""
    property bool muted: false
    signal moved(real v)
    signal iconClicked()
    implicitHeight: 44

    readonly property real shown: dragging ? dragValue : value
    property bool dragging: false
    property real dragValue: 0

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Theme.corner(height)
        color: Theme.control
        clip: true

        Rectangle {
            height: parent.height
            width: Math.max(parent.height, parent.width * s.shown)
            radius: track.radius
            color: s.muted ? Theme.faint : Theme.accent
            Behavior on width { enabled: !s.dragging; NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
        }
    }
    Icon {
        id: ic
        x: (s.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: s.height * 0.6
        name: s.icon
        size: 20
        filled: true
        color: s.shown > 0.08 && !s.muted ? Theme.onAccent : Theme.text
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: s.iconClicked() }
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: s.label !== "" ? s.label : Math.round(s.shown * 100) + "%"
        font.pixelSize: Theme.sizeSmall
        color: s.shown > 0.9 && !s.muted ? Theme.onAccent : Theme.subtext
    }
    MouseArea {
        anchors.fill: parent
        anchors.leftMargin: s.height
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, (x + s.height) / s.width)); }
        onPressed: mouse => { s.dragging = true; s.dragValue = at(mouse.x); s.moved(s.dragValue); }
        onPositionChanged: mouse => { if (pressed) { s.dragValue = at(mouse.x); s.moved(s.dragValue); } }
        onReleased: s.dragging = false
        onCanceled: s.dragging = false
        // inside a list that scrolls, the wheel scrolls the list (it used to change the value
        // of whatever slider the pointer happened to pass over); anywhere else it nudges the value
        onWheel: wheel => {
            for (let p = s.parent; p; p = p.parent) {
                if (p.contentY !== undefined && p.flickableDirection !== undefined && p.contentHeight > p.height + 1) { wheel.accepted = false; return; }
            }
            s.moved(Math.max(0, Math.min(1, s.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
        }
    }
}
