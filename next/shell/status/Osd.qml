import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../core"
import "../ui"

// The OSD: a pill near the bottom when the volume, mute or keyboard layout changes.
PanelWindow {
    id: osd
    required property var modelData
    screen: modelData
    readonly property bool here: Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]

    WlrLayershell.namespace: "monolith-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    readonly property bool atTop: Store.get("osd.position", "bottom") === "top"
    anchors { bottom: !atTop; top: atTop }
    margins { bottom: 110; top: 90 }
    implicitWidth: 340
    implicitHeight: 60
    color: "transparent"
    mask: Region {}
    visible: here && (hold.running || pill.opacity > 0.01)

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property string kind: "volume"
    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: osd.ready = true }   // not on startup

    function flash(k) { if (!ready || Store.get("osd.enabled", true) === false || Store.get("osd.show." + k, true) === false) return; kind = k; hold.restart(); }
    Connections {
        target: osd.audio
        function onVolumeChanged() { osd.flash("volume"); }
        function onMutedChanged() { osd.flash("volume"); }
    }
    Connections {
        target: Niri
        function onLayoutIndexChanged() { osd.flash("layout"); }
    }
    Timer { id: hold; interval: 1400 }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.corner(height, 8)
        color: Theme.card
        border.width: 1
        border.color: Theme.hairline
        opacity: hold.running ? 1 : 0
        scale: hold.running ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: hold.running ? 180 : 260 } }
        Behavior on scale { NumberAnimation { duration: hold.running ? Theme.enterMs : Theme.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: hold.running ? Theme.enterCurve : Theme.exitCurve } }

        Bubble {
            id: ob
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            on: true
            icon: osd.kind === "layout" ? "keyboard" : (osd.audio && (osd.audio.muted || osd.audio.volume === 0) ? "volume_off" : "volume_up")
        }
        Label {
            visible: osd.kind === "layout"
            anchors.left: ob.right; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Niri.layoutName
            strong: true
        }
        Item {
            visible: osd.kind === "volume"
            anchors.left: ob.right; anchors.leftMargin: 14
            anchors.right: pct.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            Rectangle { anchors.fill: parent; radius: 4; color: Theme.control }
            Rectangle {
                width: parent.width * Math.min(1, osd.audio ? osd.audio.volume : 0)
                height: parent.height
                radius: 4
                color: osd.audio && osd.audio.muted ? Theme.faint : Theme.accent
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
        Label {
            id: pct
            visible: osd.kind === "volume"
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: osd.audio ? Math.round(osd.audio.volume * 100) + "%" : ""
            font.pixelSize: Theme.sizeSmall
        }
    }
}
