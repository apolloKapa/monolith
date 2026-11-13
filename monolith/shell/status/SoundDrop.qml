import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../core"
import "../ui"
import "../wall/faces" as Faces

// The sound dropdown: a click on the bar's volume drops a small card out right under it. On top
// the device you hear, live bars of what it plays and its big volume bar; under it the other
// devices to switch to, the microphone, and each app making sound with its own volume. A click
// anywhere else, the volume again or Esc puts it away; "More" opens the full Sound menu.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "sound" && !HubState.open

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sinkMuted: !!(sink && sink.audio && sink.audio.muted)
    readonly property bool micMuted: !!(source && source.audio && source.audio.muted)
    PwObjectTracker { objects: dd.nodes }

    function nameOf(n) {
        if (!n) return "";
        if (n.isStream) return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }
    function iconOf(n) {
        if (!n) return "volume_off";
        const d = (n.description || "").toLowerCase();
        return d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 ? "headphones" : (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1 ? "tv" : "speaker");
    }
    function volIcon(muted, v) { return muted || v === 0 ? "volume_off" : (v < 0.4 ? "volume_down" : "volume_up"); }

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-sound"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // open, the whole screen takes the mouse: a click off the card closes it
    mask: Region { item: dd.shown ? full : null }
    Item { id: full; anchors.fill: parent }

    MouseArea { anchors.fill: parent; onClicked: HubState.closeDrop() }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: HubState.closeDrop()
    }
    onShownChanged: if (shown) keys.forceActiveFocus()

    SmoothRect {
        id: card
        width: 460
        height: Math.min(dd.height - 80, col.implicitHeight + 2 * card.pad)
        Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        // room inside: more when the corners are very round (Theme.inset)
        readonly property real pad: Theme.inset(radius, 12)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        clip: true
        // drops down from the bar with a little zoom, and goes back up the same way
        opacity: dd.shown ? 1 : 0
        scale: dd.shown ? 1 : Theme.popScale
        transformOrigin: Theme.dropOrigin
        Behavior on opacity { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dd.shown ? Theme.enterCurve : Theme.exitCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }

        Flickable {
            id: scroller
            SmoothWheel {}
            x: card.pad; y: card.pad
            width: card.width - 2 * card.pad
            height: card.height - 2 * card.pad
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            ColumnLayout {
                id: col
                width: scroller.width
                spacing: 10

                // ── the device you hear: name, live bars, mute, the big volume bar ──
                Rectangle {
                    id: hero
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: Theme.corner(80, 10)
                    color: Theme.selected
                    border.width: Theme.outlineW
                    border.color: Theme.outlineColor
                    readonly property real vol: dd.sink && dd.sink.audio ? dd.sink.audio.volume : 0
                    Bubble { id: hb; x: 16; y: 16; size: 50; icon: dd.iconOf(dd.sink); on: true }
                    Column {
                        anchors.left: hb.right; anchors.leftMargin: 12
                        anchors.right: bars.left; anchors.rightMargin: 10
                        anchors.verticalCenter: hb.verticalCenter
                        spacing: 2
                        Label { width: parent.width; elide: Text.ElideRight; text: dd.sink ? dd.nameOf(dd.sink) : "No output"; strong: true }
                        Label {
                            width: parent.width; muted: true; font.pixelSize: Theme.sizeSmall
                            text: dd.sinkMuted ? "Muted" : "Playing here"
                        }
                    }
                    // what's coming out of it, live
                    Faces.CavaBars {
                        id: bars
                        anchors.right: muteBtn.left; anchors.rightMargin: 12
                        anchors.verticalCenter: hb.verticalCenter
                        width: 72; height: 28
                        count: 12; spacing: 3; minLen: 3
                        live: dd.shown && !dd.sinkMuted
                        opacity: dd.sinkMuted ? 0.25 : 1
                        color: Theme.accent
                    }
                    Pressable {
                        id: muteBtn
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: hb.verticalCenter
                        width: 44; height: 44
                        color: dd.sinkMuted ? Theme.accent : Theme.control
                        ink: dd.sinkMuted ? Theme.onAccent : Theme.text
                        onClicked: if (dd.sink && dd.sink.audio) dd.sink.audio.muted = !dd.sink.audio.muted
                        Icon { anchors.centerIn: parent; size: 20; filled: true; name: dd.sinkMuted ? "volume_off" : "volume_up"; color: dd.sinkMuted ? Theme.onAccent : Theme.text }
                    }
                    Slider {
                        x: 16; y: 84
                        width: parent.width - 32
                        height: 50
                        icon: dd.volIcon(dd.sinkMuted, hero.vol)
                        muted: dd.sinkMuted
                        value: hero.vol
                        onMoved: v => { if (dd.sink && dd.sink.audio) { dd.sink.audio.muted = false; dd.sink.audio.volume = v; } }
                        onIconClicked: if (dd.sink && dd.sink.audio) dd.sink.audio.muted = !dd.sink.audio.muted
                    }
                }

                // ── where it plays: one row with a fold-out list of every output; a click switches ──
                Pressable {
                    id: outRow
                    visible: dd.outputs.length > 1
                    property bool expanded: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: Theme.corner(52, 8)
                    color: hovered || expanded ? Theme.containerHigh : Theme.container
                    onClicked: expanded = !expanded
                    Icon { id: oi; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "swap_horiz"; size: 20; color: Theme.subtext }
                    Label {
                        anchors.left: oi.right; anchors.leftMargin: 12
                        anchors.right: chev.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: "Output  ·  " + dd.outputs.length + " devices"
                    }
                    Icon {
                        id: chev
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"; size: 20; color: Theme.subtext
                        rotation: outRow.expanded ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
                    }
                }
                Item {
                    id: fold
                    // how far it's open (0..1), animated; hidden only once fully shut (a hidden
                    // item gets no height from the layout, so it must show before it grows)
                    property real open: outRow.expanded ? 1 : 0
                    Behavior on open { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
                    visible: outRow.visible && open > 0.01
                    Layout.fillWidth: true
                    Layout.preferredHeight: devs.implicitHeight * open
                    clip: true
                    opacity: open
                    Column {
                        id: devs
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: dd.outputs.length > 1 ? dd.outputs : []
                            Pressable {
                                id: dev
                                required property var modelData
                                readonly property bool current: modelData === dd.sink
                                width: devs.width
                                height: 48
                                radius: Theme.corner(48, 8)
                                color: current ? Theme.selected : (hovered ? Theme.container : "transparent")
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                Icon { id: di; x: 14; anchors.verticalCenter: parent.verticalCenter; name: dd.iconOf(dev.modelData); size: 19; filled: dev.current; color: dev.current ? Theme.accent : Theme.subtext }
                                Label {
                                    anchors.left: di.right; anchors.leftMargin: 12
                                    anchors.right: tick.left; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: dd.nameOf(dev.modelData)
                                    font.pixelSize: Theme.sizeSmall
                                    strong: dev.current
                                }
                                Icon { id: tick; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "check_circle"; size: 18; filled: true; color: Theme.accent; visible: dev.current }
                            }
                        }
                    }
                }

                // ── the microphone ──
                Rectangle {
                    visible: !!dd.source
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    radius: Theme.corner(80, 10)
                    color: Theme.containerHigh
                    Label {
                        x: 14; y: 12
                        width: parent.width - 28
                        elide: Text.ElideRight
                        text: dd.nameOf(dd.source) + (dd.micMuted ? "  ·  Muted" : "")
                        font.pixelSize: Theme.sizeSmall; muted: true
                    }
                    Slider {
                        x: 14; y: 40
                        width: parent.width - 28
                        height: 46
                        icon: dd.micMuted ? "mic_off" : "mic"
                        muted: dd.micMuted
                        value: dd.source && dd.source.audio ? dd.source.audio.volume : 0
                        onMoved: v => { if (dd.source && dd.source.audio) { dd.source.audio.muted = false; dd.source.audio.volume = v; } }
                        onIconClicked: if (dd.source && dd.source.audio) dd.source.audio.muted = !dd.source.audio.muted
                    }
                }

                // ── the apps making sound, each with its own volume ──
                Label { visible: dd.streams.length > 0; Layout.leftMargin: 6; Layout.topMargin: 2; text: "Apps"; muted: true; font.pixelSize: Theme.sizeSmall; strong: true }
                Repeater {
                    model: dd.streams
                    Rectangle {
                        id: app
                        required property var modelData
                        readonly property bool quiet: modelData.audio.muted
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: Theme.corner(80, 10)
                        color: Theme.containerHigh
                        Label {
                            x: 14; y: 12
                            width: parent.width - 28
                            elide: Text.ElideRight
                            text: dd.nameOf(app.modelData) + (app.modelData.properties["media.name"] ? "  ·  " + app.modelData.properties["media.name"] : "")
                            font.pixelSize: Theme.sizeSmall; muted: true
                        }
                        Slider {
                            x: 14; y: 40
                            width: parent.width - 28
                            height: 46
                            icon: dd.volIcon(app.quiet, app.modelData.audio.volume)
                            muted: app.quiet
                            value: app.modelData.audio.volume
                            onMoved: v => { app.modelData.audio.muted = false; app.modelData.audio.volume = v; }
                            onIconClicked: app.modelData.audio.muted = !app.modelData.audio.muted
                        }
                    }
                }

                // ── the full Sound menu (inputs, every device's volume) ──
                Pressable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: hovered ? Theme.container : "transparent"
                    onClicked: { HubState.closeDrop(); HubState.show("sound", dd.modelData.name); }
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { name: "tune"; size: 18; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "More sound settings"; font.pixelSize: Theme.sizeSmall; muted: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
