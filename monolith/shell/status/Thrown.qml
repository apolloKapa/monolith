import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Thrown notifications falling down this screen (core/Throw). Only there while one falls;
// takes no clicks.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var mine: Throw.on_(modelData.name)
    visible: mine.length > 0
    WlrLayershell.namespace: "monolith-thrown"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}

    Repeater {
        model: win.mine
        Image {
            id: card
            required property var modelData
            source: modelData.url
            width: modelData.w
            height: modelData.h
            smooth: true
            // the flight: position and speed in px and px/s, gravity in px/s²
            property real px: modelData.x
            property real py: modelData.y
            property real vx: modelData.vx
            property real vy: modelData.vy
            property real spin: modelData.spin
            readonly property real g: 3200
            x: px
            y: py
            rotation: 0
            FrameAnimation {
                running: true
                onTriggered: {
                    const dt = Math.min(0.05, frameTime);
                    card.vy += card.g * dt;
                    card.px += card.vx * dt;
                    card.py += card.vy * dt;
                    card.rotation += card.spin * dt;
                    // the screen's sides bounce it back, a bit slower each time
                    if (card.px < 0 && card.vx < 0) { card.px = 0; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                    const right = win.width - card.width;
                    if (card.px > right && card.vx > 0) { card.px = right; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                    // out at the bottom (rotated corners included): gone
                    if (card.py > win.height + Math.max(card.width, card.height)) { running = false; Throw.land(card.modelData.id); }
                }
            }
        }
    }
}
