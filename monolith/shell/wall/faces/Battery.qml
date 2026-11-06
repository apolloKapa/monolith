import QtQuick
import Quickshell.Services.UPower
import "../../core"
import "../../ui"

// The battery for the battery looks: the laptop's, else the first device reporting one (a mouse,
// a headset). level 0..1, charging, name, the time left, an icon and a colour.
QtObject {
    readonly property var dev: {
        const d = UPower.displayDevice;
        if (d && d.isPresent && d.isLaptopBattery) return d;
        return UPower.devices.values.find(x => x.isPresent && x.percentage > 0) || null;
    }
    readonly property bool present: !!dev
    readonly property real level: dev ? (dev.percentage > 1 ? dev.percentage / 100 : dev.percentage) : 0
    readonly property bool charging: !!dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
    readonly property string name: dev ? (dev.isLaptopBattery ? "Battery" : (dev.model || "Battery")) : "No battery"
    function hm(s) { const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60); return h > 0 ? h + " h " + m + " min" : m + " min"; }
    readonly property string time: !dev ? "On mains power"
        : dev.state === UPowerDeviceState.FullyCharged ? "Fully charged"
        : charging ? (dev.timeToFull > 0 ? hm(dev.timeToFull) + " until full" : "Charging")
        : (dev.timeToEmpty > 0 ? hm(dev.timeToEmpty) + " left" : name)
    readonly property string icon: !dev ? "power" : charging ? "battery_charging_full" : level > 0.8 ? "battery_full" : level > 0.6 ? "battery_5_bar" : level > 0.4 ? "battery_3_bar" : level > 0.2 ? "battery_2_bar" : "battery_alert"
    readonly property color color: !dev ? Theme.subtext : charging ? "#7bd88f" : level <= 0.2 ? Theme.danger : Theme.m("primary", Theme.accent)
}
