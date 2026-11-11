import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Swiped-away notifications on their way out (core/Throw). Always there (an empty,
// click-through layer: making it only when a card is thrown took a frame or two, and the card
// was gone before its copy showed), takes no clicks.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var mine: Throw.on_(modelData.name)
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
            readonly property bool falls: modelData.mode === "fall"
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
            property real travelled: 0
            x: px
            y: py
            // sliding, it fades over the first card-width or so
            opacity: falls ? 1 : Math.max(0, 1 - travelled / (width * 1.1))
            // on screen (two frames drawn, so the two overlap for a moment instead of leaving a
            // gap): the real card can hide now
            property int frames: 0
            FrameAnimation {
                running: card.status === Image.Ready
                onTriggered: {
                    if (++card.frames === 2) Throw.ready(card.modelData.id);
                    const dt = Math.min(0.05, frameTime);
                    if (card.falls) {
                        card.vy += card.g * dt;
                        card.rotation += card.spin * dt;
                    }
                    card.px += card.vx * dt;
                    card.py += card.vy * dt;
                    card.travelled += Math.abs(card.vx * dt);
                    if (card.falls) {
                        // the screen's sides bounce it back, a bit slower each time
                        if (card.px < 0 && card.vx < 0) { card.px = 0; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                        const right = win.width - card.width;
                        if (card.px > right && card.vx > 0) { card.px = right; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                    }
                    // gone: out at the bottom (falling), faded or off the side (sliding)
                    const out = card.falls ? card.py > win.height + Math.max(card.width, card.height)
                                           : (card.opacity <= 0.01 || card.px > win.width || card.px + card.width < 0);
                    if (out) { running = false; Throw.land(card.modelData.id); }
                }
            }
        }
    }
}
