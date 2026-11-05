import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// A drawing pad: draw with the mouse, pick a colour and size, clear, or save it as a picture
// (to ~/Pictures, and copied).
ColumnLayout {
    id: d
    spacing: 8
    property color ink: Theme.accent
    property real size: 4
    property var strokes: []        // [{ c, s, pts: [x, y, x, y, …] }]
    Label { text: "Draw"; strong: true; font.pixelSize: Theme.sizeTitle }
    Rectangle {
        id: pad
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.corner(80, 4)
        color: Theme.container
        clip: true
        Canvas {
            id: cv
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.lineCap = "round"; g.lineJoin = "round";
                for (const s of d.strokes) {
                    if (s.pts.length < 2) continue;
                    g.strokeStyle = s.c; g.lineWidth = s.s;
                    g.beginPath(); g.moveTo(s.pts[0], s.pts[1]);
                    for (let i = 2; i < s.pts.length; i += 2) g.lineTo(s.pts[i], s.pts[i + 1]);
                    if (s.pts.length === 2) g.lineTo(s.pts[0] + 0.1, s.pts[1]);
                    g.stroke();
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: mouse => { d.strokes = d.strokes.concat([{ c: String(d.ink), s: d.size, pts: [mouse.x, mouse.y] }]); cv.requestPaint(); }
            onPositionChanged: mouse => { if (!pressed) return; const s = d.strokes[d.strokes.length - 1]; s.pts.push(mouse.x, mouse.y); cv.requestPaint(); }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [Theme.accent, Theme.text, Theme.danger, "#f2c230", "#3a9e3a", "#2f6fdb"]
            Rectangle {
                required property var modelData
                width: 24; height: 24; radius: 12
                color: modelData
                border.width: d.ink === Qt.color(modelData) ? 3 : 1
                border.color: d.ink === Qt.color(modelData) ? Theme.text : Theme.ringTrack
                MouseArea { anchors.fill: parent; onClicked: d.ink = parent.modelData }
            }
        }
        Item { Layout.fillWidth: true }
        Pressable { width: 34; height: 34; color: Theme.control; onClicked: d.size = d.size > 10 ? 2 : d.size + 4; Label { anchors.centerIn: parent; text: d.size; font.pixelSize: Theme.sizeSmall } }
        Pressable { width: 34; height: 34; color: Theme.control; onClicked: { d.strokes = d.strokes.slice(0, -1); cv.requestPaint(); } Icon { anchors.centerIn: parent; name: "undo"; size: 18 } }
        Pressable { width: 34; height: 34; color: Theme.control; onClicked: { d.strokes = []; cv.requestPaint(); } Icon { anchors.centerIn: parent; name: "delete"; size: 18 } }
        Pressable {
            width: 34; height: 34; color: Theme.accent; ink: Theme.onAccent
            onClicked: {
                const f = Quickshell.env("HOME") + "/Pictures/Drawing_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".png";
                pad.grabToImage(r => { r.saveToFile(f); Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"; notify-send -a Monolith 'Drawing saved' \"$1\"", "_", f]); });
            }
            Icon { anchors.centerIn: parent; name: "save"; size: 18; color: Theme.onAccent }
        }
    }
}
