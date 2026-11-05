import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "timer"; title: "Lock when idle"; desc: "Lock, then turn the screens off, when you're away (videos and Stay awake pause this)"
        Toggle { checked: Idle.enabled; onToggled: on => Store.set("idle.enabled", on) }
    }
    SettingRow {
        icon: "lock"; title: "Lock after"
        Slider {
            width: 220; implicitHeight: 36
            icon: "lock"
            value: Idle.lockAfter / 1800
            label: Math.round(Idle.lockAfter / 60) + " min"
            onMoved: v => Store.set("idle.lockAfter", Math.max(60, Math.round(v * 30) * 60))
        }
    }
    SettingRow {
        icon: "desktop_access_disabled"; title: "Screens off after"
        Slider {
            width: 220; implicitHeight: 36
            icon: "monitor"
            value: Idle.screenOffAfter / 3600
            label: Math.round(Idle.screenOffAfter / 60) + " min"
            onMoved: v => Store.set("idle.screenOffAfter", Math.max(60, Math.round(v * 60) * 60))
        }
    }
    SettingRow {
        icon: "music_note"; title: "Media on the lock screen"; desc: "Show what's playing, with play/pause"
        Toggle { checked: Store.get("lock.media", true) !== false; onToggled: on => Store.set("lock.media", on) }
    }
    SettingRow {
        icon: "lock"; title: "Lock now"
        Button { text: "Lock"; onClicked: { HubState.close(); LockState.lock(); } }
    }
}
