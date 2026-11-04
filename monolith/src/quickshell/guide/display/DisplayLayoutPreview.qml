import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// Displays -> Arrangement: the monitors drawn where they sit on the desktop. Drag one to move it;
// it snaps to the edges and centres of the others, and on release it settles where it touches
// another monitor without overlapping it (no gaps, no overlaps). Apply writes every monitor's
// position to niri's config at once; it goes back on its own unless you keep it.
Rectangle {
    id: root
    required property var tab
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + rootObj.s(24)
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, 0.4)
    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
    border.width: ThemeBackend.liquidGlass ? 0 : 1
    visible: tab.compositor === "niri" && monitors.length > 0

    // monitors that are on: { name, label, w, h, mode }
    readonly property var monitors: tab.monitorsList.filter(m => m.active && m.lw > 0 && m.lh > 0)
        .map(m => ({ name: m.name, label: m.label || "", w: m.lw, h: m.lh, mode: m.dimensions + " • " + m.framerate + " Hz" }))

    // where each monitor is in the preview: { NAME: [x, y] } in logical pixels
    property var pos: ({})
    property bool edited: false
    property string dragging: ""
    property string selected: ""

    function actualPositions() {
        let p = {};
        for (const m of tab.monitorsList)
            if (m.active && m.lw > 0) p[m.name] = [m.x, m.y];
        return p;
    }
    function reset() {
        pos = actualPositions();
        edited = false;
    }
    // follow the real layout, except while you're arranging it
    onMonitorsChanged: if (!edited && dragging === "") reset()
    Connections {
        target: root.tab
        function onMonitorsListChanged() { if (!root.edited && root.dragging === "") root.reset(); }
    }

    function rectOf(name, p) {
        let m = monitors.find(mm => mm.name === name);
        let xy = (p || pos)[name] || [0, 0];
        return { name: name, x: xy[0], y: xy[1], w: m ? m.w : 0, h: m ? m.h : 0 };
    }
    function others(name) {
        return monitors.filter(m => m.name !== name).map(m => rectOf(m.name));
    }
    function overlaps(a, b) {
        return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
    }
    // how much edge two monitors have to share for the mouse to cross comfortably
    readonly property int minShared: 100
    // sharing at least minShared of an edge (a corner, or a sliver, doesn't count)
    function touches(a, b) {
        let need = Math.min(minShared, a.w, a.h, b.w, b.h);
        let xRange = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
        let yRange = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
        return ((a.x + a.w === b.x || b.x + b.w === a.x) && yRange >= need)
            || ((a.y + a.h === b.y || b.y + b.h === a.y) && xRange >= need);
    }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    // the closest of: side by side, aligned edges, centred, for one axis
    function snapAxis(v, size, rects, axis, threshold) {
        let best = v, bestD = threshold;
        for (const o of rects) {
            let s = axis === "x" ? o.x : o.y, l = axis === "x" ? o.w : o.h;
            for (const c of [s - size, s + l, s, s + l - size, s + (l - size) / 2]) {
                let d = Math.abs(c - v);
                if (d < bestD) { bestD = d; best = c; }
            }
        }
        return Math.round(best);
    }

    // a spot for `name` near (x, y) that touches another monitor and overlaps none
    function settle(name, x, y) {
        let me = rectOf(name);
        let rest = others(name);
        let at = { x: x, y: y, w: me.w, h: me.h };
        if (rest.length === 0) return [x, y];
        if (!rest.some(o => overlaps(at, o)) && rest.some(o => touches(at, o))) return [x, y];
        let best = null, bestD = Infinity;
        for (const o of rest) {
            let need = Math.min(minShared, me.w, me.h, o.w, o.h);
            let ys = clamp(y, o.y - me.h + need, o.y + o.h - need);
            let xs = clamp(x, o.x - me.w + need, o.x + o.w - need);
            for (const c of [[o.x - me.w, ys], [o.x + o.w, ys], [xs, o.y - me.h], [xs, o.y + o.h]]) {
                let r = { x: c[0], y: c[1], w: me.w, h: me.h };
                if (rest.some(oo => overlaps(r, oo))) continue;
                let d = Math.hypot(c[0] - x, c[1] - y);
                if (d < bestD) { bestD = d; best = c; }
            }
        }
        return best ? [Math.round(best[0]), Math.round(best[1])] : [x, y];
    }

    // top-left monitor at 0,0
    function normalized(p) {
        let names = Object.keys(p);
        if (names.length === 0) return p;
        let minX = Math.min(...names.map(n => p[n][0])), minY = Math.min(...names.map(n => p[n][1]));
        let out = {};
        for (const n of names) out[n] = [p[n][0] - minX, p[n][1] - minY];
        return out;
    }

    function differsFromActual() {
        let a = actualPositions(), p = normalized(pos), an = normalized(a);
        for (const n of Object.keys(p))
            if (!an[n] || an[n][0] !== p[n][0] || an[n][1] !== p[n][1]) return true;
        return false;
    }

    // the preview's scale and offset; frozen while dragging so the picture doesn't jump around
    property var view: ({ k: 0.05, ox: 0, oy: 0 })
    function fit() {
        if (dragging !== "" || monitors.length === 0 || area.width <= 0) return;
        let rs = monitors.map(m => rectOf(m.name));
        let minX = Math.min(...rs.map(r => r.x)), minY = Math.min(...rs.map(r => r.y));
        let maxX = Math.max(...rs.map(r => r.x + r.w)), maxY = Math.max(...rs.map(r => r.y + r.h));
        let pad = rootObj.s(16);
        // room around the layout, so a monitor can be dragged past the others' edges
        let k = Math.min((area.width - pad * 2) / ((maxX - minX) * 1.12), (area.height - pad * 2) / ((maxY - minY) * 1.12));
        view = {
            k: k,
            ox: (area.width - (maxX - minX) * k) / 2 - minX * k,
            oy: (area.height - (maxY - minY) * k) / 2 - minY * k
        };
    }
    onPosChanged: fit()

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(8)

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(4)
            Layout.rightMargin: rootObj.s(4)
            spacing: rootObj.s(8)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: rootObj.s(2)
                Text {
                    text: "Arrangement"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(16)
                    font.bold: true
                    color: ThemeBackend.text
                }
                Text {
                    Layout.fillWidth: true
                    text: root.monitors.length > 1
                        ? "Drag the monitors to match where they are on your desk. The mouse moves between screens where their edges touch."
                        : "Connect another monitor to arrange your screens."
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    color: ThemeBackend.subtext0
                    wrapMode: Text.WordWrap
                }
            }

            ClickButton {
                visible: root.edited && !root.tab.pendingLayout
                implicitHeight: rootObj.s(30)
                horizontalPadding: rootObj.s(14)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: "Reset"
                textFontSize: rootObj.s(11)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: root.reset()
            }
            ClickButton {
                visible: root.edited && !root.tab.pendingLayout
                implicitHeight: rootObj.s(30)
                horizontalPadding: rootObj.s(14)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: "Apply"
                textFontSize: rootObj.s(11)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: {
                    root.pos = root.normalized(root.pos);
                    root.tab.applyLayout(root.pos);
                    root.edited = false;
                }
            }
        }

        // applied right away; kept only once confirmed
        Rectangle {
            Layout.fillWidth: true
            visible: !!root.tab.pendingLayout
            implicitHeight: confirmRow.implicitHeight + rootObj.s(16)
            radius: ThemeBackend.rad(ThemeBackend.borderRadius)
            color: Qt.alpha(ThemeBackend.mauve, 0.16)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.mauve, 0.5)

            RowLayout {
                id: confirmRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: rootObj.s(12)
                anchors.rightMargin: rootObj.s(8)
                spacing: rootObj.s(8)

                Text {
                    Layout.fillWidth: true
                    text: "Keep this arrangement? Going back in " + (root.tab.pendingLayout ? root.tab.pendingLayout.left : 0) + " s"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    wrapMode: Text.WordWrap
                }
                ClickButton {
                    implicitHeight: rootObj.s(30)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Revert"
                    textFontSize: rootObj.s(11)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: root.tab.revertLayout()
                }
                ClickButton {
                    implicitHeight: rootObj.s(30)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Keep"
                    textFontSize: rootObj.s(11)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: root.tab.keepLayout()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(4)
            visible: root.tab.outputError !== ""
            text: root.tab.outputError
            color: ThemeBackend.red
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: area
            Layout.fillWidth: true
            Layout.preferredHeight: rootObj.s(260)
            radius: ThemeBackend.rad(ThemeBackend.borderRadius)
            color: Qt.alpha(ThemeBackend.crust, 0.35)
            clip: true
            onWidthChanged: root.fit()
            onHeightChanged: root.fit()
            Component.onCompleted: root.fit()

            Repeater {
                model: root.monitors
                delegate: Rectangle {
                    id: mon
                    required property var modelData
                    readonly property var r: root.rectOf(modelData.name)
                    readonly property bool active: root.dragging === modelData.name || root.selected === modelData.name

                    x: r.x * root.view.k + root.view.ox
                    y: r.y * root.view.k + root.view.oy
                    width: Math.max(4, r.w * root.view.k - 2)
                    height: Math.max(4, r.h * root.view.k - 2)
                    z: root.dragging === modelData.name ? 2 : 1
                    radius: ThemeBackend.rad(rootObj.s(6))
                    color: active ? Qt.alpha(ThemeBackend.mauve, 0.28) : Qt.alpha(ThemeBackend.surface1, 0.9)
                    border.width: active ? 2 : 1
                    border.color: active ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.9)

                    Behavior on x { enabled: root.dragging !== mon.modelData.name; NumberAnimation { duration: 180 * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: root.dragging !== mon.modelData.name; NumberAnimation { duration: 180 * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 * ThemeBackend.animScale } }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - rootObj.s(8)
                        spacing: rootObj.s(2)
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: mon.modelData.name
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(8, Math.min(rootObj.s(14), mon.height / 4))
                            font.bold: true
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: mon.height > rootObj.s(48)
                            text: mon.modelData.label
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(7, Math.min(rootObj.s(11), mon.height / 6))
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: mon.height > rootObj.s(36)
                            text: mon.modelData.mode
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Math.max(7, Math.min(rootObj.s(11), mon.height / 6))
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.monitors.length > 1 && !root.tab.pendingLayout
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point start
                        property var startPos: [0, 0]

                        onPressed: function(mouse) {
                            let p = mapToItem(area, mouse.x, mouse.y);
                            start = Qt.point(p.x, p.y);
                            startPos = root.pos[mon.modelData.name].slice();
                            root.dragging = mon.modelData.name;
                            root.selected = mon.modelData.name;
                        }
                        onPositionChanged: function(mouse) {
                            if (!pressed) return;
                            let p = mapToItem(area, mouse.x, mouse.y);
                            let k = root.view.k;
                            let nx = startPos[0] + (p.x - start.x) / k;
                            let ny = startPos[1] + (p.y - start.y) / k;
                            let rest = root.others(mon.modelData.name);
                            let threshold = rootObj.s(10) / k;
                            nx = root.snapAxis(nx, mon.r.w, rest, "x", threshold);
                            ny = root.snapAxis(ny, mon.r.h, rest, "y", threshold);
                            let np = Object.assign({}, root.pos);
                            np[mon.modelData.name] = [nx, ny];
                            root.pos = np;
                        }
                        onReleased: {
                            let xy = root.pos[mon.modelData.name];
                            let np = Object.assign({}, root.pos);
                            np[mon.modelData.name] = root.settle(mon.modelData.name, xy[0], xy[1]);
                            root.dragging = "";
                            root.pos = np;
                            root.edited = root.differsFromActual();
                        }
                    }
                }
            }
        }
    }
}
