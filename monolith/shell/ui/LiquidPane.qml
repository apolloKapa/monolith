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
    // A pane inside something turned by a quarter (the quick access bar on a side edge is the
    // bar's shape rotated): its own x and y run along other screen axes, so it reads a copy of
    // the wallpaper turned the same way (`turned`), and its place is given in that copy. 0 for
    // everything else, which reads the wallpaper as it is.
    property int turn: 0                     // 0, 90, 180 or 270 (clockwise, like Item.rotation)
    function place() {
        if (!lp.Window.window) return;
        const p = lp.mapToItem(null, 0, 0);
        const q = lp.mapToItem(null, 1, 0);
        const dx = q.x - p.x, dy = q.y - p.y;
        const t = Math.abs(dx) >= Math.abs(dy) ? (dx >= 0 ? 0 : 180) : (dy >= 0 ? 90 : 270);
        if (t !== turn) turn = t;
        const w = windowOrigin();
        const X = p.x + w.x, Y = p.y + w.y, W = Screen.width, H = Screen.height;
        // the pane's top left in the (turned) copy of the wallpaper
        const c = t === 0 ? [X, Y] : (t === 90 ? [Y, W - X] : (t === 180 ? [W - X, H - Y] : [H - Y, X]));
        const o = Qt.point(Math.round(c[0]), Math.round(c[1]));
        if (o.x !== origin.x || o.y !== origin.y) origin = o;
    }
    FrameAnimation { running: lp.visible && lp.live; onTriggered: lp.place() }
    Component.onCompleted: place()
    onVisibleChanged: if (visible) place()

    // the pointer: the glass swells and catches the light under it, only while the pointer is over
    // the glass itself. Where it is stays put once it leaves (so the light fades out there) and
    // glides after the pointer instead of jumping with each mouse event
    property real swell: hover.hovered && pointerX >= 0 && pointerY >= 0 && pointerX <= width && pointerY <= height ? 1 : 0
    Behavior on swell { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    property real pointerX: width / 2
    property real pointerY: height / 2
    Behavior on pointerX { enabled: lp.swell > 0.02; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Behavior on pointerY { enabled: lp.swell > 0.02; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    // Where the pointer is: heard by the card the glass is in (its parent), not by the glass. The
    // glass sits under the card's buttons, tiles and sliders, and each of those took the hover:
    // the light faded out over every button and back in over the gaps, and stood still meanwhile.
    // A parent stays hovered over its children, and they keep their own hover.
    HoverHandler { id: hover; parent: lp.parent }
    readonly property point hoverAt: hover.point.position
    function follow() {
        if (!hover.hovered || !lp.parent) return;
        const p = lp.mapFromItem(lp.parent, hoverAt.x, hoverAt.y);    // in the glass's own coordinates
        pointerX = p.x; pointerY = p.y;
    }
    onHoverAtChanged: follow()
    Connections { target: hover; function onHoveredChanged() { lp.follow(); } }

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

    // the wallpaper turned against the pane's quarter turn, so the shader reads it along the
    // pane's own axes (only made while the pane is turned)
    Item {
        id: turnedWall
        readonly property bool on: lp.turn !== 0 && wallTex.status === Image.Ready
        readonly property bool side: lp.turn === 90 || lp.turn === 270
        width: side ? Screen.height : Screen.width
        height: side ? Screen.width : Screen.height
        visible: on
        x: -100000                           // (drawn only into turnedTex, never on screen)
        Image {
            source: turnedWall.on ? wallTex.source : ""
            sourceSize: wallTex.sourceSize
            width: Screen.width; height: Screen.height
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            transformOrigin: Item.TopLeft
            // (screen X,Y lands where the turned pane looks for it: see place())
            rotation: -lp.turn
            x: lp.turn === 270 ? Screen.height : (lp.turn === 180 ? Screen.width : 0)
            y: lp.turn === 90 ? Screen.width : (lp.turn === 180 ? Screen.height : 0)
        }
    }
    ShaderEffectSource {
        id: turnedTex
        sourceItem: turnedWall.on ? turnedWall : null
        hideSource: true
        live: false
        mipmap: true
        smooth: true
        visible: false
        textureSize: Qt.size(Math.max(1, Math.round(turnedWall.width / 2)), Math.max(1, Math.round(turnedWall.height / 2)))
        // (redrawn when the wallpaper or the turn changes)
        Connections { target: turnedWall; function onOnChanged() { turnedTex.scheduleUpdate(); } }
    }
    Connections { target: lp; function onTurnChanged() { turnedTex.scheduleUpdate(); } }

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
        readonly property variant backdrop: turnedWall.on ? turnedTex : wallTex
        readonly property vector2d paneSize: Qt.vector2d(width, height)
        readonly property vector4d corners: Qt.vector4d(lp.topLeft >= 0 ? lp.topLeft : lp.radius, lp.topRight >= 0 ? lp.topRight : lp.radius,
                                                        lp.bottomRight >= 0 ? lp.bottomRight : lp.radius, lp.bottomLeft >= 0 ? lp.bottomLeft : lp.radius)
        readonly property vector2d origin: Qt.vector2d(lp.origin.x, lp.origin.y)
        readonly property vector2d screen: turnedWall.on ? Qt.vector2d(Math.max(1, turnedWall.width), Math.max(1, turnedWall.height))
                                                          : Qt.vector2d(Math.max(1, Screen.width), Math.max(1, Screen.height))
        readonly property real bezel: lp.bezel
        readonly property real depth: lp.depth
        readonly property real index: lp.index
        readonly property real prism: lp.prism
        readonly property real frost: lp.frost
        readonly property real shine: lp.shine
        readonly property real vivid: lp.vivid
        readonly property color tint: lp.tint
        readonly property real tintMix: lp.tintMix
        readonly property vector2d pointer: Qt.vector2d(lp.pointerX, lp.pointerY)
        readonly property real swell: lp.swell
        fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb")
    }
}
