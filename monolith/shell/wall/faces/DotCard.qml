import QtQuick
import "../../core"

// The card under every Dot look: a rounded square in flat black or off-white (or glass, or
// nothing), with a hairline edge; it hands its looks the ink, the dim ink and the red accent.
// Its Card colour (dark | light) and Background (blur | normal = Opacity | clear); earlier
// versions had glass and clear as tones, which still mean Blur and Clear when no Background is set.
Item {
    id: dc
    anchors.fill: parent
    property var ctx: null
    function opt(k, d) { return ctx ? ctx.opt(k, d) : d; }
    readonly property string tone: String(opt("dotTone", "dark"))
    readonly property bool light: tone === "light"
    readonly property string bg: String(opt("background", tone === "glass" ? "blur" : (tone === "clear" ? "clear" : "normal")))
    readonly property real radius: Math.min(width, height) * 0.16
    // the ink: white on dark, near-black on light; the accent a signal red unless you pick one
    readonly property color ink: light ? "#111111" : "#f4f4f4"
    readonly property color dim: light ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(1, 1, 1, 0.42)
    readonly property color off: light ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.07)
    readonly property color accent: {
        const v = String(opt("accentColor", "") || "");
        return /^#[0-9a-fA-F]{6}$/.test(v) ? v : (v === "accent" ? Theme.accent : "#d71921");
    }

    Glass { visible: dc.bg === "blur"; anchors.fill: parent; ctx: dc.ctx; radius: dc.radius; defaultMode: "blur"; tintColor: dc.light ? "#ececea" : Theme.m("surface_container", Theme.container) }
    Rectangle {
        readonly property real k: Math.max(0, Math.min(1, Number(dc.opt("bgOpacity", 1))))
        visible: dc.bg === "normal"
        anchors.fill: parent
        radius: dc.radius
        color: Qt.alpha(dc.light ? "#ececea" : "#0b0b0b", k)
        opacity: Math.min(1, k * 4)
        border.width: 1
        border.color: dc.light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    }
}
