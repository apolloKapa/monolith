import QtQuick
import "../../core"

// A seek bar whose played part is a sine wave (moving while it plays) and the rest a flat line,
// with a round knob; drag or click to seek. value/to in seconds.
Item {
    id: ws
    property real value: 0
    property real to: 1
    property bool playing: false
    property bool live: true
    property color color: Theme.accent
    signal moved(real v)
    property bool dragging: ma.pressed
    property real dragValue: 0
    readonly property real frac: to > 0 ? Math.max(0, Math.min(1, (dragging ? dragValue : value) / to)) : 0
    property real phase: 0
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 2200; loops: Animation.Infinite; running: ws.live && ws.playing && ws.visible }
    implicitHeight: 16
    Canvas {
        id: cv
        anchors.fill: parent
        property real p: ws.phase
        property real fr: ws.frac
        onPChanged: requestPaint()
        onFrChanged: requestPaint()
        onWidthChanged: requestPaint()
        property color c: ws.color
        onCChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const mid = height / 2, x = width * fr, lw = Math.max(2, height * 0.18), amp = ws.playing ? height * 0.22 : 0;
            g.lineCap = "round";
            g.lineWidth = lw;
            // the rest: flat and faint
            g.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.25);
            g.beginPath(); g.moveTo(Math.min(width - lw / 2, x + lw * 2), mid); g.lineTo(width - lw / 2, mid); g.stroke();
            // played: the wave
            g.strokeStyle = c;
            g.beginPath();
            for (let i = 0; i <= Math.max(1, Math.floor(x)); i += 2) {
                const y = mid + amp * Math.sin(i / Math.max(6, height * 0.9) + p);
                if (i === 0) g.moveTo(lw / 2, y); else g.lineTo(i, y);
            }
            g.stroke();
        }
    }
    Rectangle {
        x: ws.width * ws.frac - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(6, ws.height * 0.45); height: Math.max(ws.height * 0.9, 10); radius: width / 2
        color: ws.color
    }
    MouseArea {
        id: ma
        anchors.fill: parent; anchors.margins: -4
        enabled: ws.live
        cursorShape: Qt.PointingHandCursor
        function at(mx) { return Math.max(0, Math.min(1, (mx - 4) / ws.width)) * ws.to; }
        onPressed: mouse => ws.dragValue = at(mouse.x)
        onPositionChanged: mouse => { if (pressed) ws.dragValue = at(mouse.x); }
        onReleased: mouse => ws.moved(at(mouse.x))
    }
}
