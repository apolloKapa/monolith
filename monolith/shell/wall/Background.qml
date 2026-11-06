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
    property string target: Wall.pathFor(modelData.name)
    readonly property bool video: Wall.isVideo(target)
    onTargetChanged: {
        if (video || Wall.isAnimated(target)) return;
        const next = showA ? b : a;
        next.source = Wall.url(target);
    }
    Component.onCompleted: if (!video && !Wall.isAnimated(target)) a.source = Wall.url(target)

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
        Layer {
            id: a
            opacity: bg.showA ? 1 : 0
            onStatusChanged: if (status === Image.Ready && !bg.showA && source !== "") bg.showA = true
        }
        Layer {
            id: b
            opacity: bg.showA ? 0 : 1
            onStatusChanged: if (status === Image.Ready && bg.showA && source !== "" && a.source !== source) bg.showA = false
        }

        // a video wallpaper: muted, looping, over the pictures (which stay as the backdrop)
        Video {
            anchors.fill: parent
            visible: bg.video
            source: bg.video ? Wall.url(bg.target) : ""
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
        }
        AnimatedImage {
            anchors.fill: parent
            visible: Wall.isAnimated(bg.target)
            source: visible ? Wall.url(bg.target) : ""
            fillMode: Image.PreserveAspectCrop
            playing: visible
        }
    }

    // the desktop widgets, only on the first screen for now
    Widgets { screenName: bg.modelData.name; backdrop: wallLayer }
}
