import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import "../core"
import "../ui"

// The OSD: a pill near the bottom when the volume, mute or keyboard layout changes.
PanelWindow {
    id: osd
    required property var modelData
    screen: modelData
    // on the screen you're on
    readonly property bool here: Niri.focusedOutput !== "" ? Niri.focusedOutput === modelData.name : (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0])

    WlrLayershell.namespace: "monolith-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // where (Settings → Notifications → Volume & key pop-up): across and down, as a share of
    // the screen; across or upright
    readonly property bool vertical: Store.get("osd.orientation", "horizontal") === "vertical"
    readonly property real px: Number(Store.get("osd.x", 0.5))
    readonly property real py: Number(Store.get("osd.y", Store.get("osd.position", "bottom") === "top" ? 0.08 : 0.88))
    anchors { left: true; top: true }
    margins { left: Math.round(px * (modelData.width - implicitWidth)); top: Math.round(py * (modelData.height - implicitHeight)) }
    implicitWidth: vertical ? 64 : 340
    implicitHeight: vertical ? 300 : 60
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
        function onVolumeChanged() { osd.flash("volume"); if (osd.here) Sounds.play("tick"); }
        function onMutedChanged() { osd.flash("volume"); }
    }
    Connections {
        target: Niri
        function onLayoutIndexChanged() { osd.flash("layout"); }
    }
    Timer { id: hold; interval: 1400 }

    // Caps Lock and Num Lock (the keyboard's lights), and airplane mode (every radio off)
    property string capsPath: ""
    property string numPath: ""
    property int caps: -1
    property int num: -1
    property int air: -1
    Process {
        running: osd.here
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null | head -1; ls -d /sys/class/leds/*::numlock 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: { const l = text.trim().split("\n"); osd.capsPath = l[0] || ""; osd.numPath = l[1] || ""; } }
    }
    FileView { id: capsF; path: osd.capsPath !== "" ? osd.capsPath + "/brightness" : ""; blockLoading: true; printErrors: false }
    FileView { id: numF; path: osd.numPath !== "" ? osd.numPath + "/brightness" : ""; blockLoading: true; printErrors: false }
    Process {
        id: rfk
        command: ["sh", "-c", "set -- /sys/class/rfkill/rfkill*/soft; [ -e \"$1\" ] || exit 0; for f; do [ \"$(cat $f)\" = 0 ] && { echo 0; exit; }; done; echo 1"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); if (!isNaN(v)) { if (osd.air !== -1 && v !== osd.air) { osd.air = v; osd.flash("airplane"); } else osd.air = v; } } }
    }
    function check(f, old) {
        f.reload();
        const v = parseInt(f.text());
        return isNaN(v) ? old : (v > 0 ? 1 : 0);
    }
    Timer {
        interval: 250; repeat: true; running: osd.here && Store.get("osd.enabled", true) !== false
        onTriggered: {
            if (osd.capsPath !== "") { const c = osd.check(capsF, osd.caps); if (osd.caps !== -1 && c !== osd.caps) { osd.caps = c; osd.flash("caps"); } else osd.caps = c; }
            if (osd.numPath !== "") { const n = osd.check(numF, osd.num); if (osd.num !== -1 && n !== osd.num) { osd.num = n; osd.flash("num"); } else osd.num = n; }
        }
    }
    Timer { interval: 2000; repeat: true; running: osd.here && Store.get("osd.enabled", true) !== false; onTriggered: rfk.running = true }

    Rectangle {
        id: pill
        anchors.fill: parent
        // upright: the level as a bar filling upwards, the number under it
        Item {
            visible: osd.vertical
            anchors.horizontalCenter: parent.horizontalCenter
            y: 64; width: 10; height: parent.height - 64 - 40
            Rectangle { anchors.fill: parent; radius: 5; color: Theme.control }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; radius: 5
                height: osd.kind === "volume" ? parent.height * Math.min(1, osd.audio ? osd.audio.volume : 0) : parent.height
                color: osd.audio && osd.audio.muted && osd.kind === "volume" ? Theme.faint : Theme.accent
                Behavior on height { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
            }
        }
        Label {
            visible: osd.vertical
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            text: osd.kind === "volume" ? (osd.audio ? Math.round(osd.audio.volume * 100) : "") : ({ caps: osd.caps === 1 ? "On" : "Off", num: osd.num === 1 ? "On" : "Off", airplane: osd.air === 1 ? "On" : "Off" })[osd.kind] || Niri.layoutName.substring(0, 2).toUpperCase()
            font.pixelSize: Theme.sizeSmall; strong: true
        }
        radius: Theme.corner(height, 8)
        color: Theme.card
        border.width: 1
        border.color: Theme.hairline
        opacity: hold.running ? 1 : 0
        scale: hold.running ? 1 : Theme.popScale
        Behavior on opacity { NumberAnimation { duration: hold.running ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: hold.running ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: hold.running ? Theme.enterCurve : Theme.exitCurve } }

        Bubble {
            id: ob
            x: osd.vertical ? (parent.width - width) / 2 : 10
            y: osd.vertical ? 12 : (parent.height - height) / 2
            size: 40
            on: true
            icon: ({ layout: "keyboard", caps: "keyboard_capslock", num: "pin", airplane: osd.air === 1 ? "airplanemode_active" : "airplanemode_inactive" })[osd.kind]
                || (osd.audio && (osd.audio.muted || osd.audio.volume === 0) ? "volume_off" : "volume_up")
        }
        Label {
            visible: osd.kind !== "volume" && !osd.vertical
            anchors.left: ob.right; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: osd.kind === "layout" ? Niri.layoutName
                : (osd.kind === "caps" ? "Caps Lock " + (osd.caps === 1 ? "on" : "off")
                : (osd.kind === "num" ? "Num Lock " + (osd.num === 1 ? "on" : "off")
                : "Airplane mode " + (osd.air === 1 ? "on" : "off")))
            strong: true
        }
        Item {
            visible: osd.kind === "volume" && !osd.vertical
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
                Behavior on width { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
            }
        }
        Label {
            id: pct
            visible: osd.kind === "volume" && !osd.vertical
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: osd.audio ? Math.round(osd.audio.volume * 100) + "%" : ""
            font.pixelSize: Theme.sizeSmall
        }
    }

    // blur behind it (Theme → Effects), shaped like it
    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        // (only while it is fully there: the blur cannot fade out with it)
        // (worked out from the card's size and zoom, not taken from the card: an item's region
        // was read once while the card was still zoomed in from 94 % and never followed the zoom,
        // so the blur sat off the card, short of it on one side and past it on the other)
        readonly property bool on: osd.visible && hold.running
        width: on ? Math.round(pill.width * pill.scale) : 0
        height: on ? Math.round(pill.height * pill.scale) : 0
        x: Math.round((pill.width - width) / 2)
        y: Math.round((pill.height - height) / 2)
        radius: pill.radius * pill.scale
    }
}
