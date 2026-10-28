import QtQuick
import Quickshell
import "../../"

// Put inside a PanelWindow that reserves an edge (exclusiveZone): tells ReservedSpace how much
// of its screen it takes, so the Settings app knows where tiled windows go.
Item {
    id: report
    required property var window
    // what niri counts on top of the exclusive zone: the margin on that edge
    property bool countMargin: true

    readonly property string edge: {
        const a = report.window.anchors;
        const n = (a.top ? 1 : 0) + (a.bottom ? 1 : 0) + (a.left ? 1 : 0) + (a.right ? 1 : 0);
        if (n === 1) return a.top ? "top" : a.bottom ? "bottom" : a.left ? "left" : "right";
        // three edges: it holds the one whose opposite is free
        if (n === 3) return !a.bottom ? "top" : !a.top ? "bottom" : !a.right ? "left" : "right";
        return "";
    }
    readonly property real size: {
        const w = report.window;
        if (!w.visible || w.exclusionMode === ExclusionMode.Ignore || report.edge === "") return 0;
        const z = Number(w.exclusiveZone) || 0;
        if (z <= 0) return 0;
        return z + (report.countMargin ? (Number(w.margins[report.edge]) || 0) : 0);
    }
    readonly property string screenName: report.window.screen ? report.window.screen.name : ""

    property string key: ""
    function push() { if (report.key !== "") ReservedSpace.report(report.key, report.screenName, report.edge, report.size); }
    onSizeChanged: push()
    onEdgeChanged: push()
    onScreenNameChanged: push()
    Component.onCompleted: { report.key = ReservedSpace.newKey(); push(); }
    Component.onDestruction: ReservedSpace.report(report.key, "", "", 0)
}
