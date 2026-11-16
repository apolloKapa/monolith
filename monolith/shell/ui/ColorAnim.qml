import QtQuick
import "../core"

// A colour change (hover, a state's tint), Theme's fast length and standard curve.
ColorAnimation {
    duration: Theme.fastMs
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.standardCurve
}
