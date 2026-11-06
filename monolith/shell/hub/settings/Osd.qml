import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        key: "osd.enabled"; def: true;
        icon: "featured_video"; title: "Show a pop-up"; desc: "A small pill when you change the volume, keyboard layout, Caps Lock or Num Lock"
        Toggle { checked: Store.get("osd.enabled", true) !== false; onToggled: on => Store.set("osd.enabled", on) }
    }
    SettingRow {
        key: "osd.x"; def: 0.5;
        icon: "swap_horiz"; title: "Horizontal position"; desc: "0 %: the left edge, 100 %: the right"
        NumberBox { from: 0; to: 1; step: 0.01; decimals: 2; factor: 100; unit: "%"; value: Number(Store.get("osd.x", 0.5)); onMoved: v => Store.set("osd.x", v) }
    }
    SettingRow {
        key: "osd.y";
        icon: "swap_vert"; title: "Vertical position"; desc: "0 %: the top, 100 %: the bottom"
        NumberBox { from: 0; to: 1; step: 0.01; decimals: 2; factor: 100; unit: "%"; value: Number(Store.get("osd.y", Store.get("osd.position", "bottom") === "top" ? 0.08 : 0.88)); onMoved: v => Store.set("osd.y", v) }
    }
    SettingRow {
        key: "osd.orientation"; def: "horizontal";
        icon: "screen_rotation"; title: "Direction"
        Segmented { opts: [["horizontal", "Across"], ["vertical", "Upright"]]; value: Store.get("osd.orientation", "horizontal"); onPicked: v => Store.set("osd.orientation", v) }
    }
    SettingRow {
        key: "osd.show.volume"; def: true;
        icon: "volume_up"; title: "Volume"
        Toggle { checked: Store.get("osd.show.volume", true) !== false; onToggled: on => Store.set("osd.show.volume", on) }
    }
    Repeater {
        model: [["layout", "Keyboard layout", "keyboard"], ["caps", "Caps Lock", "keyboard_capslock"], ["num", "Num Lock", "pin"], ["airplane", "Airplane mode", "airplanemode_active"]]
        SettingRow {
            required property var modelData
            icon: modelData[2]; title: modelData[1]
            Toggle { checked: Store.get("osd.show." + modelData[0], true) !== false; onToggled: on => Store.set("osd.show." + modelData[0], on) }
        }
    }
}
