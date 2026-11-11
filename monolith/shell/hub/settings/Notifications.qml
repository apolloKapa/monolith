import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Notifications: do not disturb, how long they stay and where they pop up (their sound: Sounds).
ColumnLayout {
    id: notifSec
    spacing: 8
    SettingRow {
        icon: "do_not_disturb_on"; title: "Do not disturb"; desc: "Only urgent notifications pop up; the rest wait in Notifications"
        Toggle { checked: Notifs.dnd; onToggled: on => Notifs.dnd = on }
    }
    SettingRow {
        key: "notifications.timeout"; def: 6;
        icon: "timer"; title: "How long they stay"; desc: "Unless the app says otherwise; urgent ones stay until closed"
        NumberBox { from: 1; to: 300; slideTo: 30; unit: "s"; value: Number(Store.get("notifications.timeout", 6)); onMoved: v => Store.set("notifications.timeout", v) }
    }
    SettingRow {
        key: "notifications.throw"; def: "slide";
        icon: Store.get("notifications.throw", "slide") === "fall" ? "sports_baseball" : "swipe_right"
        title: "Thrown away"
        desc: Store.get("notifications.throw", "slide") === "fall"
            ? "Swipe one away and it falls down the screen like a thrown ball: as fast as you flicked it, spinning, bouncing off the sides"
            : "Swipe one away and it slides off to the side"
        Segmented { width: 220; opts: [["slide", "Slide off"], ["fall", "Fall"]]; value: Store.get("notifications.throw", "slide"); onPicked: v => Store.set("notifications.throw", v) }
    }
    SettingRow {
        icon: "science"; title: "Try it"; desc: "Send a test notification"
        Button { text: "Send"; icon: "send"; onClicked: Quickshell.execDetached(["notify-send", "-a", "Monolith", "This is how it looks", "Notifications pop up like this."]) }
    }
    // where new ones pop up: out of the island, or as cards on any edge or corner
    readonly property string where: Store.get("notifications.style", "island") === "corner" ? Store.get("notifications.position", "top-right") : "island"
    SettingRow {
        keys: ["notifications.style", "notifications.position"];
        icon: "notifications_active"; title: "Where they pop up"; desc: "On the screen you're using"
        Dropdown {
            width: 260
            opts: [["island", "Out of the bar (island)", "The bar grows to show it"],
                   ["top-left", "Top left"], ["top", "Top"], ["top-right", "Top right"],
                   ["left", "Left"], ["right", "Right"],
                   ["bottom-left", "Bottom left"], ["bottom", "Bottom"], ["bottom-right", "Bottom right"]]
            value: notifSec.where
            onPicked: v => {
                if (v === "island") Store.set("notifications.style", "island");
                else { Store.set("notifications.style", "corner"); Store.set("notifications.position", v); }
            }
        }
    }
}
