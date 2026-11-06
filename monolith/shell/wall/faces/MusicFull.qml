import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Music: glass with a quiet visualiser rising behind it; the cover on the left, the title
// (scrolling when long) and artist, the time with a wavy seek bar you can drag, and previous /
// play / next. As it gets smaller the time, then the artist and the cover step aside.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property bool active: !!p && p.trackTitle !== ""
    readonly property real r: Theme.corner(80, 14)
    readonly property real m: Math.max(6, Math.min(24, height * 0.12))
    readonly property real sp: Math.max(4, Math.min(20, height * 0.08))
    readonly property real btn: Math.max(18, Math.min(56, height * 0.24))
    readonly property real titleSize: Math.max(10, Math.min(24, height * 0.14))
    readonly property real subSize: Math.max(8, Math.min(16, height * 0.1))
    readonly property bool showArt: height >= 62 && width >= 175
    readonly property bool showTime: height >= 80
    readonly property bool showArtist: height >= 62
    readonly property bool showBars: height >= 52 && f.opt("showBars", true)
    function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return (s < 600 ? "0" : "") + Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    Item {
        anchors.fill: parent
        visible: f.showBars
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: bgMask }
        CavaBars {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: Math.max(20, parent.height * 0.55) * 0.55
            live: f.live && !!f.p && f.p.isPlaying
            continuous: f.opt("continuous", false)
            opacity: 0.2
        }
    }
    Rectangle { id: bgMask; anchors.fill: parent; radius: f.r; visible: false; layer.enabled: true }

    Item {
        anchors.fill: parent
        anchors.margins: f.m
        Rectangle {
            id: art
            visible: f.showArt
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: f.showArt ? Math.min(200, parent.height) : 0; height: width
            radius: Theme.corner(width, 8)
            color: Theme.control
            Icon { anchors.centerIn: parent; name: "music_note"; size: parent.width * 0.38; color: Theme.subtext; visible: cov.status !== Image.Ready }
            Image { id: cov; anchors.fill: parent; source: f.active ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
            MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: artMask }
            Rectangle { id: artMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
        }
        Item {
            anchors.left: f.showArt ? art.right : parent.left; anchors.leftMargin: f.showArt ? f.sp : 0
            anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: parent.bottom
            Marquee {
                id: ttl
                width: parent.width
                text: f.active ? (f.p.trackTitle || "Unknown track") : "Nothing playing"
                color: Theme.text
                font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.titleSize
                active: f.live && f.active
            }
            Text {
                id: artist
                anchors.top: ttl.bottom; anchors.topMargin: Math.max(1, f.sp * 0.2)
                width: parent.width; elide: Text.ElideRight
                visible: f.active && f.showArtist
                text: f.active ? (f.p.trackArtist || "Unknown artist") : ""
                color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: f.subSize
            }
            // the time and the wavy seek bar, between the names and the buttons
            RowLayout {
                visible: f.showTime && f.active
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: artist.visible ? artist.bottom : ttl.bottom
                anchors.bottom: ctl.top
                spacing: Math.max(4, f.sp * 0.4)
                Text { text: f.active ? f.mmss(f.p.position) : "--:--"; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Math.max(7, f.subSize * 0.85) }
                WavySeek {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(14, Math.round(f.subSize * 1.2))
                    live: f.live
                    value: f.active ? f.p.position : 0
                    to: f.active && f.p.length > 0 ? f.p.length : 1
                    playing: f.active && f.p.isPlaying
                    onMoved: v => { if (f.p && f.p.canSeek) f.p.position = v; }
                }
                Text { text: f.active ? f.mmss(f.p.length) : "--:--"; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Math.max(7, f.subSize * 0.85) }
            }
            Row {
                id: ctl
                anchors.bottom: parent.bottom
                spacing: Math.max(2, f.sp * 0.5)
                Repeater {
                    model: [["skip_previous", 0], [f.active && f.p.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
                    Pressable {
                        required property var modelData
                        width: f.btn; height: f.btn
                        radius: Math.max(4, f.btn * 0.2)
                        color: hovered ? Theme.containerHigh : Qt.alpha(Theme.control, 0.85)
                        enabledInput: f.live && !!f.p
                        onClicked: modelData[1] === 0 ? f.p.previous() : (modelData[1] === 1 ? f.p.togglePlaying() : f.p.next())
                        Icon { anchors.centerIn: parent; name: parent.modelData[0]; filled: true; size: Math.max(12, f.btn * 0.5); color: parent.hovered ? (parent.modelData[1] === 1 ? Theme.accent : Theme.text) : (parent.modelData[1] === 1 ? Theme.text : Theme.subtext) }
                    }
                }
            }
        }
    }
}
