import QtQuick
import QtQuick.Effects
import "../"
import "../reusables"

// The wallpaper picker's honeycomb: every wallpaper is a rounded hexagon, spiralling out from
// the selected one. Drag (or scroll) to move around; hexes near the middle grow, the ones at the
// edges shrink away. Click a hexagon to set it. The picker's ListView stays the source of truth
// for the selection (arrow keys, filters, search), this view follows view.currentIndex.
Flickable {
    id: grid

    required property var picker
    required property var listView
    property var model: null

    readonly property real hexR: picker.s(92)
    readonly property real gap: picker.s(10)
    readonly property real hexW: Math.sqrt(3) * hexR
    readonly property real hexH: 2 * hexR
    // spacing between centres: the hexagon plus the gap
    readonly property real stepR: hexR + gap / Math.sqrt(3)

    readonly property int count: model ? model.count : 0
    property var cells: []
    property int rings: 0

    // axial spiral: ring 0 is the middle, each ring k holds 6k cells
    function buildCells() {
        const dirs = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
        let out = [[0, 0]];
        let k = 0;
        while (out.length < count) {
            k++;
            let q = -k, r = k;
            for (let d = 0; d < 6 && out.length < count; d++) {
                for (let j = 0; j < k && out.length < count; j++) {
                    out.push([q, r]);
                    q += dirs[d][0];
                    r += dirs[d][1];
                }
            }
        }
        rings = k;
        cells = out;
    }
    onCountChanged: buildCells()
    Component.onCompleted: buildCells()

    // the honeycomb's half-size, plus room so even the outer hexes can be dragged to the middle
    readonly property real halfW: Math.sqrt(3) * stepR * (rings + 0.5)
    readonly property real halfH: 1.5 * stepR * rings + hexR
    readonly property real originX: width / 2 + halfW
    readonly property real originY: height / 2 + halfH
    contentWidth: originX * 2
    contentHeight: originY * 2

    function cellX(i) {
        const c = cells[i];
        return c ? originX + Math.sqrt(3) * stepR * (c[0] + c[1] / 2) : originX;
    }
    function cellY(i) {
        const c = cells[i];
        return c ? originY + 1.5 * stepR * c[1] : originY;
    }

    // bring a hexagon to the middle
    function centerOn(i, animate) {
        if (i < 0 || i >= cells.length || width <= 0) return;
        const tx = Math.max(0, Math.min(contentWidth - width, cellX(i) - width / 2));
        const ty = Math.max(0, Math.min(contentHeight - height, cellY(i) - height / 2));
        if (animate) {
            panX.to = tx; panY.to = ty;
            panAnim.restart();
        } else {
            contentX = tx; contentY = ty;
        }
    }

    ParallelAnimation {
        id: panAnim
        NumberAnimation { id: panX; target: grid; property: "contentX"; duration: (420) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
        NumberAnimation { id: panY; target: grid; property: "contentY"; duration: (420) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
    }
    onMovementStarted: panAnim.stop()

    Connections {
        target: grid.listView
        function onCurrentIndexChanged() { grid.centerOn(grid.listView.currentIndex, true); }
    }
    onCellsChanged: Qt.callLater(() => grid.centerOn(grid.listView.currentIndex, false))
    onWidthChanged: Qt.callLater(() => grid.centerOn(grid.listView.currentIndex, false))
    onVisibleChanged: if (visible) Qt.callLater(() => grid.centerOn(grid.listView.currentIndex, false))

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2500
    maximumFlickVelocity: 3000
    interactive: !picker.isApplying

    // one rounded hexagon, shared as the mask of every tile (all tiles are the same size)
    Canvas {
        id: hexMask
        width: Math.ceil(grid.hexW)
        height: Math.ceil(grid.hexH)
        visible: false
        layer.enabled: true
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, R = grid.hexR;
            const t = 0.2; // how far along each edge the rounding starts
            let pts = [];
            for (let i = 0; i < 6; i++) {
                const a = (Math.PI / 180) * (60 * i - 90);
                pts.push([cx + R * Math.cos(a), cy + R * Math.sin(a)]);
            }
            const lerp = (p, q, f) => [p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f];
            ctx.beginPath();
            for (let i = 0; i < 6; i++) {
                const prev = pts[(i + 5) % 6], cur = pts[i], next = pts[(i + 1) % 6];
                const a = lerp(cur, prev, t), b = lerp(cur, next, t);
                if (i === 0) ctx.moveTo(a[0], a[1]); else ctx.lineTo(a[0], a[1]);
                ctx.quadraticCurveTo(cur[0], cur[1], b[0], b[1]);
            }
            ctx.closePath();
            ctx.fillStyle = "#ffffff";
            ctx.fill();
        }
    }

    // the same shape as a ring, drawn round the selected hexagon
    Canvas {
        id: hexRing
        property color ringColor: ThemeBackend.mauve
        onRingColorChanged: requestPaint()
        width: Math.ceil(grid.hexW) + 16
        height: Math.ceil(grid.hexH) + 16
        visible: false
        layer.enabled: true
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, R = grid.hexR + 5;
            const t = 0.2;
            let pts = [];
            for (let i = 0; i < 6; i++) {
                const a = (Math.PI / 180) * (60 * i - 90);
                pts.push([cx + R * Math.cos(a), cy + R * Math.sin(a)]);
            }
            const lerp = (p, q, f) => [p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f];
            ctx.beginPath();
            for (let i = 0; i < 6; i++) {
                const prev = pts[(i + 5) % 6], cur = pts[i], next = pts[(i + 1) % 6];
                const a = lerp(cur, prev, t), b = lerp(cur, next, t);
                if (i === 0) ctx.moveTo(a[0], a[1]); else ctx.lineTo(a[0], a[1]);
                ctx.quadraticCurveTo(cur[0], cur[1], b[0], b[1]);
            }
            ctx.closePath();
            ctx.lineWidth = 4;
            ctx.strokeStyle = ringColor;
            ctx.stroke();
        }
    }

    Repeater {
        model: grid.model

        delegate: Item {
            id: tile
            required property int index
            required property var model

            readonly property string fileName: model.fileName !== undefined ? String(model.fileName) : ""
            readonly property string fileUrl: model.fileUrl !== undefined ? String(model.fileUrl) : ""
            readonly property string posterUrl: model.posterUrl !== undefined ? String(model.posterUrl) : ""
            readonly property bool isVideo: (model.isVideo !== undefined && model.isVideo !== null) ? !!model.isVideo : /\.(mp4|mkv|mov|webm)$/i.test(fileName)
            readonly property bool isCurrent: index === grid.listView.currentIndex

            readonly property real cx: grid.cellX(index)
            readonly property real cy: grid.cellY(index)
            x: cx - width / 2
            y: cy - height / 2
            width: grid.hexW
            height: grid.hexH
            z: isCurrent ? 10 : (hoverArea.containsMouse ? 5 : 1)

            // distance from the middle of the view, measured on the view's own (wide) ellipse:
            // 0 = centre, 1 = the edge
            readonly property real dist: {
                const dx = (cx - grid.contentX - grid.width / 2) / Math.max(1, grid.width / 2 - grid.hexW * 0.3);
                const dy = (cy - grid.contentY - grid.height / 2) / Math.max(1, grid.height / 2 - grid.hexR * 0.6);
                return Math.sqrt(dx * dx + dy * dy);
            }
            readonly property real falloff: Math.max(0, Math.min(1, (dist - 0.4) / 0.75))
            readonly property bool near: dist < 1.8
            property bool everNear: false
            onNearChanged: if (near) everNear = true

            visible: dist < 1.6
            scale: (1.0 - 0.55 * falloff) * (isCurrent ? 1.08 : (hoverArea.containsMouse ? 1.04 : 1.0))
            opacity: 1.0 - 0.75 * falloff * falloff
            Behavior on scale { enabled: !grid.moving; NumberAnimation { duration: (160) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: hexMask
                }

                Rectangle {
                    anchors.fill: parent
                    color: ThemeBackend.surface1
                }

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // big images: no second copy in the image cache (the GPU texture is enough)
                    cache: false
                    sourceSize.width: Math.round(grid.hexW * 1.6)
                    source: tile.everNear ? (tile.isVideo ? tile.posterUrl : tile.fileUrl) : ""
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: (200) * ThemeBackend.animScale } }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: hoverArea.pressed ? 0.25 : 0
                }
            }

            Text {
                visible: tile.isVideo
                anchors.centerIn: parent
                text: "󰐊"
                font.family: ThemeBackend.iconFont
                font.pixelSize: picker.s(30)
                color: "#ffffff"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.35)
            }

            ShaderEffectSource {
                visible: tile.isCurrent
                anchors.centerIn: parent
                width: hexRing.width
                height: hexRing.height
                sourceItem: hexRing
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !grid.picker.isApplying
                // only the hexagon itself, not the corners of its box
                containmentMask: QtObject {
                    function contains(p) {
                        const dx = Math.abs(p.x - tile.width / 2), dy = Math.abs(p.y - tile.height / 2);
                        return dx <= grid.hexW / 2 && dy <= grid.hexR - dx / Math.sqrt(3);
                    }
                }
                onClicked: {
                    grid.picker.initialFocusSet = true;
                    grid.listView.currentIndex = tile.index;
                    grid.picker.applyWallpaper(tile.fileName, tile.isVideo);
                }
            }
        }
    }

    // mouse wheel pans (shift for sideways) instead of flicking a long way
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            panAnim.stop();
            const dx = event.angleDelta.x !== 0 ? event.angleDelta.x : ((event.modifiers & Qt.ShiftModifier) ? event.angleDelta.y : 0);
            const dy = (event.modifiers & Qt.ShiftModifier) ? 0 : event.angleDelta.y;
            grid.contentX = Math.max(0, Math.min(grid.contentWidth - grid.width, grid.contentX - dx));
            grid.contentY = Math.max(0, Math.min(grid.contentHeight - grid.height, grid.contentY - dy));
        }
    }
}
