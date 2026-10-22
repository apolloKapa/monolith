import QtQuick
import "../../"

// Monolith's surface effects, laid over a panel's background (under its content): grain,
// corner marks and an edge light (Theme -> Effects). WallpaperBlur creates one next to
// itself for every outer panel, so the bar, dock, launcher, popups, notifications and
// widgets all get them.
Item {
    id: fx
    property Item target: null
    readonly property real r: target ? Math.max(target.topLeftRadius, target.topRightRadius) : 0
    readonly property bool big: width > Scaler.s(60) && height > Scaler.s(30)

    x: target ? target.x : 0
    y: target ? target.y : 0
    width: target ? target.width : 0
    height: target ? target.height : 0
    z: target ? target.z : -1
    visible: !!target && target.surfaceEnabled && !target.earsOnly && target.nestLevel === 0 && target.parentVisible && big

    // ── grain ──
    ShaderEffect {
        anchors.fill: parent
        visible: ThemeBackend.fxGrain
        property vector2d itemSize: Qt.vector2d(width, height)
        property real radius: fx.r
        property real amount: ThemeBackend.liquidGlass ? 0.05 : 0.07
        property real seed: 0
        fragmentShader: Caching.monolithDir ? ("file://" + Caching.monolithDir + "/assets/shaders/effects/surface_grain.frag.qsb") : ""
    }

    // ── edge light: a soft line along the top edge ──
    Rectangle {
        visible: ThemeBackend.fxEdge && !ThemeBackend.outlined
        x: fx.r * 0.6
        y: 0
        width: parent.width - fx.r * 1.2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(ThemeBackend.text, 0.22) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── marks: accent brackets just inside the four corners ──
    Repeater {
        model: ThemeBackend.fxMarks && fx.width > Scaler.s(140) && fx.height > Scaler.s(70) ? 4 : 0
        Item {
            required property int index
            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index >= 2
            readonly property real inset: Math.max(Scaler.s(6), fx.r * 0.42)
            readonly property real len: Scaler.s(9)
            readonly property real th: Math.max(1, Scaler.s(1.5))
            x: atRight ? fx.width - inset - len : inset
            y: atBottom ? fx.height - inset - len : inset
            width: len
            height: len
            opacity: 0.85
            Rectangle {
                x: 0
                y: parent.atBottom ? parent.len - parent.th : 0
                width: parent.len
                height: parent.th
                color: ThemeBackend.mauve
            }
            Rectangle {
                x: parent.atRight ? parent.len - parent.th : 0
                y: 0
                width: parent.th
                height: parent.len
                color: ThemeBackend.mauve
            }
        }
    }
}
