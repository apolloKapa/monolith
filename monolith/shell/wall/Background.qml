import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import "../core"

// The wallpaper, on the background layer of every screen. A new one fades in over the old.
PanelWindow {
    id: bg
    required property var modelData
    screen: modelData
    WlrLayershell.namespace: "monolith-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    // a notes widget (and the GitHub widget's name field) takes typing when clicked
    WlrLayershell.keyboardFocus: WidgetLayout.items("desktop").some(i => i.type === "notes" || i.type === "github") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.card

    property bool showA: true
    // what's picked, and what's on screen: they differ for a moment while a live wallpaper changes
    property string target: Wall.pathFor(modelData.name)
    property string current: ""
    readonly property bool video: Wall.isVideo(current)
    readonly property bool gif: Wall.isAnimated(current)
    function isLive(p) { return Wall.isVideo(p) || Wall.isAnimated(p); }
    function showPicture(p) {
        const u = Wall.url(p);
        const shown = showA ? a : b;
        // already the picture underneath (a video was over it): nothing will load, it's ready now
        if (String(shown.source) === u && shown.status === Image.Ready) { Qt.callLater(swap.ready); return; }
        const next = showA ? b : a;
        next.source = u;
    }
    onTargetChanged: {
        if (current === target) return;
        // the first one (settings still loading at start): straight in, nothing to animate from
        if (current === "") { current = target; if (target !== "" && !isLive(target)) showPicture(target); return; }
        // picture to picture: the two layers cross-fade (below). To or from a live one: the old one
        // freezes on its last frame, the new one starts underneath, and once it really plays the
        // frozen frame fades away while the new one settles in from a slight zoom
        if (!isLive(current) && !isLive(target)) { current = target; showPicture(target); return; }
        swap.begin();
    }
    Component.onCompleted: { current = target; if (current !== "" && !isLive(current)) a.source = Wall.url(current); }

    QtObject {
        id: swap
        property bool active: false
        function begin() {
            if (!active) {
                active = true;
                freeze.active = true;       // takes its picture of the old wallpaper on its first frame
                fade.stop();
                freeze.opacity = 1;
                content.scale = 1;
            }
            capture.restart();
        }
        // the new one is on screen: let go of the old frame
        function ready() {
            if (!active || capture.running || fade.running) return;
            settle.stop();
            fade.start();
        }
    }
    // a few frames for the freeze to be drawn, then the new wallpaper goes in under it
    Timer {
        id: capture
        interval: 50
        onTriggered: {
            bg.current = bg.target;
            if (!bg.isLive(bg.current)) bg.showPicture(bg.current);
            settle.restart();
        }
    }
    // never wait forever (a video that won't play, a missing file)
    Timer { id: settle; interval: 2500; onTriggered: { swap.ready(); } }
    ParallelAnimation {
        id: fade
        NumberAnimation { target: freeze; property: "opacity"; to: 0; duration: Theme.ms(900); easing.type: Easing.InOutCubic }
        NumberAnimation { target: content; property: "scale"; from: 1.06; to: 1; duration: Theme.ms(1100); easing.type: Easing.OutCubic }
        onFinished: { freeze.active = false; swap.active = false; content.scale = 1; }
    }

    component Layer: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(bg.width, bg.height)
        Behavior on opacity { NumberAnimation { duration: Theme.ms(700); easing.type: Easing.InOutCubic } }
        // the picture that just faded out lets go of its memory (a whole screen's worth)
        onOpacityChanged: if (opacity === 0 && source !== "") source = ""
    }
    // everything that makes up the wallpaper, in one item the widgets' glass can blur
    Item {
        id: wallLayer
        anchors.fill: parent
        // everything but the frozen frame: what the freeze takes its picture of
        Item {
            id: content
            anchors.fill: parent
            Layer {
                id: a
                opacity: bg.showA ? 1 : 0
                onStatusChanged: {
                    if (status === Image.Ready && !bg.showA && source !== "") bg.showA = true;
                    if (status === Image.Ready && !bg.isLive(bg.current)) swap.ready();
                }
            }
            Layer {
                id: b
                opacity: bg.showA ? 0 : 1
                onStatusChanged: {
                    if (status === Image.Ready && bg.showA && source !== "" && a.source !== source) bg.showA = false;
                    if (status === Image.Ready && !bg.isLive(bg.current)) swap.ready();
                }
            }

            // a video wallpaper: looping, over the pictures (which stay as the backdrop); muted unless
            // Sound is on, and paused while a fullscreen app covers this screen (Wallpaper → Live)
            Video {
                id: vid
                anchors.fill: parent
                visible: bg.video
                source: bg.video ? Wall.url(bg.current) : ""
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: Store.get("wallpaper.liveSound", false) !== true
                volume: 0.6
                autoPlay: true
                // its first frames are showing
                onPositionChanged: if (bg.video && position > 0) swap.ready()
            }
            AnimatedImage {
                anchors.fill: parent
                visible: bg.gif
                source: visible ? Wall.url(bg.current) : ""
                fillMode: Image.PreserveAspectCrop
                playing: visible && !bg.covered
                onStatusChanged: if (status === AnimatedImage.Ready && bg.gif) swap.ready()
            }
        }
        // the old wallpaper's last frame, over the new one until that plays (then it fades away)
        Loader {
            id: freeze
            anchors.fill: parent
            active: false
            sourceComponent: ShaderEffectSource {
                sourceItem: content
                live: false
                hideSource: false
            }
        }
    }
    readonly property bool covered: Store.get("wallpaper.livePause", true) !== false && Niri.focusedFullscreen && Niri.focusedOutput === modelData.name
    onCoveredChanged: if (video) { if (covered) vid.pause(); else vid.play(); }

    // the desktop widgets, only on the first screen for now
    Widgets { screenName: bg.modelData.name; backdrop: wallLayer }
}
