import QtQuick
import QtQuick.Window
import "../core"

// A pane of liquid glass (shaders/glass.frag): put it inside a card (it fills it, under the
// card's content) and give it the card's corner radius. What it bends is the screen's
// wallpaper: a still copy of it (the video's first frame for a video wallpaper) loaded once for
// the screen, sampled where the pane sits on it. Windows behind a pane aren't seen through it.
//
// Where the pane is on the screen: where it is in its window, plus where the window is on the
// screen. Full-screen windows (the island, menus, drops) are at 0,0; a window that isn't (the
// dock, corner pop-ups) sets `glassOrigin` (a point) on an item the pane sits inside.
Item {
    id: lp
    property real radius: 0
    // per corner (top left, top right, bottom right, bottom left); -1 = `radius`
    property real topLeft: -1
    property real topRight: -1
    property real bottomRight: -1
    property real bottomLeft: -1
    property real bezel: Math.max(6, Math.min(28, Math.min(width, height) * 0.3))
    property real depth: bezel * 0.75
    property real index: 1.5
    property real prism: 0.12
    property real frost: 1.6
    property real shine: 0.5
    property real vivid: 1.2
    property color tint: Theme.dark ? "#101014" : "#ffffff"
    property real tintMix: Theme.dark ? 0.22 : 0.18
    property bool live: true                       // follow the pane as it moves (every frame)

    // the screen and its wallpaper
    readonly property string screenName: Screen.name
    readonly property string wallPath: { const p = Wall.pathFor(screenName); return Wall.isVideo(p) ? Wall.thumb(p) : p; }
    // where its window is on the screen (see above)
    function windowOrigin() {
        for (let it = lp.parent; it; it = it.parent)
            if (it.glassOrigin !== undefined) return it.glassOrigin;
        return Qt.point(0, 0);
    }
    property point origin: Qt.point(0, 0)
    function place() {
        if (!lp.Window.window) return;
        const p = lp.mapToItem(null, 0, 0);
        const w = windowOrigin();
        const o = Qt.point(Math.round(p.x + w.x), Math.round(p.y + w.y));
        if (o.x !== origin.x || o.y !== origin.y) origin = o;
    }
    FrameAnimation { running: lp.visible && lp.live; onTriggered: lp.place() }
    Component.onCompleted: place()
    onVisibleChanged: if (visible) place()

    // the pointer: the glass swells under it
    property real swell: hover.hovered ? 1 : 0
    Behavior on swell { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    HoverHandler { id: hover }

    Image {
        id: wallTex
        visible: false
        source: lp.wallPath !== "" ? Wall.url(lp.wallPath) : ""
        // half the screen's size is plenty: it's bent and frosted; cropped like the wallpaper
        sourceSize: Qt.size(Math.max(1, Math.round(Screen.width / 2)), Math.max(1, Math.round(Screen.height / 2)))
        fillMode: Image.PreserveAspectCrop
        mipmap: true
        smooth: true
        asynchronous: true
        cache: true
    }

    // until the wallpaper has loaded (or when there's none): a plain tinted pane
    Rectangle {
        anchors.fill: parent
        visible: wallTex.status !== Image.Ready
        radius: lp.radius
        color: Qt.alpha(Theme.frame, 0.85)
    }

    ShaderEffect {
        anchors.fill: parent
        visible: wallTex.status === Image.Ready
        readonly property variant backdrop: wallTex
        readonly property vector2d paneSize: Qt.vector2d(width, height)
        readonly property vector4d corners: Qt.vector4d(lp.topLeft >= 0 ? lp.topLeft : lp.radius, lp.topRight >= 0 ? lp.topRight : lp.radius,
                                                        lp.bottomRight >= 0 ? lp.bottomRight : lp.radius, lp.bottomLeft >= 0 ? lp.bottomLeft : lp.radius)
        readonly property vector2d origin: Qt.vector2d(lp.origin.x, lp.origin.y)
        readonly property vector2d screen: Qt.vector2d(Math.max(1, Screen.width), Math.max(1, Screen.height))
        readonly property real bezel: lp.bezel
        readonly property real depth: lp.depth
        readonly property real index: lp.index
        readonly property real prism: lp.prism
        readonly property real frost: lp.frost
        readonly property real shine: lp.shine
        readonly property real vivid: lp.vivid
        readonly property color tint: lp.tint
        readonly property real tintMix: lp.tintMix
        readonly property vector2d pointer: Qt.vector2d(hover.point.position.x, hover.point.position.y)
        readonly property real swell: lp.swell
        fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb")
    }
}
