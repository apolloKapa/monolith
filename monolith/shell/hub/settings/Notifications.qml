import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Notifications: do not disturb, how long they stay and where they pop up (their sound: Sounds).
ColumnLayout {
    id: notifSec
    spacing: 8
    Component.onCompleted: Notifs.checkOwner()
    SettingRow {
        icon: "do_not_disturb_on"; title: "Do not disturb"; desc: "Only urgent notifications pop up; the rest wait in Notifications"
        Toggle { checked: Notifs.dnd; onToggled: on => Notifs.dnd = on }
    }
    SettingRow {
        key: "notifications.timeout"; def: 6;
        icon: "timer"; title: "How long they stay"; desc: "Unless the app says otherwise; urgent ones stay until closed"
        NumberBox { from: 1; to: 300; slideTo: 30; unit: "s"; value: Number(Store.get("notifications.timeout", 6)); onMoved: v => Store.set("notifications.timeout", v) }
    }
    // a game (any fullscreen app) on the screen they'd pop up on
    SettingRow {
        key: "notifications.fullscreen"; def: "other";
        icon: "fullscreen"; title: "While an app is fullscreen"
        desc: {
            const m = Store.get("notifications.fullscreen", "other");
            return m === "show" ? "They pop up over it as usual"
                 : m === "other" ? "They pop up on another screen (with one screen, or all fullscreen: they wait). Urgent ones always show"
                 : "They wait, then one summary comes up when you leave fullscreen. Urgent ones always show";
        }
        Dropdown {
            opts: [["other", "Show on another screen"], ["hold", "Hold, summary after"], ["show", "Show over it"]]
            value: Store.get("notifications.fullscreen", "other")
            onPicked: v => Store.set("notifications.fullscreen", v)
        }
    }
    SettingRow {
        key: "notifications.fullscreenSound"; def: false;
        visible: Store.get("notifications.fullscreen", "other") !== "show"
        icon: "volume_off"; title: "Sound while fullscreen"; desc: "Off: notifications are silent while a fullscreen app covers the screen"
        Toggle { checked: Store.get("notifications.fullscreenSound", false) === true; onToggled: on => Store.set("notifications.fullscreenSound", on) }
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
    // ── how new ones pop up: two themes, only ever one of them ──
    readonly property bool side: Store.get("notifications.style", "island") === "corner"
    SettingRow {
        keys: ["notifications.style"];
        icon: "notifications_active"; title: "Style"
        desc: Theme.barSide !== "" ? "With the bar down the side there's no bar to drop out of: they come up at the side"
            : notifSec.side ? "Side: cards stack at an edge or corner of the screen, like before"
                            : "Island: they drop out of the bar at the top (a card under a floating bar)"
        Segmented {
            width: 240
            opts: [["island", "Island"], ["corner", "Side"]]
            value: notifSec.side ? "corner" : "island"
            onPicked: v => Store.set("notifications.style", v)
        }
    }
    SettingRow {
        visible: notifSec.side || Theme.barSide !== ""
        key: "notifications.position"; def: "top-right";
        icon: "picture_in_picture"; title: "Where at the side"; desc: "On the screen you're using"
        Dropdown {
            width: 220
            opts: [["top-left", "Top left"], ["top", "Top"], ["top-right", "Top right"],
                   ["left", "Left"], ["right", "Right"],
                   ["bottom-left", "Bottom left"], ["bottom", "Bottom"], ["bottom-right", "Bottom right"]]
            value: Store.get("notifications.position", "top-right")
            onPicked: v => Store.set("notifications.position", v)
        }
    }
    // another notification program took the bus: it shows its own popups (two kinds at once)
    // and Monolith's never come
    SettingRow {
        visible: Notifs.otherDaemon !== ""
        icon: "warning"; title: Notifs.otherDaemon + " is showing notifications"
        desc: "Another notification program started and took them over, so its popups show instead of (or as well as) Monolith's. Use Monolith's stops it and keeps it from starting again."
        Button { text: "Use Monolith's"; icon: "notifications"; primary: true; onClicked: Notifs.takeBack() }
    }
}
