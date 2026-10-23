import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

// The Frame bar style (Settings -> Bar -> Style -> Frame): the bar runs into a solid frame
// around the whole screen, with rounded inner corners where it meets the desktop. The side and
// bottom strips reserve their space (windows tile inside the frame) and let clicks through.
// Popups open as drawers pulled out of the frame (Main.qml).
Variants {
    model: Quickshell.screens

    delegate: Component {
        Scope {
            id: frame
            required property var modelData

            readonly property var barCfg: Config.getSetting("bar", {}) || {}
            readonly property bool enabled: barCfg.style === "frame"
            readonly property string barPos: barCfg.position || "top"
            readonly property real thickness: Scaler.s(barCfg.frameThickness !== undefined ? Number(barCfg.frameThickness) : 8)
            readonly property real barH: Scaler.s(barCfg.height !== undefined ? Number(barCfg.height) : 40)
            readonly property real radius: Scaler.s(18)
            // solid, like the bar in this style (bar/Bar.qml barOpacity)
            readonly property color color: ThemeBackend.frameColor
            // what's taken on each side: the bar on its edge, the frame on the others
            // an auto-hiding bar doesn't hold its edge: the frame runs along it like the others
            readonly property real edgeBar: barCfg.autohide === true ? thickness : barH
            readonly property real topIn: barPos === "top" ? edgeBar : thickness
            readonly property real bottomIn: barPos === "bottom" ? edgeBar : thickness
            readonly property real leftIn: barPos === "left" ? edgeBar : thickness
            readonly property real rightIn: barPos === "right" ? edgeBar : thickness

            component Strip: PanelWindow {
                screen: frame.modelData
                visible: frame.enabled
                color: "transparent"
                WlrLayershell.namespace: "qs-frame"
                WlrLayershell.layer: WlrLayer.Top
                mask: Region {}
                Rectangle {
                    anchors.fill: parent
                    color: frame.color
                    // glass, like the bar and popups, in the see-through styles
                    WallpaperBlur {
                        z: -1
                        anchors.fill: parent
                        radius: 0
                        standalone: true
                    }
                }
            }

            Strip {
                visible: frame.enabled && frame.thickness > 0 && (frame.barPos !== "left" || frame.barCfg.autohide === true)
                anchors { left: true; top: true; bottom: true }
                implicitWidth: frame.thickness
                exclusiveZone: frame.thickness
            }
            Strip {
                visible: frame.enabled && frame.thickness > 0 && (frame.barPos !== "right" || frame.barCfg.autohide === true)
                anchors { right: true; top: true; bottom: true }
                implicitWidth: frame.thickness
                exclusiveZone: frame.thickness
            }
            Strip {
                visible: frame.enabled && frame.thickness > 0 && (frame.barPos !== "bottom" || frame.barCfg.autohide === true)
                anchors { left: true; right: true; bottom: true }
                implicitHeight: frame.thickness
                exclusiveZone: frame.thickness
            }
            Strip {
                visible: frame.enabled && frame.thickness > 0 && (frame.barPos !== "top" || frame.barCfg.autohide === true)
                anchors { left: true; right: true; top: true }
                implicitHeight: frame.thickness
                exclusiveZone: frame.thickness
            }

            // the four rounded inner corners, over everything, clicks pass through
            PanelWindow {
                screen: frame.modelData
                visible: frame.enabled
                color: "transparent"
                anchors { left: true; right: true; top: true; bottom: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "qs-frame-corners"
                WlrLayershell.layer: WlrLayer.Top
                mask: Region {}

                Repeater {
                    model: 4
                    ShaderEffect {
                        required property int index
                        x: (index === 0 || index === 2) ? frame.leftIn : parent.width - frame.rightIn - width
                        y: (index < 2) ? frame.topIn : parent.height - frame.bottomIn - height
                        width: frame.radius
                        height: frame.radius
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real cornerIndex: index
                        property color color: frame.color
                        fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
                    }
                }
            }
        }
    }
}
