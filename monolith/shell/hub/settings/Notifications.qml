import QtQuick
import QtQuick.Layouts
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
        icon: "picture_in_picture"; title: "Where they pop up"
        Segmented {
            width: 300
            opts: [["top-left", "↖"], ["top-right", "↗"], ["bottom-left", "↙"], ["bottom-right", "↘"]]
            value: Store.get("notifications.position", "top-right")
            onPicked: v => Store.set("notifications.position", v)
        }
    }
}
