import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../ui"

// Sound: the device in use on a card of its own with the one big volume bar, the other
// devices as plain rows under it (a click switches to one), and the apps playing, each
// with its own volume. Only the card's bar takes the wheel: scrolling the list just scrolls.
Page {
    id: page
    pageId: "sound"
    implicitHeight: Math.min(600, col.implicitHeight)
    property string tab: "out"

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isStream)
    readonly property var devices: tab === "out" ? outputs : inputs
    readonly property var inUse: tab === "out" ? Pipewire.defaultAudioSink : (tab === "in" ? Pipewire.defaultAudioSource : null)
    readonly property bool out: tab !== "in"
    PwObjectTracker { objects: page.nodes }

    function nameOf(n) {
        if (!n) return "";
        if (n.isStream) return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }
    function iconOf(n) {
        if (!n) return "volume_off";
        if (n.isStream) return "music_note";
        if (!n.isSink) return "mic";
        const d = (n.description || "").toLowerCase();
        return d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 ? "headphones" : (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1 ? "tv" : "speaker");
    }
    function use(n) {
        if (n.isSink) Pipewire.preferredDefaultAudioSink = n;
        else Pipewire.preferredDefaultAudioSource = n;
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        IconTabs {
            opts: [["out", "Outputs", "speaker"], ["in", "Inputs", "mic"], ["apps", "Apps", "apps"]]
            value: page.tab
            onPicked: v => page.tab = v
        }

        // ── the device in use ──
        Rectangle {
            id: now
            visible: page.tab !== "apps" && page.inUse !== null
            readonly property var node: page.inUse
            readonly property bool quiet: !!(node && node.audio && node.audio.muted)
            Layout.fillWidth: true
            Layout.preferredHeight: 148
            radius: Theme.corner(84, 6)
            color: Theme.selected
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            Bubble { id: nb; x: 16; y: 16; size: 52; icon: page.iconOf(now.node); on: true }
            Column {
                anchors.left: nb.right; anchors.leftMargin: 14
                anchors.right: mute.left; anchors.rightMargin: 12
                anchors.verticalCenter: nb.verticalCenter
                spacing: 3
                Label { width: parent.width; text: page.nameOf(now.node); strong: true; font.pixelSize: Theme.sizeTitle }
                Label {
                    width: parent.width; muted: true
                    text: now.quiet ? "Muted" : ((page.out ? "Playing here" : "Listening here") + "  ·  " + Math.round((now.node && now.node.audio ? now.node.audio.volume : 0) * 100) + "%")
                }
            }
            Pressable {
                id: mute
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: nb.verticalCenter
                width: 44; height: 44
                radius: Theme.corner(height)
                color: now.quiet ? Theme.accent : Theme.control
                ink: now.quiet ? Theme.onAccent : Theme.text
                onClicked: if (now.node && now.node.audio) now.node.audio.muted = !now.node.audio.muted
                Icon {
                    anchors.centerIn: parent; size: 22
                    name: page.out ? (now.quiet ? "volume_off" : "volume_up") : (now.quiet ? "mic_off" : "mic")
                    color: now.quiet ? Theme.onAccent : Theme.text
                }
            }
            Slider {
                x: 16
                y: 84
                width: parent.width - 32
                height: 48
                icon: page.out ? (now.quiet ? "volume_off" : "volume_up") : (now.quiet ? "mic_off" : "mic")
                muted: now.quiet
                value: now.node && now.node.audio ? now.node.audio.volume : 0
                onMoved: v => { if (now.node && now.node.audio) { now.node.audio.muted = false; now.node.audio.volume = v; } }
                onIconClicked: if (now.node && now.node.audio) now.node.audio.muted = !now.node.audio.muted
            }
        }

        SectionHead {
            visible: page.tab !== "apps" && page.devices.length > 1
            text: page.out ? "Play somewhere else" : "Use another microphone"
        }
        SectionHead {
            visible: page.tab === "apps" && page.streams.length > 0
            text: page.streams.length === 1 ? "1 app is making sound" : page.streams.length + " apps are making sound"
        }

        // the lists scroll under the card when they're long
        Flickable {
            id: scroller
            SmoothWheel {}
            visible: page.tab === "apps" ? page.streams.length > 0 : page.devices.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, 330)
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ColumnLayout {
                id: rows
                width: parent.width
                spacing: 8

                // the other devices: a click switches
                Repeater {
                    model: page.tab === "apps" ? [] : page.devices.filter(n => n !== page.inUse)
                    Pressable {
                        id: dev
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: Theme.corner(height)
                        color: Theme.containerHigh
                        onClicked: page.use(modelData)
                        Bubble { id: db; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 36; icon: page.iconOf(dev.modelData) }
                        Column {
                            anchors.left: db.right; anchors.leftMargin: 12
                            anchors.right: sw.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Label { width: parent.width; text: page.nameOf(dev.modelData); strong: true }
                            Label {
                                width: parent.width; muted: true; font.pixelSize: Theme.sizeSmall
                                text: (dev.modelData.audio.muted ? "Muted" : Math.round(dev.modelData.audio.volume * 100) + "%") + "  ·  click to switch"
                            }
                        }
                        Icon { id: sw; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; name: "swap_horiz"; size: 20; color: Theme.subtext; opacity: dev.hovered ? 1 : 0.5 }
                    }
                }

                // the apps: a name, what's playing, its own volume
                Repeater {
                    model: page.tab === "apps" ? page.streams : []
                    Rectangle {
                        id: app
                        required property var modelData
                        readonly property bool quiet: modelData.audio.muted
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: Theme.corner(56, 6)
                        color: Theme.containerHigh
                        border.width: Theme.outlineW
                        border.color: Theme.outlineColor
                        Bubble { id: ab; x: 12; y: 12; size: 36; icon: app.modelData.isSink ? "music_note" : "mic" }
                        Column {
                            anchors.left: ab.right; anchors.leftMargin: 12
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: ab.verticalCenter
                            Label { width: parent.width; text: page.nameOf(app.modelData); strong: true }
                            Label { width: parent.width; muted: true; font.pixelSize: Theme.sizeSmall; text: app.modelData.properties["media.name"] || (app.modelData.isSink ? "Playing" : "Recording"); }
                        }
                        Slider {
                            x: 12
                            y: 56
                            width: parent.width - 24
                            height: 32
                            icon: app.quiet ? "volume_off" : "volume_up"
                            muted: app.quiet
                            value: app.modelData.audio.volume
                            onMoved: v => { app.modelData.audio.muted = false; app.modelData.audio.volume = v; }
                            onIconClicked: app.modelData.audio.muted = !app.modelData.audio.muted
                        }
                    }
                }
            }
        }

        Empty {
            visible: page.tab !== "apps" && page.inUse === null
            icon: page.out ? "volume_off" : "mic_off"
            title: page.out ? "Nothing to play through" : "No microphone"
            sub: page.out ? "Plug in speakers or headphones and they show up here." : "Plug in a microphone or a headset and it shows up here."
        }
        Empty {
            visible: page.tab === "apps" && page.streams.length === 0
            icon: "music_off"
            title: "It's quiet"
            sub: "Apps show up here while they play or record sound, each with its own volume."
        }
    }
}
