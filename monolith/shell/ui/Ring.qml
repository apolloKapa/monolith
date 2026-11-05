import QtQuick
import QtQuick.Shapes
import "../core"

// A progress ring: `value` 0..1 as an accent arc over a faint track, the text in the middle.
Item {
    id: ring
    property real value: 0
    property real thickness: 10
    property color color: Theme.accent
    property string text: ""
    property string caption: ""
    implicitWidth: 120
    implicitHeight: 120
    readonly property real rad: Math.min(width, height) / 2 - thickness / 2
    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.ringTrack
            strokeWidth: ring.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.rad; radiusY: ring.rad; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.color
            strokeWidth: ring.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.rad; radiusY: ring.rad; startAngle: -90; sweepAngle: 360 * Math.max(0.005, ring.shown) }
        }
    }
    Column {
        anchors.centerIn: parent
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ring.text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Math.round(ring.width * 0.2); font.weight: Font.Bold }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: ring.caption; muted: true; font.pixelSize: Theme.sizeSmall }
    }
}
