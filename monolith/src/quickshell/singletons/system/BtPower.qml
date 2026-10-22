pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Turning Bluetooth on/off for every button. BlueZ refuses to power an adapter that rfkill
// has blocked (airplane mode elsewhere, or a block restored at boot), so the toggle used to
// silently do nothing: unblock it first, then power it on once the block is gone.
Item {
    id: root

    function setEnabled(on) {
        const adapter = Bluetooth.defaultAdapter;
        if (!on) {
            if (adapter) adapter.enabled = false;
            return;
        }
        if (adapter && adapter.state !== BluetoothAdapterState.Blocked) {
            adapter.enabled = true;
            return;
        }
        unblock.running = true;
    }

    function toggle() {
        const adapter = Bluetooth.defaultAdapter;
        setEnabled(!(adapter && adapter.enabled));
    }

    Process {
        id: unblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: powerOn.restart()
    }

    // BlueZ needs a moment to notice the block is gone
    Timer {
        id: powerOn
        interval: 300
        onTriggered: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = true
    }
}
