import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Quick access: rest the pointer on the screen's edge (right or left, Settings → Desktop →
// Quick access) and a panel slides in with small tools as tabs: a calculator, a unit
// converter, notes, a timer, a drawing pad and the system's usage. It slides away when the
// pointer leaves it.
PanelWindow {
    id: qa
    required property var modelData
    screen: modelData
    readonly property bool enabled: Store.get("quick.enabled", true) !== false
    readonly property bool onLeft: Store.get("quick.edge", "right") === "left"
    readonly property var tools: Store.get("quick.tools", ["calc", "convert", "notes", "timer", "draw", "usage"])
    readonly property int speed: Number(Store.get("quick.speed", 260))
    property string tool: tools.length ? tools[0] : ""
    property bool out: false

    visible: enabled
    WlrLayershell.namespace: "monolith-quick"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: out ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: onLeft; right: !onLeft }
    implicitWidth: 460
    color: "transparent"
    // only the edge strip and (when out) the panel take the mouse
    mask: Region { item: qa.out ? panel : edge }

    // the edge: resting on it for a moment brings the panel
    Item {
        id: edge
        x: qa.onLeft ? 0 : parent.width - 2
        width: 2
        y: parent.height * 0.2
        height: parent.height * 0.6
        HoverHandler { id: edgeHover; onHoveredChanged: if (hovered) wait.restart(); else wait.stop() }
    }
    Timer { id: wait; interval: Number(Store.get("quick.delay", 250)); onTriggered: qa.out = true }
    Timer { id: leave; interval: 450; onTriggered: if (!panelHover.hovered) qa.out = false }

    Rectangle {
        id: panel
        width: 420
        height: Math.min(qa.height - 120, 560)
        anchors.verticalCenter: parent.verticalCenter
        x: qa.out ? (qa.onLeft ? 12 : qa.width - width - 12) : (qa.onLeft ? -width - 30 : qa.width + 30)
        Behavior on x { NumberAnimation { duration: qa.speed; easing.type: Easing.BezierSpline; easing.bezierCurve: qa.out ? Theme.springCurve : Theme.exitCurve } }
        radius: Theme.islandRadius
        color: Theme.frame
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: Theme.shadowY; shadowHorizontalOffset: Theme.shadowX }
        HoverHandler { id: panelHover; onHoveredChanged: if (!hovered) leave.restart(); else leave.stop() }

        // the tools as tabs down the side
        Column {
            id: rail
            x: 10; y: 10
            spacing: 6
            Repeater {
                model: qa.tools
                Pressable {
                    required property string modelData
                    readonly property bool on: qa.tool === modelData
                    width: 44; height: 44
                    color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                    onClicked: qa.tool = modelData
                    Icon {
                        anchors.centerIn: parent
                        name: ({ calc: "calculate", convert: "swap_horiz", notes: "sticky_note_2", timer: "timer", draw: "draw", usage: "monitoring" })[parent.modelData] || "help"
                        size: 21; filled: parent.on
                        color: parent.on ? Theme.onAccentContainer : Theme.text
                    }
                }
            }
        }
        Loader {
            x: rail.x + rail.width + 10; y: 12
            width: panel.width - x - 12
            height: panel.height - 24
            active: qa.out || panel.x !== (qa.onLeft ? -panel.width - 30 : qa.width + 30)
            source: "quick/" + ({ calc: "Calc", convert: "Convert", notes: "Notes", timer: "Timer", draw: "Draw", usage: "Usage" })[qa.tool] + ".qml"
        }
    }
}
