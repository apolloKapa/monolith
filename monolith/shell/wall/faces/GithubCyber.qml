import QtQuick
import "../../core"
import "../../ui"

// GitHub, Cyberpunk: COMMITS. The year's total big, and the last weeks of contributions as a grid
// of squares lit in cyan (the busiest days pink).
FaceBase {
    id: f
    property bool held: false
    readonly property bool want: f.live && f.visible
    onWantChanged: { if (want && !held) { GitHub.hold(); held = true; } else if (!want && held) { GitHub.release(); held = false; } }
    Component.onCompleted: if (want) { GitHub.hold(); held = true; }
    Component.onDestruction: if (held) GitHub.release()
    CyberCard {
        id: c; ctx: f.ctx; label: "Commits // " + (GitHub.user || "set a user")
        CyberText { id: total; card: c; width: parent.width * 0.4; height: parent.height * 0.42; text: String(GitHub.total || 0) }
        Text { anchors.left: total.right; anchors.leftMargin: c.u * 0.04; anchors.verticalCenter: total.verticalCenter; renderType: Text.CurveRendering; text: "THIS YEAR"; color: c.neon; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: Math.max(9, c.u * 0.1) }
        Grid {
            id: g
            anchors.bottom: parent.bottom
            width: parent.width; height: parent.height * 0.5
            rows: 7; flow: Grid.TopToBottom
            readonly property int weeks: Math.max(4, Math.floor(width / (height / 7)))
            readonly property var days: GitHub.days.slice(Math.max(0, GitHub.days.length - weeks * 7))
            spacing: Math.max(1, height / 7 * 0.18)
            Repeater {
                model: g.days.length
                Rectangle {
                    required property int index
                    readonly property var d: g.days[index]
                    width: (g.height - g.spacing * 6) / 7; height: width
                    color: !d || d.level <= 0 ? Qt.alpha(c.edge, 0.1) : (d.level >= 4 ? c.hot : Qt.alpha(c.edge, 0.3 + 0.2 * d.level))
                }
            }
        }
    }
}
