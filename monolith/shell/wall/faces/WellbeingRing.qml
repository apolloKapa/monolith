import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Wellbeing, ring: today's screen time as a (wavy) ring filling up to the daily goal (or the
// hours picked), the time in the middle and the busiest app's icon over it.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: 1 }
    readonly property real d: Math.min(width, height)
    readonly property real full: wd.fullAt(String(f.opt("fullAt", "goal")))
    readonly property bool over: wd.total > full
    Glass { visible: f.opt("ringCard", false) === true; anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Item {
        anchors.centerIn: parent
        width: f.d; height: f.d
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1.5; shadowBlur: 0.35; shadowOpacity: 0.55 }
        WaveRing { anchors.fill: parent; anchors.margins: f.d * 0.04; value: Math.min(1, wd.total / Math.max(1, f.full)); color: f.over ? Theme.danger : f.accentC
                   wavy: f.opt("sineWave", true); thickness: f.opt("lineThickness", 8); live: f.live }
        Column {
            anchors.centerIn: parent
            spacing: f.d * 0.01
            Image {
                visible: f.opt("showTopApp", true) !== false && wd.top.length > 0 && f.d >= 110
                anchors.horizontalCenter: parent.horizontalCenter
                width: f.d * 0.15; height: width; sourceSize: Qt.size(64, 64); asynchronous: true
                source: wd.top.length ? wd.top[0].icon : ""
            }
            Icon { visible: !(f.opt("showTopApp", true) !== false && wd.top.length > 0) && f.d >= 90; anchors.horizontalCenter: parent.horizontalCenter; name: "self_improvement"; size: f.d * 0.15; color: f.subC }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: wd.fmtShort(wd.total); color: f.mainC; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.d * 0.18 }
            Text { visible: f.d >= 100; anchors.horizontalCenter: parent.horizontalCenter
                   text: f.over ? "over by " + wd.fmtShort(wd.total - f.full) : "of " + wd.fmtShort(f.full)
                   color: f.over ? Theme.danger : f.subC; font.family: Theme.fontFamily; font.weight: Font.DemiBold; font.pixelSize: f.d * 0.075 }
        }
    }
    WellOpen { face: f }
}
