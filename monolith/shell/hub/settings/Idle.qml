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
        icon: "brightness_low"; title: "Dim first"; desc: "The screens darken this long before locking (move to stop it)"
        Segmented { width: 300; opts: [["0", "Off"], ["10", "10 s"], ["20", "20 s"], ["60", "1 min"]]; value: String(Idle.dimBefore); onPicked: v => Store.set("idle.dimBefore", Number(v)) }
    }
    SettingRow {
        icon: "bedtime"; title: "Suspend after"; desc: "Put the PC to sleep when you've been away this long"
        Segmented { width: 330; opts: [["0", "Never"], ["1800", "30 min"], ["3600", "1 hour"], ["7200", "2 hours"]]; value: String(Idle.suspendAfter); onPicked: v => Store.set("idle.suspendAfter", Number(v)) }
    }
    SettingRow {
        icon: "play_circle"; title: "Not while playing"; desc: "Music or video playing counts as being here"
        Toggle { checked: Idle.mediaPauses; onToggled: on => Store.set("idle.mediaPauses", on) }
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
