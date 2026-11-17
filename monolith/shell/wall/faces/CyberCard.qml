import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// The panel under every Cyberpunk look (like DotCard for the Dot ones): a dark HUD panel with two
// corners cut and a neon edge, a yellow tick along the top and a cyan bracket at the bottom left,
// faint scanlines, and a yellow label block (`label`) at the top left. It hands its looks the
// colours (neon: yellow, edge: cyan, hot: pink, ink: the text), the type (Rajdhani when there)
// and a unit (`u`) that keeps everything in proportion. What goes on it goes in `body`, inside
// the frame and under the label.
Item {
    id: cc
    anchors.fill: parent
    property var ctx: null
    property string label: ""
    property bool showLabel: label !== ""
    default property alias content: body.data
    readonly property alias body: body
    function opt(k, d) { return ctx ? ctx.opt(k, d) : d; }
    function col(k, d) {
        const v = String(opt(k, "") || "");
        if (v === "") return d;
        if (v === "accent") return Theme.accent;
        if (v === "text") return Theme.text;
        return /^#[0-9a-fA-F]{6}$/.test(v) ? v : d;
    }
    readonly property color neon: col("mainColor", Theme.c("yellow", "#fcee0a"))
    readonly property color edge: col("accentColor", Theme.c("teal", "#00f0ff"))
    readonly property color hot: Theme.c("pink", "#ff2a6d")
    readonly property color ink: "#e8f6ff"
    readonly property color dim: Qt.rgba(0.75, 0.9, 1, 0.5)
    readonly property string fam: Qt.fontFamilies().indexOf("Rajdhani") !== -1 ? "Rajdhani" : Theme.fontFamily
    readonly property bool framed: opt("frame", true) !== false
    readonly property real u: Math.max(40, Math.min(width, height))
    readonly property real cut: Math.min(width, height) * 0.12
    readonly property real line: Math.max(1, u * 0.008)

    Shape {
        anchors.fill: parent
        visible: cc.framed
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Qt.rgba(0.02, 0.02, 0.05, Math.max(0, Math.min(1, Number(cc.opt("bgOpacity", 0.7)))))
            strokeColor: Qt.alpha(cc.edge, 0.85)
            strokeWidth: cc.line
            joinStyle: ShapePath.MiterJoin
            startX: cc.cut; startY: 0
            PathLine { x: cc.width; y: 0 }
            PathLine { x: cc.width; y: cc.height - cc.cut }
            PathLine { x: cc.width - cc.cut; y: cc.height }
            PathLine { x: 0; y: cc.height }
            PathLine { x: 0; y: cc.cut }
            PathLine { x: cc.cut; y: 0 }
        }
    }
    // scanlines, faint, inside the frame
    Item {
        anchors.fill: parent
        anchors.margins: cc.line
        visible: cc.framed
        clip: true
        opacity: 0.06
        Image { anchors.fill: parent; source: "../../ui/scan.png"; fillMode: Image.Tile; smooth: false }
    }
    Rectangle { visible: cc.framed; x: cc.width * 0.62; y: 0; width: cc.u * 0.28; height: Math.max(2, cc.u * 0.018); color: cc.neon }
    Rectangle { visible: cc.framed; x: 0; y: cc.height - height; width: cc.u * 0.16; height: Math.max(2, cc.u * 0.018); color: cc.edge }
    Rectangle { visible: cc.framed; x: 0; y: cc.height - cc.u * 0.2; width: Math.max(2, cc.u * 0.018); height: cc.u * 0.2; color: cc.edge }
    // the label block
    Rectangle {
        id: tag
        visible: cc.showLabel
        x: cc.cut + cc.u * 0.04; y: cc.u * 0.07
        width: tagText.implicitWidth + cc.u * 0.08; height: Math.max(14, cc.u * 0.12)
        color: cc.neon
        Text {
            id: tagText
            renderType: Text.CurveRendering
            anchors.centerIn: parent
            text: cc.label.toUpperCase()
            color: "#0a0a12"
            font.family: cc.fam; font.weight: Font.Bold
            font.pixelSize: Math.max(9, parent.height * 0.72)
            font.letterSpacing: 1
        }
    }
    Item {
        id: body
        x: cc.cut * 0.6 + cc.u * 0.04
        y: cc.showLabel ? tag.y + tag.height + cc.u * 0.05 : cc.u * 0.07
        width: cc.width - x - cc.u * 0.08
        height: cc.height - y - cc.u * 0.08
    }
}
