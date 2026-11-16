import QtQuick
import "../core"

// The shell's standard animation, from Theme's motion system: a NumberAnimation whose length and
// curve follow `kind`, scaled by Theme → Effects → speed (and instant with animations off).
//   "standard"  a move or change between two resting states (the default): shortMs, standardCurve
//   "enter"     something arriving: popInMs, enterCurve (fast out, long settle)
//   "exit"      something leaving: popOutMs, exitCurve (gathers, then goes)
//   "fast"      hovers, presses, small state changes: fastMs, standardCurve
// Set `duration` or the easing yourself only where a part needs its own.
NumberAnimation {
    property string kind: "standard"
    duration: kind === "enter" ? Theme.popInMs : kind === "exit" ? Theme.popOutMs : kind === "fast" ? Theme.fastMs : Theme.shortMs
    easing.type: Easing.BezierSpline
    easing.bezierCurve: kind === "enter" ? Theme.enterCurve : kind === "exit" ? Theme.exitCurve : Theme.standardCurve
}
