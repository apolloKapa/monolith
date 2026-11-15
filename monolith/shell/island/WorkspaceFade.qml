import QtQuick
import "../core"

// niri, Animations → Workspace switching → Fade. niri can only slide workspaces up and down, so
// for Fade it switches at once (its own workspace-switch animation is off) and this covers the
// screen with the wallpaper as the switch happens, then fades that away: the new workspace's
// windows fade in over the wallpaper. (The old workspace can't be pictured once niri has
// switched, so it isn't a crossfade.) Drawn in the island's window, under the bar (Island.qml).
Item {
    id: fw
    required property string screenName

    // how long the fade takes, from Speed
    readonly property string speed: (Store.get("animations.workspaceSwitch", {}) || {}).speed || "normal"
    readonly property int ms: Theme.ms(({ relaxed: 420, normal: 300, fast: 220, fastest: 150 })[speed] || 300)

    // the workspace shown on this screen: a new one is a switch (not the first one seen)
    readonly property var shownWs: Niri.workspacesOn(screenName).find(w => w.is_active)
    readonly property var wsId: shownWs ? shownWs.id : null
    property var lastId: null
    onWsIdChanged: {
        if (lastId !== null && wsId !== null && wsId !== lastId) play();
        lastId = wsId;
    }
    function play() {
        if (!Theme.animOn || cover.status !== Image.Ready) return;
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
}
