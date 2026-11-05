import QtQuick
import Quickshell.Hyprland
import "../../../reusables"
import "../../../"

// Workspaces as slabs (Monolith's default): a thin upright bar per workspace, like the logo.
// The current one stands tallest in the accent colour, ones with windows are mid-height,
// empty ones are short and faint. Click one to go there.
Item {
    id: root
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    function s(v) { return widget ? widget.s(v) : v; }

    readonly property real thick: s(widget && widget.isCompact ? 4 : 5)
    readonly property real tall: s(widget && widget.isCompact ? 18 : 22)
    readonly property real gap: s(widget && widget.isCompact ? 5 : 6)

    function isShown(index) {
        if (!widget) return false;
        if (typeof widget.isShown === "function") return widget.isShown(index);
        return true;
    }

    implicitWidth: flow.implicitWidth + s(8)
    implicitHeight: flow.implicitHeight + s(4)

    AxisFlow {
        id: flow
        vertical: root.isVertical
        anchors.centerIn: parent
        spacing: ThemeBackend.orbit ? root.s(3) : root.gap

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: ws
                required property int index
                readonly property bool active: widget ? index === widget.activeIndex : false
                readonly property bool occupied: widget ? widget.isOccupied(index) : false
                readonly property bool hovered: wsMa.containsMouse
                readonly property real length: active ? root.tall : (hovered ? root.tall * 0.85 : (occupied ? root.tall * 0.62 : root.tall * 0.36))
                visible: root.isShown(index)

                // Orbit: the current workspace is an accent pill with its number, ones with windows
                // filled dots, empty ones hollow rings; they slide as the pill moves
                readonly property bool orbit: ThemeBackend.orbit
                property real orbitMain: ws.active ? root.s(34) : root.s(12)
                Behavior on orbitMain { NumberAnimation { duration: (360) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }

                // a bit wider than the slab so it's easy to hit
                width: orbit ? (root.isVertical ? root.tall : (visible ? ws.orbitMain + root.s(2) : 0))
                             : (root.isVertical ? root.tall : (visible ? root.thick + root.s(6) : 0))
                height: orbit ? (root.isVertical ? (visible ? ws.orbitMain + root.s(2) : 0) : root.tall)
                              : (root.isVertical ? (visible ? root.thick + root.s(6) : 0) : root.tall)

                Rectangle {
                    visible: ws.orbit
                    anchors.centerIn: parent
                    readonly property real dot: ws.active ? root.s(18) : (ws.occupied || ws.hovered ? root.s(10) : root.s(9))
                    width: root.isVertical ? dot : ws.orbitMain
                    height: root.isVertical ? ws.orbitMain : dot
                    radius: Math.min(Math.min(width, height) / 2, ThemeBackend.borderRadius + 4)
                    color: ws.active ? ThemeBackend.mauve : (ws.occupied ? Qt.alpha(ThemeBackend.text, ws.hovered ? 0.85 : 0.6) : (ws.hovered ? Qt.alpha(ThemeBackend.text, 0.3) : "transparent"))
                    border.width: (!ws.active && !ws.occupied) ? Math.max(1, root.s(1.5)) : 0
                    border.color: Qt.alpha(ThemeBackend.text, 0.35)
                    Behavior on color { ColorAnimation { duration: (220) * ThemeBackend.animScale } }
                    Behavior on height { NumberAnimation { duration: (360) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
                    Behavior on width { NumberAnimation { duration: (360) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
                    Text {
                        anchors.centerIn: parent
                        text: ws.index + 1
                        opacity: ws.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: (200) * ThemeBackend.animScale } }
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.DemiBold
                        font.pixelSize: root.s(10)
                        color: ThemeBackend.onPrimary
                    }
                }

                Rectangle {
                    visible: !ws.orbit
                    anchors.centerIn: parent
                    width: root.isVertical ? ws.length : root.thick
                    height: root.isVertical ? root.thick : ws.length
                    radius: ThemeBackend.rad(root.thick / 2)
                    color: ws.active ? ThemeBackend.mauve
                        : Qt.alpha(ThemeBackend.text, ws.hovered ? 0.8 : (ws.occupied ? 0.55 : 0.22))
                    Behavior on width { NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutBack } }
                    Behavior on height { NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: (180) * ThemeBackend.animScale } }
                }

                MouseArea {
                    id: wsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (widget) widget.focusWorkspace(ws.index)
                }
            }
        }
    }
}
