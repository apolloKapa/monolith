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
        NumberBox { from: 1; to: 1440; unit: "min"; value: Math.round(Idle.lockAfter / 60); onMoved: v => Store.set("idle.lockAfter", v * 60) }
    }
    SettingRow {
        icon: "desktop_access_disabled"; title: "Screens off after"
        NumberBox { from: 0; to: 1440; unit: "min"; zeroText: "Never"; value: Math.round(Idle.screenOffAfter / 60); onMoved: v => Store.set("idle.screenOffAfter", v * 60) }
    }
    SettingRow {
        icon: "brightness_low"; title: "Dim first"; desc: "The screens darken this long before locking (move to stop it)"
        NumberBox { from: 0; to: 600; step: 5; unit: "s"; zeroText: "Off"; value: Idle.dimBefore; onMoved: v => Store.set("idle.dimBefore", v) }
    }
    SettingRow {
        icon: "bedtime"; title: "Suspend after"; desc: "Put the PC to sleep when you've been away this long"
        NumberBox { from: 0; to: 1440; step: 5; unit: "min"; zeroText: "Never"; value: Idle.suspendAfter / 60; onMoved: v => Store.set("idle.suspendAfter", Math.round(v * 60)) }
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
