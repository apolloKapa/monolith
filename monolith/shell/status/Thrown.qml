import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Swiped notifications (core/Throw): held under the pointer, then thrown, slid off or sprung
// back. Always there (an empty, click-through layer: making it when a swipe starts took a frame
// or two), takes no clicks.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var mine: Throw.on_(modelData.name)
    // the copies, one row each. (The Repeater used to take `mine` itself: that's a new list every
    // time one is launched or lands, so every copy was rebuilt, back where it was grabbed and
    // "held", and the ones already thrown never got their let-go again: several thrown at once
    // left frozen cards on the screen.) Only rows that came or went change now.
    ListModel { id: rows }
    onMineChanged: {
        const ids = mine.map(f => f.id);
        for (let i = rows.count - 1; i >= 0; i--)
            if (ids.indexOf(rows.get(i).fid) === -1) rows.remove(i);
        for (const f of mine) {
            let have = false;
            for (let i = 0; i < rows.count; i++) if (rows.get(i).fid === f.id) { have = true; break; }
            if (!have) rows.append({ fid: f.id, url: f.url, fx: f.x, fy: f.y, fw: f.w, fh: f.h });
        }
    }
    WlrLayershell.namespace: "monolith-thrown"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}

    Repeater {
        model: rows
        Image {
            id: card
            required property int fid
            required property string url
            required property real fx
            required property real fy
            required property real fw
            required property real fh
            // (what the rest reads, as before)
            readonly property var modelData: ({ id: fid, x: fx, y: fy, w: fw, h: fh })
            source: url
            width: fw
            height: fh
            smooth: true
            // held: where the pointer has it; then the flight (px, px/s, gravity px/s²)
            property string phase: "held"        // held | fall | slide | back
            property real dx: 0
            property real px: modelData.x
            property real py: modelData.y
            property real vx: 0
            property real vy: 0
            property real spin: 0
            property real travelled: 0
            readonly property real g: 3200
            x: phase === "held" || phase === "back" ? modelData.x + dx : px
            y: phase === "held" || phase === "back" ? modelData.y : py
            // fades as it goes sideways (held and sliding); falling it stays solid
            opacity: phase === "fall" ? 1 : Math.max(0, 1 - Math.abs(phase === "slide" ? travelled : dx) / (width * 1.1))
            // springing back home: a little past it and back, then the real card takes over (it
            // shows first and the copy goes a frame later, so they overlap instead of flickering)
            NumberAnimation {
                id: backAnim
                target: card; property: "dx"; to: 0
                duration: Theme.ms(320); easing.type: Easing.OutBack; easing.overshoot: 1.4
                onFinished: { Throw.home(card.modelData.id); Qt.callLater(() => Throw.land(card.modelData.id)); }
            }
            property int frames: 0
            // never stuck: held with no word from its card for a while (the card went away
            // mid-swipe), it springs back and goes
            Timer { id: stale; interval: 8000; running: card.phase === "held"; onTriggered: if (card.phase === "held") { card.phase = "back"; backAnim.restart(); } }

            Connections {
                target: Throw
                function onDragTo(id, d) { if (id === card.modelData.id && card.phase === "held") { card.dx = d; stale.restart(); } }
                function onLetGo(id, vx, vy, mode) {
                    if (id !== card.modelData.id) return;
                    card.px = card.modelData.x + card.dx; card.py = card.modelData.y;
                    card.travelled = Math.abs(card.dx);
                    card.vx = vx; card.vy = mode === "fall" ? vy : 0;
                    card.spin = mode === "fall" ? Math.max(-720, Math.min(720, vx * 0.35 + (Math.random() - 0.5) * 120)) : 0;
                    card.phase = mode;
                }
                function onSpringBack(id) {
                    if (id !== card.modelData.id) return;
                    card.phase = "back";
                    backAnim.restart();
                }
            }
            FrameAnimation {
                running: card.status === Image.Ready
                onTriggered: {
                    // on screen (two frames drawn, so the two overlap for a moment instead of
                    // leaving a gap): the real card can hide now
                    if (++card.frames === 2) Throw.ready(card.modelData.id);
                    if (card.phase !== "fall" && card.phase !== "slide") return;
                    const dt = Math.min(0.05, frameTime);
                    const falls = card.phase === "fall";
                    if (falls) {
                        card.vy += card.g * dt;
                        card.rotation += card.spin * dt;
                    }
                    card.px += card.vx * dt;
                    card.py += card.vy * dt;
                    card.travelled += Math.abs(card.vx * dt);
                    if (falls) {
                        // the screen's sides bounce it back, a bit slower each time
                        if (card.px < 0 && card.vx < 0) { card.px = 0; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                        const right = win.width - card.width;
                        if (card.px > right && card.vx > 0) { card.px = right; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                    }
                    // gone: out at the bottom (falling), faded or off the side (sliding)
                    const out = falls ? card.py > win.height + Math.max(card.width, card.height)
                                      : (card.opacity <= 0.01 || card.px > win.width || card.px + card.width < 0);
                    if (out) { running = false; Throw.land(card.modelData.id); }
                }
            }
        }
    }
}
