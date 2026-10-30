import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Workspace overview (monolith msg toggle overview): every monitor's workspaces as rows, each
// window drawn to scale in niri's scrolling columns. Click a window to go to it, click a row
// to switch workspace. Typing searches windows and apps; Enter opens the first match.
PopupShell {
    id: root
    framed: false

    property var outputs: ({})
    property var workspaces: []
    property var windows: []
    property string query: ""
    property int current: 0

    readonly property string q: query.trim().toLowerCase()
    function matches(w) {
        return q !== "" && ((w.title || "") + " " + (w.app_id || "")).toLowerCase().indexOf(q) !== -1;
    }
    readonly property var windowHits: q === "" ? [] : windows.filter(w => matches(w))
    readonly property var appHits: {
        if (q === "" || !DesktopEntries.applications) return [];
        let out = [];
        for (let e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            let hay = (e.name + " " + (e.genericName || "") + " " + (e.keywords || []).join(" ")).toLowerCase();
            if (hay.indexOf(q) !== -1) out.push(e);
            if (out.length >= 6) break;
        }
        return out;
    }
    // what Enter / arrows walk through: matching windows, then apps
    readonly property var results: windowHits.map(w => ({ kind: "window", win: w })).concat(appHits.map(a => ({ kind: "app", app: a })))

    // rows: workspaces that have windows, plus each monitor's current one, monitor by monitor
    readonly property var rows: {
        let used = {};
        for (let w of windows) used[w.workspace_id] = true;
        let list = workspaces.filter(ws => used[ws.id] || ws.is_active);
        list.sort((a, b) => (a.output || "").localeCompare(b.output || "") || a.idx - b.idx);
        return list;
    }

    focusTarget: search.field

    onOpened: {
        search.clear();
        root.current = 0;
        refresh();
    }
    onQueryChanged: root.current = 0

    function refresh() {
        loader.running = false;
        loader.running = true;
    }

    function iconFor(appId) {
        let e = AppMatcher.entry(AppMatcher.resolve(appId));
        let name = e && e.icon ? e.icon : appId;
        // an icon picked from a file (Settings -> Theme -> Icons) is a path, not a theme name
        if (String(name).startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, true) || Quickshell.iconPath(String(appId).toLowerCase(), true) || "";
    }

    function focusWindow(id) {
        root.close();
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]);
    }
    function focusWorkspace(ws) {
        root.close();
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", ws.name ? ws.name : String(ws.idx)]);
    }
    function activate(r) {
        if (!r) return;
        if (r.kind === "window") {
            focusWindow(r.win.id);
        } else {
            root.close();
            r.app.execute();
        }
    }

    Process {
        id: loader
        command: ["sh", "-c", "printf '{\"windows\":%s,\"workspaces\":%s,\"outputs\":%s}' \"$(niri msg -j windows)\" \"$(niri msg -j workspaces)\" \"$(niri msg -j outputs)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text);
                    root.outputs = d.outputs;
                    root.workspaces = d.workspaces;
                    root.windows = d.windows;
                } catch (e) {}
            }
        }
    }

    // backdrop: dim + click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.crust, 0.72)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.s(48)
        anchors.topMargin: root.s(64)
        spacing: root.s(18)

        SearchBox {
            id: search
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.s(520)
            placeholderText: I18n.t("overview.search", "Search windows and apps…")
            onTextChanged: root.query = text
            onNavigate: (d) => { let n = root.results.length; if (n) root.current = (root.current + d + n) % n; }
            onAccepted: root.activate(root.results[root.current])
        }

        // search results (only while typing)
        Flow {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width * 0.8
            visible: root.q !== ""
            spacing: root.s(8)

            Repeater {
                model: root.results
                Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.current
                    width: Math.min(root.s(320), resRow.implicitWidth + root.s(24))
                    height: root.s(40)
                    radius: ThemeBackend.borderRadius
                    color: sel ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface0, 0.85)
                    border.width: ThemeBackend.outlined ? ThemeBackend.outlineInner : 0
                    border.color: ThemeBackend.outlineColor
                    RowLayout {
                        id: resRow
                        anchors.fill: parent
                        anchors.leftMargin: root.s(10)
                        anchors.rightMargin: root.s(12)
                        spacing: root.s(8)
                        Image {
                            Layout.preferredWidth: root.s(22); Layout.preferredHeight: root.s(22)
                            sourceSize: Qt.size(root.s(44), root.s(44))
                            source: res.modelData.kind === "window" ? root.iconFor(res.modelData.win.app_id) : (String(res.modelData.app.icon).startsWith("/") ? "file://" + res.modelData.app.icon : Quickshell.iconPath(res.modelData.app.icon, true))
                        }
                        Text {
                            Layout.fillWidth: true
                            text: res.modelData.kind === "window" ? (res.modelData.win.title || res.modelData.win.app_id) : res.modelData.app.name
                            color: res.sel ? ThemeBackend.crust : ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            elide: Text.ElideRight
                        }
                        Text {
                            text: res.modelData.kind === "window" ? I18n.t("overview.window", "window") : I18n.t("overview.app", "open")
                            color: res.sel ? ThemeBackend.crust : ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activate(res.modelData) }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: rowsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rowsCol
                width: parent.width
                spacing: root.s(14)

                Repeater {
                    model: root.rows

                    Rectangle {
                        id: wsRow
                        required property var modelData
                        readonly property var out: root.outputs[modelData.output]
                        readonly property real outW: out && out.logical ? out.logical.width : 1920
                        readonly property real outH: out && out.logical ? out.logical.height : 1080
                        readonly property real k: (height - root.s(44)) / outH
                        readonly property var wins: root.windows.filter(w => w.workspace_id === modelData.id)
                        readonly property var tiled: wins.filter(w => !w.is_floating && w.layout && w.layout.pos_in_scrolling_layout)
                        readonly property var floating: wins.filter(w => w.is_floating)
                        // columns: [[window, ...], ...] in niri's order
                        readonly property var cols: {
                            let byCol = {};
                            for (let w of tiled) {
                                let c = w.layout.pos_in_scrolling_layout[0];
                                (byCol[c] = byCol[c] || []).push(w);
                            }
                            return Object.keys(byCol).map(Number).sort((a, b) => a - b)
                                .map(c => byCol[c].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]));
                        }

                        width: rowsCol.width
                        height: root.s(250)
                        radius: ThemeBackend.borderRadius
                        color: Qt.alpha(ThemeBackend.base, (ThemeBackend.glassActive || ThemeBackend.liquidGlass) ? 0.55 : 0.94)
                        border.width: modelData.is_active ? 2 : (ThemeBackend.outlined ? ThemeBackend.outlineInner : 0)
                        border.color: modelData.is_active ? Qt.alpha(ThemeBackend.mauve, 0.7) : ThemeBackend.outlineColor

                        WallpaperBlur {
                            z: -1
                            anchors.fill: parent
                            radius: parent.radius
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: wsRow.modelData.is_focused
                            color: Qt.alpha(ThemeBackend.mauve, 0.08)
                        }

                        MouseArea { anchors.fill: parent; onClicked: root.focusWorkspace(wsRow.modelData) }

                        Caption {
                            id: wsLabel
                            x: root.s(14); y: root.s(12)
                            text: (wsRow.modelData.name || wsRow.modelData.idx) + "  /  " + (wsRow.modelData.output || "")
                            accent: wsRow.modelData.is_active
                        }

                        Flickable {
                            id: colsFlick
                            anchors.fill: parent
                            anchors.topMargin: root.s(34)
                            anchors.leftMargin: root.s(10)
                            anchors.rightMargin: root.s(10)
                            anchors.bottomMargin: root.s(10)
                            contentWidth: Math.max(width, colsRow.implicitWidth)
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: colsRow
                                x: Math.max(0, (colsFlick.width - implicitWidth) / 2)
                                height: parent.height
                                spacing: root.s(8)

                                Repeater {
                                    model: wsRow.cols.concat(wsRow.floating.map(w => [w]))

                                    Column {
                                        id: colItem
                                        required property var modelData
                                        spacing: root.s(6)
                                        height: colsRow.height

                                        Repeater {
                                            model: colItem.modelData

                                            Rectangle {
                                                id: tile
                                                required property var modelData
                                                readonly property bool hit: root.matches(modelData)
                                                width: Math.max(root.s(90), (modelData.layout.tile_size ? modelData.layout.tile_size[0] : 600) * wsRow.k)
                                                height: (colItem.height - (colItem.modelData.length - 1) * colItem.spacing) / colItem.modelData.length
                                                radius: ThemeBackend.rad(root.s(8))
                                                color: tile.modelData.is_focused ? Qt.alpha(ThemeBackend.mauve, 0.28) : (tileMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                                                border.width: hit ? 2 : (ThemeBackend.outlined ? ThemeBackend.outlineInner : 1)
                                                border.color: hit ? ThemeBackend.mauve : (ThemeBackend.outlined ? ThemeBackend.outlineColor : Qt.alpha(ThemeBackend.text, 0.08))
                                                opacity: root.q === "" || hit ? 1 : 0.35
                                                Behavior on opacity { NumberAnimation { duration: (150) * ThemeBackend.animScale } }

                                                // a little window: title bar with the title, the app icon in the middle
                                                Rectangle {
                                                    id: titleBar
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: root.s(22)
                                                    topLeftRadius: tile.radius
                                                    topRightRadius: tile.radius
                                                    color: Qt.alpha(ThemeBackend.crust, 0.35)
                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: root.s(8)
                                                        anchors.rightMargin: root.s(22)
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: tile.modelData.title || tile.modelData.app_id
                                                        color: ThemeBackend.subtext1
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: root.s(10)
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                                Image {
                                                    id: tileIcon
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: titleBar.height / 2
                                                    width: Math.min(root.s(56), (parent.height - titleBar.height) * 0.55); height: width
                                                    sourceSize: Qt.size(root.s(112), root.s(112))
                                                    source: root.iconFor(tile.modelData.app_id)
                                                }
                                                Text {
                                                    visible: tile.modelData.is_floating
                                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: root.s(6)
                                                    text: "󰖲"
                                                    color: ThemeBackend.subtext0
                                                    font.family: ThemeBackend.iconFont
                                                    font.pixelSize: root.s(12)
                                                }
                                                MouseArea {
                                                    id: tileMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.focusWindow(tile.modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            WheelScroll {}
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: wsRow.wins.length === 0
                            text: I18n.t("overview.empty", "Empty")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                        }
                    }
                }
            }

            WheelScroll {}
        }
    }
}
