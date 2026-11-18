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
// "<style>'s effect" (style "fx", niri and Hyprland): the same idea for every style with an effect
// of its own (Theme.fxKind): its marks over the slide (ui/shaders/wsfx.frag; Cyberpunk's is Glitch).
// niri only, drawn here because niri can't: Slide and fade (niri slides as usual, and the
// wallpaper comes over the new workspace and fades away, so it fades in as it arrives) and Slide
// sideways (niri switches at once, and the wallpaper over the new workspace is taken away from
// one side to the other with a soft edge, ui/shaders/wswipe.frag: it comes in sideways).
Item {
    id: fw
    required property string screenName

    // how long it takes, from Speed
    readonly property var sw: Store.get("animations.workspaceSwitch", {}) || {}
    readonly property string style: sw.style || "slidevert"
    // the light over the slide: Glitch's, or the style's own (none in a style without an effect)
    readonly property string fx: style === "glitch" ? "cyber" : (style === "fx" ? Theme.fxKind : "")
    readonly property bool glitch: style === "glitch" || style === "fx"
    readonly property int fxNum: ["", "fjord", "doodle", "terminal", "paper", "concrete", "industrial", "liquid", "luxe"].indexOf(fx)
    // Monolith's own, on niri: the wallpaper over the new workspace, faded or wiped away
    readonly property bool wipes: !Niri.hyprland && style === "slide"
    readonly property bool slideFades: !Niri.hyprland && style === "slidefadevert"
    readonly property string speed: sw.speed || "normal"
    // (Glitch: about as long as the compositor's slide at that speed)
    readonly property int ms: glitch ? Theme.fxMs(({ relaxed: 640, normal: 470, fast: 370, fastest: 290 })[speed] || 470)
                    : (wipes || slideFades) ? Theme.ms(({ relaxed: 560, normal: 400, fast: 300, fastest: 220 })[speed] || 400)
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
        fw.way = idx < lastIdx ? -1 : 1;
        if (lastId !== null && wsId !== null && wsId !== lastId) play();
        lastId = wsId;
        lastIdx = idx;
    }
    function play() {
        if (!Theme.animOn) return;
        if (glitch) {
            // (not over a fullscreen window: a game switching workspaces would flash)
            if (fx === "" || Niri.fullscreenOn(screenName)) return;
            scan.seed = Math.random() * 97;
            sweep.restart();
            return;
        }
        if (Niri.hyprland || ["fade", "slide", "slidefadevert"].indexOf(style) === -1) return;
        if (cover.status !== Image.Ready) return;
        fadeAway.stop(); fadeOver.stop(); wipe.stop();
        if (wipes) { cover.opacity = 1; fw.wipeP = 0; wipe.start(); }
        // (over niri's slide: the cover comes in a few frames, not at once, so the slide's first
        // frames don't cut to the wallpaper)
        else if (slideFades) fadeOver.start();
        else { cover.opacity = 1; fadeAway.start(); }
    }
    // up or down the workspaces (-1: to one above), and how far the sideways wipe has got
    property int way: 1
    property real wipeP: 0

    // the wallpaper as the background shows it (a video's still), loaded ahead
    Item {
        anchors.fill: parent
        visible: cover.opacity > 0.001
        // Slide sideways: taken away from one side to the other
        layer.enabled: wipe.running
        layer.effect: ShaderEffect {
            property real p: fw.wipeP
            property real dir: fw.way
            property real soft: 0.09
            fragmentShader: Qt.resolvedUrl("../ui/shaders/wswipe.frag.qsb")
        }
        Image {
            id: cover
            anchors.fill: parent
            opacity: 0
            source: Wall.still(Wall.pathFor(fw.screenName))
            sourceSize: Qt.size(fw.width, fw.height)
            fillMode: Image.PreserveAspectCrop
            cache: true
        }
        NumberAnimation { id: fadeAway; target: cover; property: "opacity"; from: 1; to: 0; duration: fw.ms; easing.type: Easing.OutCubic }
        SequentialAnimation {
            id: fadeOver
            NumberAnimation { target: cover; property: "opacity"; from: 0; to: 0.92; duration: Theme.ms(45) }
            NumberAnimation { target: cover; property: "opacity"; to: 0; duration: fw.ms; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            id: wipe
            NumberAnimation { target: fw; property: "wipeP"; from: 0; to: 1; duration: Math.max(1, fw.ms); easing.type: Easing.OutCubic }
            PropertyAction { target: cover; property: "opacity"; value: 0 }
        }
    }
    // Glitch, or the style's own effect: the light over the slide (p 0 … 1 through it)
    ShaderEffect {
        id: scan
        anchors.fill: parent
        visible: sweep.running
        property vector2d itemSize: Qt.vector2d(width, height)
        property real p: 0
        property real dir: 1
        property real seed: 0
        // (wsscan.frag: Glitch and Cyberpunk)
        property color cyan: Theme.accent
        property color red: Theme.danger
        // (wsfx.frag: every other style's)
        property real kind: Math.max(1, fw.fxNum)
        property color accent: Theme.accent
        property color ink: Theme.text
        fragmentShader: Qt.resolvedUrl(fw.fxNum > 0 ? "../ui/shaders/wsfx.frag.qsb" : "../ui/shaders/wsscan.frag.qsb")
        NumberAnimation on p { id: sweep; running: false; from: 0; to: 1; duration: Math.max(1, fw.ms); easing.type: Easing.Linear }
    }
}
