import QtQuick
import "../"
import "../reusables"

// With the Frame bar style, a popup is a drawer pulled out of the frame: a solid shape behind it
// that reaches the bar and/or the side of the screen when the popup is near them, square where it
// meets the frame and joined to it by rounded "ears". It slides out of the edge it hangs from.
Item {
    id: drawer
    anchors.fill: parent

    // the popup's rectangle (screen coordinates) and how far it is open (0..1)
    property real popupX: 0
    property real popupY: 0
    property real popupW: 0
    property real popupH: 0
    property real progress: 0
    property bool active: false

    readonly property var barCfg: Config.getSetting("bar", {}) || {}
    readonly property bool frameStyle: barCfg.style === "frame"
    readonly property string barPos: barCfg.position || "top"
    readonly property real thickness: Scaler.s(barCfg.frameThickness !== undefined ? Number(barCfg.frameThickness) : 8)
    readonly property real barH: Scaler.s(barCfg.height !== undefined ? Number(barCfg.height) : 40)
    // an auto-hiding bar doesn't hold its edge: the frame runs along it like the others
    readonly property real edgeBar: barCfg.autohide === true ? thickness : barH
    readonly property real topIn: barPos === "top" ? edgeBar : thickness
    readonly property real bottomIn: barPos === "bottom" ? edgeBar : thickness
    readonly property real leftIn: barPos === "left" ? edgeBar : thickness
    readonly property real rightIn: barPos === "right" ? edgeBar : thickness
    readonly property real r: Scaler.s(18)
    readonly property real reach: Scaler.s(80)
    readonly property color color: ThemeBackend.frameColor

    // which frame edges the popup hangs from (it's near them, and not a full-screen panel)
    readonly property bool fullScreen: popupW >= width - leftIn - rightIn - 2 && popupH >= height - topIn - bottomIn - 2
    readonly property bool atTop: !fullScreen && popupY - topIn < reach
    readonly property bool atBottom: !fullScreen && (height - bottomIn) - (popupY + popupH) < reach
    readonly property bool atLeft: !fullScreen && popupX - leftIn < reach
    readonly property bool atRight: !fullScreen && (width - rightIn) - (popupX + popupW) < reach
    readonly property bool attached: atTop || atBottom || atLeft || atRight

    // the drawer, stretched to the edges it hangs from
    readonly property real dL: atLeft ? leftIn : popupX
    readonly property real dT: atTop ? topIn : popupY
    readonly property real dR: atRight ? width - rightIn : popupX + popupW
    readonly property real dB: atBottom ? height - bottomIn : popupY + popupH

    // it slides out of the edge it hangs from (top first, then bottom, left, right)
    readonly property string from: atTop ? "top" : atBottom ? "bottom" : atLeft ? "left" : "right"

    visible: frameStyle && active && attached && progress > 0.001

    Item {
        id: body
        x: drawer.from === "right" ? drawer.dR - width : drawer.dL
        y: drawer.from === "bottom" ? drawer.dB - height : drawer.dT
        width: (drawer.from === "left" || drawer.from === "right") ? (drawer.dR - drawer.dL) * drawer.progress : drawer.dR - drawer.dL
        height: (drawer.from === "top" || drawer.from === "bottom") ? (drawer.dB - drawer.dT) * drawer.progress : drawer.dB - drawer.dT

        Rectangle {
            id: plate
            anchors.fill: parent
            color: drawer.color
            topLeftRadius: (drawer.atTop || drawer.atLeft) ? 0 : drawer.r
            topRightRadius: (drawer.atTop || drawer.atRight) ? 0 : drawer.r
            bottomLeftRadius: (drawer.atBottom || drawer.atLeft) ? 0 : drawer.r
            bottomRightRadius: (drawer.atBottom || drawer.atRight) ? 0 : drawer.r
            // glass in the see-through styles, the same as the popup inside it
            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: plate.topLeftRadius
                topRightRadius: plate.topRightRadius
                bottomLeftRadius: plate.bottomLeftRadius
                bottomRightRadius: plate.bottomRightRadius
                standalone: true
            }
        }

        // ears: concave corners joining the drawer to the frame
        component Ear: ShaderEffect {
            property real cornerIndex: 0
            width: drawer.r
            height: drawer.r
            property vector2d itemSize: Qt.vector2d(width, height)
            property color color: drawer.color
            fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }
        // along the top edge
        Ear { visible: drawer.atTop && !drawer.atLeft; cornerIndex: 1; x: -width; y: 0 }
        Ear { visible: drawer.atTop && !drawer.atRight; cornerIndex: 0; x: body.width; y: 0 }
        // along the bottom edge
        Ear { visible: drawer.atBottom && !drawer.atLeft; cornerIndex: 3; x: -width; y: body.height - height }
        Ear { visible: drawer.atBottom && !drawer.atRight; cornerIndex: 2; x: body.width; y: body.height - height }
        // along the left edge
        Ear { visible: drawer.atLeft && !drawer.atTop; cornerIndex: 2; x: 0; y: -height }
        Ear { visible: drawer.atLeft && !drawer.atBottom; cornerIndex: 0; x: 0; y: body.height }
        // along the right edge
        Ear { visible: drawer.atRight && !drawer.atTop; cornerIndex: 3; x: body.width - width; y: -height }
        Ear { visible: drawer.atRight && !drawer.atBottom; cornerIndex: 1; x: body.width - width; y: body.height }
    }
}
