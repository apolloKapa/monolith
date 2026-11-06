import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Quick access: the mini bar that slides out of a screen edge, how it behaves, and its tools.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var all: [["calc", "Calculator", "calculate"], ["convert", "Converter", "swap_horiz"], ["notes", "Notes", "sticky_note_2"],
                                ["timer", "Timer", "timer"], ["draw", "Draw", "draw"], ["usage", "System usage", "monitoring"]]
    readonly property var tools: Store.get("quick.tools", ["calc", "convert", "notes", "timer", "draw", "usage"])

    readonly property var edges: { const e = Store.get("quick.edges", null); return Array.isArray(e) ? e : [Store.get("quick.edge", "right")]; }
    SettingRow {
        key: "quick.enabled"; def: true;
        icon: "side_navigation"; title: "Quick access"; desc: "Rest the pointer on a screen edge: a mini bar of tools slides out there. Drag it out (or click a tool) to open it fully, drag it back to fold it"
        Toggle { checked: Store.get("quick.enabled", true) !== false; onToggled: on => Store.set("quick.enabled", on) }
    }
    SettingRow {
        keys: ["quick.edges", "quick.edge"];
        icon: "border_outer"; title: "Edges"; desc: "Where it can come out (not along the bar's own edge; on the dock's edge, only away from the dock)"
        Row {
            spacing: 6
            Repeater {
                model: [["left", "Left"], ["right", "Right"], ["top", "Top"], ["bottom", "Bottom"]]
                Pressable {
                    required property var modelData
                    readonly property bool on: sec.edges.indexOf(modelData[0]) !== -1
                    width: el.implicitWidth + 28; height: 34
                    radius: 17
                    color: on ? Theme.accent : (hovered ? Theme.control : Theme.containerHigh)
                    onClicked: {
                        const l = on ? sec.edges.filter(x => x !== modelData[0]) : sec.edges.concat([modelData[0]]);
                        if (l.length) Store.set("quick.edges", l);
                    }
                    Label { id: el; anchors.centerIn: parent; text: parent.modelData[1]; color: parent.on ? Theme.onAccent : Theme.text; strong: parent.on }
                }
            }
        }
    }
    SettingRow {
        key: "quick.touch"; def: "bar";
        icon: "swipe_left"; title: "Touching the edge"; desc: "Show the mini bar first, or open the tool straight away"
        Dropdown { width: 240; opts: [["bar", "Shows the mini bar"], ["full", "Opens it fully"]]; value: Store.get("quick.touch", "bar"); onPicked: v => Store.set("quick.touch", v) }
    }
    SettingRow {
        key: "quick.size"; def: "normal";
        icon: "aspect_ratio"; title: "Size when open"
        Dropdown { width: 240; opts: [["small", "Small"], ["normal", "Normal"], ["large", "Large"]]; value: Store.get("quick.size", "normal"); onPicked: v => Store.set("quick.size", v) }
    }
    SettingRow {
        key: "quick.remember"; def: true;
        icon: "history"; title: "Open on the last tool"; desc: "Off: it always starts on the first tool"
        Toggle { checked: Store.get("quick.remember", true) !== false; onToggled: on => Store.set("quick.remember", on) }
    }
    SettingRow {
        key: "quick.edgeSize"; def: 2;
        icon: "line_weight"; title: "Edge thickness"; desc: "How wide the strip along the edge is that brings it out"
        Dropdown { width: 240; opts: [["1", "1 px"], ["2", "2 px"], ["3", "3 px"], ["4", "4 px"], ["6", "6 px"], ["8", "8 px"]]; value: String(Store.get("quick.edgeSize", 2)); onPicked: v => Store.set("quick.edgeSize", Number(v)) }
    }
    SettingRow {
        key: "quick.delay"; def: 250;
        icon: "hourglass_top"; title: "Wait before it shows"; desc: "How long the pointer rests on the edge first"
        NumberBox { from: 0; to: 3000; slideTo: 1500; step: 50; unit: "ms"; value: Number(Store.get("quick.delay", 250)); onMoved: v => Store.set("quick.delay", v) }
    }
    SettingRow {
        key: "quick.hideDelay"; def: 600;
        icon: "hourglass_bottom"; title: "Wait before it goes"; desc: "After the pointer leaves it (pinned, or while you type in it, it stays)"
        NumberBox { from: 0; to: 5000; slideTo: 2000; step: 50; unit: "ms"; value: Number(Store.get("quick.hideDelay", 600)); onMoved: v => Store.set("quick.hideDelay", v) }
    }
    SettingRow {
        key: "quick.speed"; def: 260;
        icon: "speed"; title: "Slide speed"; desc: "How long sliding out and opening take"
        NumberBox { from: 0; to: 2000; slideTo: 800; step: 10; unit: "ms"; value: Number(Store.get("quick.speed", 260)); onMoved: v => Store.set("quick.speed", v) }
    }
    SettingRow {
        key: "quick.offInGameMode"; def: true;
        icon: "sports_esports"; title: "Off in Game mode"; desc: "While Game mode is on, the edges do nothing"
        Toggle { checked: Store.get("quick.offInGameMode", true) !== false; onToggled: on => Store.set("quick.offInGameMode", on) }
    }
    SettingRow {
        key: "quick.overFullscreen"; def: false;
        icon: "fullscreen"; title: "Over fullscreen windows"; desc: "Off: a fullscreen game or video keeps its edges"
        Toggle { checked: Store.get("quick.overFullscreen", false) === true; onToggled: on => Store.set("quick.overFullscreen", on) }
    }
    SettingRow {
        key: "quick.emptyOnly"; def: false;
        icon: "desktop_windows"; title: "Only on an empty workspace"; desc: "It comes out only when the workspace has no windows"
        Toggle { checked: Store.get("quick.emptyOnly", false) === true; onToggled: on => Store.set("quick.emptyOnly", on) }
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
