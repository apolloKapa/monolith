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
        spacing: root.gap

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

                // a bit wider than the slab so it's easy to hit
                width: root.isVertical ? root.tall : (visible ? root.thick + root.s(6) : 0)
                height: root.isVertical ? (visible ? root.thick + root.s(6) : 0) : root.tall

                Rectangle {
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
