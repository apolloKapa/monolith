import QtQuick
import "../../core"
import "../../ui"

// Material analog: a scalloped dial (twelve soft lobes) in the primary container colour, thick
// rounded hour and minute hands, and the second shown as a dot running round the rim.
FaceBase {
    id: f
    readonly property real d: Math.min(width, height)
    readonly property bool secs: opt("showSeconds", true)
    readonly property color dial: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourC: Theme.m("secondary", Theme.subtext)
    readonly property color minC: Theme.m("primary", Theme.accent)
    readonly property color secC: Theme.m("tertiary", Theme.accent)
    Canvas {
        anchors.centerIn: parent
        width: f.d; height: f.d
        property color fill: f.dial
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const cx = width / 2, cy = height / 2, rm = width * 0.46, amp = width * 0.012;
            c.beginPath();
            for (let i = 0; i <= 240; i++) {
                const a = i / 240 * Math.PI * 2, r = rm + amp * Math.cos(12 * a);
                const x = cx + r * Math.sin(a), y = cy - r * Math.cos(a);
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.closePath();
            c.fillStyle = fill;
            c.fill();
        }
    }
    component Hand: Item {
        property real angle
        property real w
        property real len
        property color col
        anchors.centerIn: parent
        rotation: angle
        Behavior on rotation { enabled: f.live; RotationAnimation { duration: 400; direction: RotationAnimation.Clockwise; easing.type: Easing.OutCubic } }
        Rectangle { width: parent.w; height: parent.len; radius: width / 2; color: parent.col; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: -width / 2 }
    }
    Hand { angle: (f.now.getHours() % 12) * 30 + f.now.getMinutes() * 0.5; w: f.d * 0.076; len: f.d * 0.24; col: f.hourC }
    Hand { angle: f.now.getMinutes() * 6 + f.now.getSeconds() * 0.1; w: f.d * 0.082; len: f.d * 0.36; col: f.minC }
    // the second: a dot on the rim that glides to the next one
    Item {
        visible: f.secs
        anchors.centerIn: parent
        rotation: f.now.getSeconds() * 6
        Behavior on rotation { enabled: f.live; RotationAnimation { duration: 250; direction: RotationAnimation.Clockwise; easing.type: Easing.OutCubic } }
        Rectangle { width: f.d * 0.05; height: width; radius: width / 2; color: f.secC; anchors.horizontalCenter: parent.horizontalCenter; y: -f.d * 0.41 - height / 2 }
    }
    Rectangle { anchors.centerIn: parent; width: f.d * 0.03; height: width; radius: width / 2; color: f.dial }
}
