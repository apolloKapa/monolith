import QtQuick
import "../../core"
import "../../ui"

// Wellbeing, Cyberpunk: UPLINK. Today's screen time big with its split signal, against the goal as
// segments, and the busiest apps under it.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: 3 }
    readonly property real full: wd.fullAt(String(f.opt("fullAt", "goal")))
    CyberCard {
        id: c; ctx: f.ctx; label: "Uplink // today"
        CyberText { id: t; card: c; width: parent.width; height: parent.height * 0.36; text: wd.clockText(wd.total); color: wd.total > f.full ? c.hot : c.ink }
        CyberBar { y: t.height + c.u * 0.03; card: c; width: parent.width; height: Math.max(4, c.u * 0.05); count: 20; value: f.full > 0 ? wd.total / f.full : 0 }
        Column {
            anchors.bottom: parent.bottom; width: parent.width
            spacing: c.u * 0.015
            Repeater {
                model: wd.top
                Row {
                    required property var modelData
                    width: parent.width; height: Math.max(12, c.u * 0.1)
                    Text { renderType: Text.CurveRendering; width: parent.width * 0.6; height: parent.height; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; text: String(parent.modelData.name || parent.modelData.id || "").toUpperCase(); color: c.neon; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.8 }
                    Text { renderType: Text.CurveRendering; width: parent.width * 0.4; height: parent.height; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; text: wd.fmtShort(parent.modelData.secs || 0); color: c.ink; font.family: c.fam; font.weight: Font.DemiBold; font.pixelSize: parent.height * 0.8 }
                }
            }
        }
    }
}
