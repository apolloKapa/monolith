import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Sounds: the notification sound, and the interface's own clicks.
ColumnLayout {
    spacing: 8
    SettingRow {
        key: "notifications.sound"; def: true;
        icon: "volume_up"; title: "Notification sound"; desc: "A short sound when a notification arrives"
        Toggle { checked: Store.get("notifications.sound", true); onToggled: on => Store.set("notifications.sound", on) }
    }
    SettingRow {
        key: "notifications.soundFile"; def: "";
        icon: "music_note"; title: "Your own sound"; desc: "A sound file (.oga, .wav, .mp3). Empty: the system's"
        Row {
            spacing: 6
            Field { width: 240; text: Store.get("notifications.soundFile", ""); placeholder: "/path/to/sound.oga"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("notifications.soundFile", "")) Store.set("notifications.soundFile", p); } }
            Button { text: "Play"; icon: "play_arrow"; onClicked: Notifs.playSound(false) }
        }
    }
    SettingRow {
        key: "sounds.enabled"; def: false;
        icon: "graphic_eq"; title: "Interface sounds"; desc: "Soft clicks for buttons and switches, and for menus opening and closing"
        Toggle { checked: Sounds.on; onToggled: on => { Store.set("sounds.enabled", on); if (on) Qt.callLater(() => Sounds.play("toggle-on")); } }
    }
    SettingRow {
        key: "sounds.volume"; def: 0.5;
        visible: Sounds.on
        icon: "volume_down"; title: "Interface volume"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Sounds.volume; onMoved: v => { Store.set("sounds.volume", v); Sounds.play("click"); } }
    }
}
