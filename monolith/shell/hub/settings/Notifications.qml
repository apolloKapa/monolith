import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "do_not_disturb_on"; title: "Do not disturb"; desc: "Only urgent notifications pop up; the rest wait in Notifications"
        Toggle { checked: Notifs.dnd; onToggled: on => Notifs.dnd = on }
    }
    SettingRow {
        icon: "volume_up"; title: "Sound"; desc: "A short sound when a notification arrives"
        Toggle { checked: Store.get("notifications.sound", true); onToggled: on => Store.set("notifications.sound", on) }
    }
    SettingRow {
        icon: "music_note"; title: "Your own sound"; desc: "A sound file (.oga, .wav, .mp3). Empty: the system's"
        Row {
            spacing: 6
            Field { width: 240; text: Store.get("notifications.soundFile", ""); placeholder: "/path/to/sound.oga"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("notifications.soundFile", "")) Store.set("notifications.soundFile", p); } }
            Button { text: "Play"; icon: "play_arrow"; onClicked: Notifs.playSound(false) }
        }
    }
    SettingRow {
        icon: "timer"; title: "How long they stay"; desc: "Unless the app says otherwise; urgent ones stay until closed"
        NumberBox { from: 1; to: 300; unit: "s"; value: Number(Store.get("notifications.timeout", 6)); onMoved: v => Store.set("notifications.timeout", v) }
    }
    SettingRow {
        icon: "science"; title: "Try it"; desc: "Send a test notification"
        Button { text: "Send"; icon: "send"; onClicked: Quickshell.execDetached(["notify-send", "-a", "Monolith", "This is how it looks", "Notifications pop up like this."]) }
    }
    SettingRow {
        icon: "notifications_active"; title: "How they pop up"; desc: "Out of the island on the screen you're using, or as cards in a corner"
        Segmented {
            opts: [["island", "Island"], ["corner", "Corner"]]
            value: Store.get("notifications.style", "island")
            onPicked: v => Store.set("notifications.style", v)
        }
    }
    SettingRow {
        visible: Store.get("notifications.style", "island") === "corner"
        icon: "picture_in_picture"; title: "Which corner"
        Segmented {
            width: 300
            opts: [["top-left", "↖"], ["top-right", "↗"], ["bottom-left", "↙"], ["bottom-right", "↘"]]
            value: Store.get("notifications.position", "top-right")
            onPicked: v => Store.set("notifications.position", v)
        }
    }
}
