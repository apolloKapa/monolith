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
    // only where there's a bar (Settings -> Bar -> General -> Monitors)
    model: Config.screensFor("bar")

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
            // what's taken on each side: the bar on its edge, the frame on the others.
            // A bar that doesn't hold its whole edge (auto-hiding, or narrower than the screen:
            // Bar -> Width) leaves it to the frame, which runs along it like the others; a
            // narrower bar hangs from it as a notch (bar/TopBar.qml frameInset)
            readonly property bool barSpans: barCfg.autohide !== true && !(Number(barCfg.width) < 100)
            readonly property real edgeBar: barSpans ? barH : thickness
            readonly property bool barVertical: barPos === "left" || barPos === "right"
            readonly property real topIn: barPos === "top" ? edgeBar : thickness
            readonly property real bottomIn: barPos === "bottom" ? edgeBar : thickness
            readonly property real leftIn: barPos === "left" ? edgeBar : thickness
            readonly property real rightIn: barPos === "right" ? edgeBar : thickness
            // Blur / Liquid glass: one sheet of glass round the whole screen (bar edge included)
            // with a rounded hole for the desktop. Separate strips each drew their own glass edge,
            // which showed as cuts where they met the bar, and the flat corners didn't match.
            readonly property bool glass: ThemeBackend.seeThrough

            component Strip: PanelWindow {
                id: strip
                screen: frame.modelData
                ReservedReport { window: strip }
                visible: frame.enabled
                color: "transparent"
                WlrLayershell.namespace: "qs-frame"
                WlrLayershell.layer: WlrLayer.Top
                mask: Region {}
                Rectangle {
                    anchors.fill: parent
                    // see-through styles: the strip only reserves its edge, the sheet below draws
                    visible: !frame.glass
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

            // a notch bar's edge: the frame runs along it under the bar (Bottom layer), without
            // reserving it or pushing the bar off the edge (the bar reserves that edge itself)
            PanelWindow {
                screen: frame.modelData
                visible: frame.enabled && frame.thickness > 0 && !frame.barSpans && frame.barCfg.autohide !== true
                color: "transparent"
                anchors {
                    top: frame.barPos === "top" || frame.barVertical
                    bottom: frame.barPos === "bottom" || frame.barVertical
                    left: frame.barPos === "left" || !frame.barVertical
                    right: frame.barPos === "right" || !frame.barVertical
                }
                implicitWidth: frame.thickness
                implicitHeight: frame.thickness
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "qs-frame"
                WlrLayershell.layer: WlrLayer.Bottom
                mask: Region {}
                Rectangle {
                    anchors.fill: parent
                    // see-through styles: the sheet below draws it
                    visible: !frame.glass
                    color: frame.color
                }
            }

            // the see-through frame: below windows, so a window reaching into a rounded corner
            // sits on the glass instead of being cut by a flat corner patch
            PanelWindow {
                screen: frame.modelData
                visible: frame.enabled && frame.glass
                color: "transparent"
                anchors { left: true; right: true; top: true; bottom: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "qs-frame-glass"
                WlrLayershell.layer: WlrLayer.Bottom
                mask: Region {}

                Item {
                    id: sheet
                    anchors.fill: parent
                    readonly property rect hole: Qt.rect(frame.leftIn, frame.topIn,
                        width - frame.leftIn - frame.rightIn, height - frame.topIn - frame.bottomIn)
                    // the glass's outer edge sits off screen: the only rim is round the hole
                    readonly property real offscreen: 64
                    // a bar narrower than its edge (bar/TopBar.qml, SideBar.qml): the glass runs
                    // round it too. Its window starts after the frame strips on the sides.
                    readonly property var notch: frame.barSpans ? undefined : FrameNotch.notches[frame.modelData.name]
                    readonly property rect notchRect: {
                        const n = sheet.notch;
                        if (!n || n.edge !== frame.barPos || n.to - n.from < 1) return Qt.rect(0, 0, 0, 0);
                        const o = sheet.offscreen;
                        const len = n.to - n.from;
                        if (n.edge === "top") return Qt.rect(frame.leftIn + n.from, -o, len, n.depth + o);
                        if (n.edge === "bottom") return Qt.rect(frame.leftIn + n.from, height - n.depth, len, n.depth + o);
                        if (n.edge === "left") return Qt.rect(-o, frame.topIn + n.from, n.depth + o, len);
                        return Qt.rect(width - n.depth, frame.topIn + n.from, n.depth + o, len);
                    }
                    readonly property real notchRadius: sheet.notch ? sheet.notch.radius : 0
                    readonly property real notchFillet: sheet.notch ? sheet.notch.fillet : 0

                    WallpaperBlur {
                        anchors.fill: parent
                        standalone: true
                        radius: 0
                        boxRect: Qt.rect(-sheet.offscreen, -sheet.offscreen, width + 2 * sheet.offscreen, height + 2 * sheet.offscreen)
                        holeRect: sheet.hole
                        holeRadius: frame.radius
                        notchRect: sheet.notchRect
                        notchRadius: sheet.notchRadius
                        notchFillet: sheet.notchFillet
                    }
                    ShaderEffect {
                        anchors.fill: parent
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property color color: frame.color
                        property vector4d hole: Qt.vector4d(sheet.hole.x + sheet.hole.width * 0.5 - width * 0.5, sheet.hole.y + sheet.hole.height * 0.5 - height * 0.5, sheet.hole.width * 0.5, sheet.hole.height * 0.5)
                        property real holeRadius: frame.radius
                        property vector4d notch: sheet.notchRect.width > 0 ? Qt.vector4d(sheet.notchRect.x + sheet.notchRect.width * 0.5 - width * 0.5, sheet.notchRect.y + sheet.notchRect.height * 0.5 - height * 0.5, sheet.notchRect.width * 0.5, sheet.notchRect.height * 0.5) : Qt.vector4d(0, 0, 0, 0)
                        property vector2d notchRadii: Qt.vector2d(sheet.notchRadius, sheet.notchFillet)
                        fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/frame_tint.frag.qsb"
                    }
                }
            }

            // solid styles: the four rounded inner corners, over everything, clicks pass through
            PanelWindow {
                screen: frame.modelData
                visible: frame.enabled && !frame.glass
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
