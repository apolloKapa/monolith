import QtQuick
import "../core"

// niri, Animations → Workspace switching → Fade. niri can only slide workspaces up and down, so
// for Fade it switches at once (its own workspace-switch animation is off) and this covers the
// screen with the wallpaper as the switch happens, then fades that away: the new workspace's
// windows fade in over the wallpaper. (The old workspace can't be pictured once niri has
// switched, so it isn't a crossfade.) Drawn in the island's window, under the bar (Island.qml).
// Glitch (niri and Hyprland, the Cyberpunk style's): the compositor slides the workspaces as
// usual, and this lays light over the slide, going the same way (ui/shaders/wsscan.frag): a neon
// line split into red and cyan, a glow and scanlines behind it, a few streaks of data around it.
// Nothing covers the windows: an earlier version covered them with the wallpaper and wiped that
// away, but it could only start once the switch had happened, so the new workspace flashed
// before the cover came, and the cut under it was a hard one.
Item {
    id: fw
    required property string screenName

    // how long it takes, from Speed
    readonly property var sw: Store.get("animations.workspaceSwitch", {}) || {}
    readonly property bool glitch: sw.style === "glitch"
    readonly property string speed: sw.speed || "normal"
    // (Glitch: about as long as the compositor's slide at that speed)
    readonly property int ms: glitch ? Theme.fxMs(({ relaxed: 640, normal: 470, fast: 370, fastest: 290 })[speed] || 470)
                                     : Theme.ms(({ relaxed: 420, normal: 300, fast: 220, fastest: 150 })[speed] || 300)

    // the workspace shown on this screen: a new one is a switch (not the first one seen)
    readonly property var shownWs: Niri.workspacesOn(screenName).find(w => w.is_active)
    readonly property var wsId: shownWs ? shownWs.id : null
    property var lastId: null
    property int lastIdx: 0
    onWsIdChanged: {
        const idx = shownWs ? Number(shownWs.idx) || 0 : 0;
        // up (a workspace above: a lower number) or down: the glitch's front goes that way
        scan.dir = idx < lastIdx ? -1 : 1;
        if (lastId !== null && wsId !== null && wsId !== lastId) play();
        lastId = wsId;
        lastIdx = idx;
    }
    function play() {
        if (!Theme.animOn) return;
        if (glitch) {
            // (not over a fullscreen window: a game switching workspaces would flash)
            if (Niri.fullscreenOn(screenName)) return;
            scan.seed = Math.random() * 97;
            sweep.restart();
            return;
        }
        if (cover.status !== Image.Ready) return;
        fadeAway.stop();
        cover.opacity = 1;
        fadeAway.start();
    }

    // the wallpaper as the background shows it (a video's still), loaded ahead
    Image {
        id: cover
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0.001
        source: Wall.still(Wall.pathFor(fw.screenName))
        sourceSize: Qt.size(fw.width, fw.height)
        fillMode: Image.PreserveAspectCrop
        cache: true
        NumberAnimation { id: fadeAway; target: cover; property: "opacity"; from: 1; to: 0; duration: fw.ms; easing.type: Easing.OutCubic }
    }
    // Glitch: the light over the slide (p 0 … 1 through it)
    ShaderEffect {
        id: scan
        anchors.fill: parent
        visible: sweep.running
        property vector2d itemSize: Qt.vector2d(width, height)
        property real p: 0
        property real dir: 1
        property real seed: 0
        property color cyan: Theme.accent
        property color red: Theme.danger
        fragmentShader: Qt.resolvedUrl("../ui/shaders/wsscan.frag.qsb")
        NumberAnimation on p { id: sweep; running: false; from: 0; to: 1; duration: Math.max(1, fw.ms); easing.type: Easing.Linear }
    }
}
