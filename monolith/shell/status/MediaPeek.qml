import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// The now-playing peek: hover the bar's media module for a moment and a small player hangs under
// it (cover, title, artist, progress, previous / play / next); it stays while the pointer is on
// either, and a click on the module opens Media as before.
PanelWindow {
    id: pk
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.peekScreen === modelData.name && !HubState.open && !!player
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-media-peek"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: pk.shown ? card : null }

    // the position, moving every frame
    PlayPosition { id: pp; player: pk.player; active: pk.shown }

    Rectangle {
        id: card
        width: 360; height: 128
        x: Math.max(12, Math.min(pk.width - width - 12, HubState.peekX - width / 2))
        y: Theme.barBottom ? HubState.peekY - height - 10 + (pk.shown ? 0 : 8) : HubState.peekY + 10 + (pk.shown ? 0 : -8)
        radius: Theme.corner(80, 14)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        opacity: pk.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: pk.shown ? Theme.fastMs : Theme.ms(120); easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        CardShadow {}
        HoverHandler { onHoveredChanged: HubState.peekCardHover = hovered }

        Rectangle {
            id: art
            x: 12; y: 12
            width: 104; height: 104
            radius: Theme.corner(104, 10)
            color: Theme.control
            Icon { anchors.centerIn: parent; visible: cov.status !== Image.Ready; name: "music_note"; size: 40; color: Theme.subtext }
            Image { id: cov; anchors.fill: parent; visible: false; source: pk.player ? (pk.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(208, 208); asynchronous: true }
            MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: artMask }
            Rectangle { id: artMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { HubState.peekScreen = ""; HubState.toggle("media", pk.modelData.name); } }
        }
        Column {
            x: art.x + art.width + 14; y: 14
            width: card.width - x - 14
            spacing: 2
            Label { width: parent.width; elide: Text.ElideRight; text: pk.player ? (pk.player.trackTitle || "Unknown track") : ""; strong: true; font.pixelSize: Theme.sizeBody + 1 }
            Label { width: parent.width; elide: Text.ElideRight; text: pk.player ? (pk.player.trackArtist || "") : ""; muted: true; font.pixelSize: Theme.sizeSmall }
        }
        // progress
        Rectangle {
            x: art.x + art.width + 14; y: 66
            width: card.width - x - 14; height: 4; radius: 2
            color: Theme.ringTrack
            visible: !!pk.player && pk.player.length > 0
            Rectangle { height: parent.height; radius: 2; color: Theme.accent; width: pk.player && pk.player.length > 0 ? parent.width * Math.min(1, pp.shown / pk.player.length) : 0 }
        }
        Row {
            x: art.x + art.width + 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            spacing: 4
            Repeater {
                model: [["skip_previous", 0], [pk.player && pk.player.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
                Pressable {
                    required property var modelData
                    width: modelData[1] === 1 ? 48 : 36; height: 36
                    color: modelData[1] === 1 ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
                    ink: modelData[1] === 1 ? Theme.onAccent : Theme.text
                    enabledInput: !!pk.player
                    onClicked: modelData[1] === 0 ? pk.player.previous() : (modelData[1] === 1 ? pk.player.togglePlaying() : pk.player.next())
                    Icon { anchors.centerIn: parent; name: parent.modelData[0]; filled: true; size: 21; color: parent.modelData[1] === 1 ? Theme.onAccent : Theme.text }
                }
            }
        }
    }
}
