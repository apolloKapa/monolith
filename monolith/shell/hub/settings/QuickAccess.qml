import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Quick access: the panel that slides in from the screen's edge, and what's in it.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var all: [["calc", "Calculator", "calculate"], ["convert", "Converter", "swap_horiz"], ["notes", "Notes", "sticky_note_2"],
                                ["timer", "Timer", "timer"], ["draw", "Draw", "draw"], ["usage", "System usage", "monitoring"]]
    readonly property var tools: Store.get("quick.tools", ["calc", "convert", "notes", "timer", "draw", "usage"])

    SettingRow {
        key: "quick.enabled"; def: true;
        icon: "side_navigation"; title: "Quick access"; desc: "Rest the pointer on the screen's edge and a panel of small tools slides in"
        Toggle { checked: Store.get("quick.enabled", true) !== false; onToggled: on => Store.set("quick.enabled", on) }
    }
    SettingRow {
        key: "quick.edge"; def: "right";
        icon: "border_right"; title: "Which edge"
        Segmented { opts: [["left", "Left"], ["right", "Right"]]; value: Store.get("quick.edge", "right"); onPicked: v => Store.set("quick.edge", v) }
    }
    SettingRow {
        key: "quick.delay"; def: 250;
        icon: "hourglass_top"; title: "Wait before it opens"; desc: "How long the pointer rests on the edge first"
        NumberBox { from: 0; to: 3000; slideTo: 1500; step: 50; unit: "ms"; value: Number(Store.get("quick.delay", 250)); onMoved: v => Store.set("quick.delay", v) }
    }
    SettingRow {
        key: "quick.speed"; def: 260;
        icon: "speed"; title: "Slide speed"; desc: "How long sliding in takes"
        NumberBox { from: 0; to: 2000; slideTo: 800; step: 10; unit: "ms"; value: Number(Store.get("quick.speed", 260)); onMoved: v => Store.set("quick.speed", v) }
    }
    Label { text: "Tools (in this order)"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    Repeater {
        model: sec.all
        SettingRow {
            key: "quick.tools";
            required property var modelData
            readonly property int at: sec.tools.indexOf(modelData[0])
            icon: modelData[2]; title: modelData[1]
            desc: at >= 0 ? "Tab " + (at + 1) : "Not in the panel"
            Row {
                spacing: 4
                Pressable { visible: at > 0; width: 32; height: 32; color: hovered ? Theme.control : "transparent"
                    onClicked: { const l = sec.tools.slice(); const t = l[at]; l[at] = l[at - 1]; l[at - 1] = t; Store.set("quick.tools", l); }
                    Icon { anchors.centerIn: parent; name: "arrow_upward"; size: 17 } }
                Toggle {
                    checked: at >= 0
                    onToggled: on => Store.set("quick.tools", on ? sec.tools.concat([modelData[0]]) : sec.tools.filter(x => x !== modelData[0]))
                }
            }
        }
    }
}
