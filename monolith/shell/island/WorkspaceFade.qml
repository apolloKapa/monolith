import QtQuick
import "../core"

// niri, Animations → Workspace switching → Fade. niri can only slide workspaces up and down, so
// for Fade it switches at once (its own workspace-switch animation is off) and this covers the
// screen with the wallpaper as the switch happens, then fades that away: the new workspace's
// windows fade in over the wallpaper. (The old workspace can't be pictured once niri has
// switched, so it isn't a crossfade.) Drawn in the island's window, under the bar (Island.qml).
// Glitch (niri and Hyprland, the Cyberpunk style's): the same cover, wiped away by a neon front
// sweeping down the screen with a narrow torn band behind it (ui/shaders/wsglitch.frag): rows
// slide sideways and split into red and cyan as they go. Calm on purpose: no flashing blocks,
// nothing that blinks (the menus' glitch, at full screen, strobed).
Item {
    id: fw
    required property string screenName

    // how long it takes, from Speed
    readonly property var sw: Store.get("animations.workspaceSwitch", {}) || {}
    readonly property bool glitch: sw.style === "glitch"
    readonly property string speed: sw.speed || "normal"
    readonly property int ms: glitch ? Theme.fxMs(({ relaxed: 760, normal: 560, fast: 440, fastest: 340 })[speed] || 560)
                                     : Theme.ms(({ relaxed: 420, normal: 300, fast: 220, fastest: 150 })[speed] || 300)

    // the workspace shown on this screen: a new one is a switch (not the first one seen)
    readonly property var shownWs: Niri.workspacesOn(screenName).find(w => w.is_active)
    readonly property var wsId: shownWs ? shownWs.id : null
    property var lastId: null
    property int lastIdx: 0
    onWsIdChanged: {
        const idx = shownWs ? Number(shownWs.idx) || 0 : 0;
        // up (a workspace above: a lower number) or down: the glitch's front goes that way
        tear.dir = idx < lastIdx ? -1 : 1;
        if (lastId !== null && wsId !== null && wsId !== lastId) play();
        lastId = wsId;
        lastIdx = idx;
    }
    function play() {
        if (!Theme.animOn || cover.status !== Image.Ready) return;
        if (glitch) {
            // (not over a fullscreen window: a game switching workspaces would flash)
            if (Niri.fullscreenOn(screenName)) return;
            tear.seed = Math.random() * 97;
            tearAway.restart();
            return;
        }
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
    // Glitch: the cover, wiped by the front (p from 0, whole, to 1, gone)
    ShaderEffect {
        id: tear
        anchors.fill: parent
        visible: tearAway.running
        property var source: cover
        property vector2d itemSize: Qt.vector2d(width, height)
        property real p: 0
        property real seed: 0
        property real dir: 1
        property color red: Theme.danger
        property color cyan: Theme.accent
        fragmentShader: Qt.resolvedUrl("../ui/shaders/wsglitch.frag.qsb")
        NumberAnimation on p { id: tearAway; running: false; from: 0; to: 1; duration: Math.max(1, fw.ms); easing.type: Easing.InOutCubic }
    }
}
