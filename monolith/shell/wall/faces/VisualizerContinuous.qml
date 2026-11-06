import QtQuick
import "../../core"
import "../../ui"

// Visualiser, continuous: one smooth filled shape riding the music.
// Everything about its look is in its settings (the editor's ⚙); what cava hears is shared.
FaceBase {
    id: f
    readonly property string anchor: String(f.opt("anchor", f.opt("mirror", false) ? "middle" : "bottom"))
    CavaBars {
        anchors.fill: parent
        live: f.live
        preview: !f.live || f.editing
        continuous: true
        bars: Number(f.opt("barCount", 64)) || 64
        mirror: f.anchor === "middle"
        flip: f.anchor === "top"
        minBar: Number(f.opt("barWidth", 6))
        spacing: Number(f.opt("barSpacing", 4))
        minLen: Number(f.opt("restHeight", 3))
        roundness: Number(f.opt("roundness", 1))
        scaleY: Number(f.opt("heightScale", 1))
        fade: f.opt("edgeFade", true) === true
        dynamic: f.opt("dynamicOpacity", true) === true
        fill: Number(f.opt("fillOpacity", 0.9))
        smoothMs: Number(f.opt("smoothing", 70))
        color: f.colorOpt("barColor", Theme.accent)
        color2: f.colorOpt("barColor2", f.colorOpt("barColor", Theme.accent))
    }
}
