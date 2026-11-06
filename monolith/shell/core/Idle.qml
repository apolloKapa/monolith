pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Idle actions, in order: dim the screens a little before locking, lock, turn the screens off,
// suspend (each optional, times in seconds; Settings → Lock & idle). Anything holding an idle
// inhibitor (a video, Stay awake) pauses them, and so does music or video playing (optional).
Singleton {
    id: idle
    readonly property bool enabled: Store.get("idle.enabled", false)
    readonly property int lockAfter: Store.get("idle.lockAfter", 300)
    readonly property int screenOffAfter: Store.get("idle.screenOffAfter", 450)
    readonly property int dimBefore: Store.get("idle.dimBefore", 20)          // 0: no dimming
    readonly property int suspendAfter: Store.get("idle.suspendAfter", 0)     // 0: never
    readonly property bool mediaPauses: Store.get("idle.mediaPauses", true) !== false
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool on: enabled && !(mediaPauses && playing)
    // the screens are dimmed (status/Dim.qml), until you move or lock
    readonly property bool dimming: dimMon.isIdle && on && !LockState.locked

    IdleMonitor {
        id: dimMon
        enabled: idle.on && idle.dimBefore > 0 && idle.lockAfter > idle.dimBefore
        timeout: Math.max(1, idle.lockAfter - idle.dimBefore)
        respectInhibitors: true
    }
    IdleMonitor {
        enabled: idle.on && idle.lockAfter > 0
        timeout: idle.lockAfter
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) LockState.lock()
    }
    IdleMonitor {
        enabled: idle.on && idle.screenOffAfter > 0
        timeout: idle.screenOffAfter
        respectInhibitors: true
        onIsIdleChanged: Niri.action([isIdle ? "power-off-monitors" : "power-on-monitors"])
    }
    IdleMonitor {
        enabled: idle.on && idle.suspendAfter > 0
        timeout: idle.suspendAfter
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) { LockState.lock(); Power.suspend(); }
    }

    // your own idle actions (Settings → Lock & idle): [{ name, after (s), command, resume }]
    readonly property var actions: Store.get("idle.actions", [])
    Instantiator {
        model: idle.actions
        delegate: IdleMonitor {
            required property var modelData
            enabled: idle.on && Number(modelData.after) > 0 && (modelData.command || "") !== ""
            timeout: Math.max(1, Number(modelData.after))
            respectInhibitors: true
            onIsIdleChanged: {
                if (isIdle) Quickshell.execDetached(["sh", "-c", modelData.command]);
                else if ((modelData.resume || "") !== "") Quickshell.execDetached(["sh", "-c", modelData.resume]);
            }
        }
    }
}
