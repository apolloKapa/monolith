pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Idle actions: lock after a while, then turn the screens off. Anything holding an idle
// inhibitor (a video, Quick → Stay awake) pauses them. Times are seconds (Settings → Lock & idle).
Singleton {
    id: idle
    readonly property bool enabled: Store.get("idle.enabled", false)
    readonly property int lockAfter: Store.get("idle.lockAfter", 300)
    readonly property int screenOffAfter: Store.get("idle.screenOffAfter", 450)

    IdleMonitor {
        enabled: idle.enabled && idle.lockAfter > 0
        timeout: idle.lockAfter
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) LockState.lock()
    }
    IdleMonitor {
        enabled: idle.enabled && idle.screenOffAfter > 0
        timeout: idle.screenOffAfter
        respectInhibitors: true
        onIsIdleChanged: Niri.action([isIdle ? "power-off-monitors" : "power-on-monitors"])
    }
}
