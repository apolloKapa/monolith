import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

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
    // (raised again when a swipe starts, if an Overlay window went up over it since: see below)
    onMineChanged: {
        if (buried && mine.length > 0 && rows.count === 0) {
            buried = false; up = false;
            Qt.callLater(() => { win.up = true; win.sync(); });
            return;
        }
        sync();
    }
    function sync() {
        const ids = mine.map(f => f.id);
        for (let i = rows.count - 1; i >= 0; i--)
            if (ids.indexOf(rows.get(i).fid) === -1) rows.remove(i);
        for (const f of mine) {
            let have = false;
            for (let i = 0; i < rows.count; i++) if (rows.get(i).fid === f.id) { have = true; break; }
            if (!have) rows.append({ fid: f.id, url: f.url, fx: f.x, fy: f.y, fw: f.w, fh: f.h, fink: f.ink ? JSON.stringify(f.ink) : "" });
        }
    }
    WlrLayershell.namespace: "monolith-thrown"
    WlrLayershell.layer: WlrLayer.Overlay
    // back on top of the Overlay windows when one went up over it (HubState.raised): mapped
    // again, it's the newest. That's done when the next swipe starts, not when the other window
    // goes up: it used to be remade (a full-screen surface on every screen) each time a menu
    // opened, right as the menu started moving, which made menus late on older laptops.
    property bool up: true
    property bool buried: false
    // Only there while something is being thrown (and a few seconds after): empty, it was still
    // a full-screen surface on every screen, with its buffers on the GPU, all day. The real card
    // waits for its copy to be drawn before it hides (Throw.ready), so it coming up a frame or
    // two later shows as nothing.
    readonly property bool busy: mine.length > 0 || rows.count > 0
    onBusyChanged: if (!busy) keep.restart()
    Timer { id: keep; interval: 4000 }
    visible: up && (busy || keep.running)
    Connections {
        target: HubState
        function onRaisedChanged() { win.buried = true; }
    }
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
            required property string fink
            // (what the rest reads, as before)
            readonly property var modelData: ({ id: fid, x: fx, y: fy, w: fw, h: fh })
            source: url
            width: fw
            height: fh
            smooth: true
            // held: where the pointer has it; then the flight (px, px/s, gravity px/s²)
            property string phase: "held"        // held | fall | slide | back | wall
            // "Thrown away: Theme" with a style that has its own effect: let go, it isn't thrown off;
            // it drifts on a little the way it was thrown while the style's effect takes it
            property real burn: 0
            CyberFx { target: card; p: card.burn; going: true }
            NumberAnimation {
                id: burnAnim; target: card; property: "burn"; from: 0; to: 1; duration: Theme.fxOutMs
                onFinished: Throw.land(card.modelData.id)
            }
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
            // Held, it stays solid and hangs off the tray like card stock pulled off a ledge: it
            // pivots where it crosses the tray's side (that point slides along it as it's pulled),
            // the part that's out droops, more the further it's out (up to ~75° all of it out),
            // and it has weight: it tips with a little overshoot, settles, and swings when the
            // pointer speeds up or slows down. It can't tip in (the tray holds it up); springing
            // back, the tray lifts it level again. (hangStep, from the FrameAnimation below)
            readonly property bool hanging: phase === "held" || phase === "back"
            property real theta: 0               // the tilt, degrees (clockwise)
            property real omega: 0               // and how fast it's turning, radians/s
            property real lastDx: 0
            property real ptrV: 0                // the pointer's speed and its change, px/s, px/s²
            property real ptrA: 0
            // where it crosses the tray's side, along its top edge (pulled left: the tray's left
            // side is |dx| in from its left end)
            readonly property real pivotX: dx < 0 ? Math.min(width, -dx) : Math.max(0, width - dx)
            transform: Rotation { origin.x: card.pivotX; origin.y: 0; angle: card.hanging ? card.theta : 0 }
            function hangStep(dt) {
                // the pointer's motion (smoothed: a wobbly hand shouldn't shake it)
                const v = (dx - lastDx) / dt;
                lastDx = dx;
                const a = Math.max(-25000, Math.min(25000, (v - ptrV) / dt));
                ptrV += (v - ptrV) * 0.5;
                ptrA += (a - ptrA) * 0.25;
                // where it wants to hang: like card stock, the part that's out droops from the
                // start, more the more is out (up to ~75° all of it out)
                const out = Math.min(1, Math.abs(dx) / Math.max(1, width));
                const e = Math.max(0, Math.min(1, (out - 0.06) / 0.94));
                const side = dx < 0 ? -1 : 1;
                const want = side * 75 * Math.pow(e * e * (3 - 2 * e), 1.15) * Math.PI / 180;
                // it gets there like something with weight: springy, a little past it and back,
                // and the pointer speeding up or slowing down swings it (its weight lags behind:
                // torque of −a at its middle about the pivot, over a flat card's moment there)
                const t = theta * Math.PI / 180;
                const rx = width / 2 - pivotX, ry = height / 2;
                const ryr = rx * Math.sin(t) + ry * Math.cos(t);
                const inertia = rx * rx + ry * ry + (width * width + height * height) / 12;
                omega += (38 * (want - t) - 5.5 * omega + ryr * ptrA / inertia) * dt;
                let th = theta + omega * dt * 180 / Math.PI;
                // the tray holds it up: it tips out over the edge, never in
                if (th * side < 0) { th = 0; if (omega * side < 0) omega = -omega * 0.2; }
                theta = th;
            }
            // sliding off, it fades as it goes (from where it was let go); falling it stays solid
            opacity: dropFade * (phase === "slide" ? Math.max(0, 1 - travelled / (width * 1.1)) : 1)
            // the press ripple, carried on from where it was when grabbed: it spreads to the edges
            // and fades, as on the card (the photograph has none: it froze half-grown there)
            readonly property var inkAt: fink !== "" ? JSON.parse(fink) : null
            Ripple {
                id: rip
                visible: !!card.inkAt
                anchors.fill: parent
                radius: Theme.rnd(card.inkAt ? card.inkAt.radius : 0)
                ink: card.inkAt ? card.inkAt.color : "white"
                cx: card.inkAt ? card.inkAt.cx : 0
                cy: card.inkAt ? card.inkAt.cy : 0
                spread: card.inkAt ? card.inkAt.spread : 0
                alpha: card.inkAt ? card.inkAt.alpha : 0
            }
            ParallelAnimation {
                running: !!card.inkAt
                NumberAnimation { target: rip; property: "spread"; to: rip.reach; duration: Theme.ms(Math.max(120, 420 * (1 - rip.spread / Math.max(1, rip.reach)))); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve }
                SequentialAnimation {
                    PauseAnimation { duration: Theme.ms(120) }
                    NumberAnimation { target: rip; property: "alpha"; to: 0; duration: Theme.ms(300); easing.type: Easing.OutCubic }
                }
            }
            // its card went on to another notification mid-swipe: it fades away where it is
            NumberAnimation {
                id: dropAnim; target: card; property: "dropFade"; to: 0; duration: Theme.ms(180); easing.type: Easing.OutCubic
                onFinished: Throw.land(card.modelData.id)
            }
            property real dropFade: 1
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
                    // the hang becomes the flight's own turn: the same angle about the middle,
                    // moved so the card stays exactly where it hung (no jump as it's let go)
                    const a = card.theta * Math.PI / 180;
                    const ox = card.pivotX - card.width / 2, oy = -card.height / 2;
                    card.px += ox - (ox * Math.cos(a) - oy * Math.sin(a));
                    card.py += oy - (ox * Math.sin(a) + oy * Math.cos(a));
                    card.rotation = card.theta;
                    const turning = card.omega * 180 / Math.PI;
                    card.travelled = 0;
                    card.vx = vx; card.vy = mode === "fall" ? vy : 0;
                    // (it keeps turning the way it was swinging)
                    card.spin = mode === "fall" ? Math.max(-720, Math.min(720, turning + vx * 0.25 + (Math.random() - 0.5) * 90)) : 0;
                    card.phase = mode;
                    // Theme: the style's own way out (only then: Fall and Slide off stay what they are)
                    if (mode === "theme") { card.phase = "wall"; card.vy = 0; card.rotation = 0; burnAnim.restart(); }
                }
                function onDrop(id) { if (id === card.modelData.id && card.phase === "held") { card.phase = "drop"; dropAnim.restart(); } }
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
                    const dt = Math.min(0.05, frameTime);
                    if (card.hanging) { card.hangStep(Math.max(0.001, dt)); return; }
                    // (taken by the Blackwall: a slow drift the way it was thrown, nothing else)
                    if (card.phase === "wall") { card.px += card.vx * dt * 0.12; return; }
                    if (card.phase !== "fall" && card.phase !== "slide") return;
                    const falls = card.phase === "fall";
                    if (falls) {
                        card.vy += card.g * dt;
                        card.rotation += card.spin * dt;
                    }
                    card.px += card.vx * dt;
                    card.py += card.vy * dt;
                    card.travelled += Math.abs(card.vx * dt);
                    if (falls) {
                        // the screen's sides bounce it back, a bit slower each time. Where its edges are
                        // depends on how far it has turned: a wide card on its side is narrow, so it
                        // goes by the turned card's width, not its box's (that bounced off thin air)
                        const a = card.rotation * Math.PI / 180;
                        const half = (Math.abs(card.width * Math.cos(a)) + Math.abs(card.height * Math.sin(a))) / 2;
                        const mid = card.px + card.width / 2;
                        if (mid - half < 0 && card.vx < 0) { card.px = half - card.width / 2; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
                        if (mid + half > win.width && card.vx > 0) { card.px = win.width - half - card.width / 2; card.vx = -card.vx * 0.6; card.spin = -card.spin * 0.7; }
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
