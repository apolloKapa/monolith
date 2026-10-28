//@ pragma AppId monolith-settings
//@ pragma Env MONOLITH_STANDALONE=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."
import "guide"

ShellRoot {
    id: app

    readonly property real uiScale: {
        let general = Config.getSetting("general", {});
        let v = general ? Number(general.uiScale) : NaN;
        return (isNaN(v) || v <= 0) ? 1.0 : v;
    }

    readonly property int toplevelCount: ToplevelManager.toplevels.values.length

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    IpcHandler {
        target: "settings"

        function goto(tab: string, subtab: string): void {
            popup.gotoTab(tab, subtab);
        }

        function close(): void {
            popup.closePopup();
        }

        function open(): void {
            app.openWindow();
        }

        function isOpen(): bool {
            return app.window !== null;
        }

        function focus(): void {
            let list = ToplevelManager.toplevels.values;
            for (let i = 0; i < list.length; i++) {
                if (list[i].appId === "monolith-settings") {
                    list[i].activate();
                    return;
                }
            }
        }

        function ping(): string {
            return "ok";
        }
    }

    // The settings page is loaded once (at login, see settings.sh prewarm) and kept. Each
    // time settings opens it gets a new window, which is thrown away when it closes: a window
    // niri has closed (close-window) can't be shown again, so reusing one left settings dead.
    property var window: null

    function openWindow() {
        if (app.window) return;
        app.window = windowComponent.createObject(app);
        popup.parent = app.window.contentItem;
        popup.visible = true;
    }

    function closeWindow() {
        if (!app.window) return;
        let w = app.window;
        app.window = null;
        popup.visible = false;
        popup.parent = holder;
        w.destroy();
        // nothing stays loaded in the background: the whole app quits (starts again on open)
        Qt.callLater(Qt.quit);
    }

    Component.onCompleted: if (Quickshell.env("MONOLITH_SETTINGS_HIDDEN") !== "1") openWindow()

    Item {
        id: holder
        visible: false

        GuidePopup {
            id: popup
            anchors.fill: parent
            standalone: true
            visible: false
            onExitRequested: app.closeWindow()
        }
    }

    Component {
        id: windowComponent

        FloatingWindow {
            id: win
            title: I18n.t("widgets.guide.name", "Settings")
            color: "transparent"
            implicitWidth: Math.round(1200 * app.uiScale)
            implicitHeight: Math.round(750 * app.uiScale)
            minimumSize: Qt.size(Math.round(480 * app.uiScale), Math.round(400 * app.uiScale))
            visible: true

            // where the window is on its screen, from niri (for glass: the wallpaper behind it
            // has to line up with the real one)
            readonly property var niriWindow: {
                const ws = NiriState._windows;
                for (const id in ws) if (ws[id] && ws[id].app_id === "monolith-settings") return ws[id];
                return null;
            }
            readonly property var niriLayout: niriWindow ? niriWindow.layout : null
            // the monitor niri has it on (kept while a drag takes it off every workspace)
            property string outputName: ""
            readonly property var niriWorkspace: niriWindow ? (NiriState._workspaces[niriWindow.workspace_id] || null) : null
            onNiriWorkspaceChanged: if (niriWorkspace && niriWorkspace.output) outputName = niriWorkspace.output
            readonly property var outScreen: Quickshell.screens.find(s => s.name === win.outputName) || win.screen
            // in a column (tiled, maximized or fullscreen): niri gives no position, it's worked out
            readonly property bool tiled: niriLayout !== null && !!niriLayout.pos_in_scrolling_layout
            readonly property var niriPos: {
                const l = niriLayout;
                if (!l) return null;
                const off = l.window_offset_in_tile || [0, 0];
                if (l.tile_pos_in_workspace_view)
                    return [l.tile_pos_in_workspace_view[0] + off[0], l.tile_pos_in_workspace_view[1] + off[1]];
                if (!tiled) return null;
                const p = tiledPos(l);
                return p ? [p[0] + off[0], p[1] + off[1]] : null;
            }

            // what Monolith's bar, frame, dock and island take off each edge (ReservedSpace)
            property var reserved: ({})
            FileView {
                path: Caching.getRunDir("monolith") + "/reserved.json"
                watchChanges: true
                onFileChanged: reload()
                onLoaded: {
                    try { win.reserved = JSON.parse(text()) || {}; } catch (e) { win.reserved = {}; }
                }
            }

            // a tile's spot on screen: columns sit side by side in the area the panels leave free,
            // with niri's gap around them; the tiles of a column fill its height
            function tiledPos(l) {
                const scr = win.outScreen;
                if (!scr || !l.tile_size) return null;
                if (Math.abs(l.tile_size[0] - scr.width) < 1 && Math.abs(l.tile_size[1] - scr.height) < 1) return [0, 0];
                const r = win.reserved[win.outputName] || {};
                const waX = r.left || 0;
                const waY = r.top || 0;
                const waW = scr.width - waX - (r.right || 0);
                const waH = scr.height - waY - (r.bottom || 0);
                const col = l.pos_in_scrolling_layout[0];
                const row = l.pos_in_scrolling_layout[1];
                let widths = {};
                let column = [];
                const ws = NiriState._windows;
                for (const id in ws) {
                    const w = ws[id];
                    const wl = w ? w.layout : null;
                    if (!wl || !wl.pos_in_scrolling_layout || !wl.tile_size || w.workspace_id !== win.niriWindow.workspace_id) continue;
                    const c = wl.pos_in_scrolling_layout[0];
                    widths[c] = Math.max(widths[c] || 0, wl.tile_size[0]);
                    if (c === col) column.push([wl.pos_in_scrolling_layout[1], wl.tile_size[1]]);
                }
                let sumH = 0;
                for (const t of column) sumH += t[1];
                const gap = (waH - sumH) / (column.length + 1);
                if (!(gap >= 0) || widths[col] === undefined) return null;
                let y = waY + gap;
                for (const t of column) if (t[0] < row) y += t[1] + gap;
                const cols = Object.keys(widths).map(Number);
                let before = 0;
                let strip = gap * (cols.length - 1);
                for (const c of cols) {
                    strip += widths[c];
                    if (c < col) before += widths[c] + gap;
                }
                // a column as wide as the screen allows (Mod+T maximizes) is shown exactly; when every
                // column fits, niri leaves them where they started. Otherwise the scroll is unknown.
                if (Math.abs(widths[col] + 2 * gap - waW) < 1) return [waX + gap, y];
                if (strip + 2 * gap <= waW + 1) return [waX + gap + before, y];
                return null;
            }

            // niri reports no position while it moves the window itself (Mod+drag), but the
            // window follows the pointer 1:1 then: the glass follows the mouse's own motion
            // (pointer_motion.py) from the last position niri gave, so it keeps bending the right
            // part of the wallpaper all through the drag. Positions here span all monitors, so a
            // drag onto another one switches the glass over to that monitor's wallpaper.
            readonly property var niriGlobal: niriPos && outScreen ? [outScreen.x + niriPos[0], outScreen.y + niriPos[1]] : null
            property var heldPos: [0, 0]
            property real motionX: 0
            property real motionY: 0
            property real dragBaseX: 0
            property real dragBaseY: 0
            // motion total when the left button last went down (the drag's real start)
            property real pressX: 0
            property real pressY: 0
            property bool pointerReady: false
            // the motion helper can't run (no input group): mid-drag the glass can't know where it is
            property bool pointerFailed: false
            // left button held (a drag can only be happening then)
            property bool buttonHeld: false
            // a Super+drag: position gone while the button is held
            readonly property bool dragging: niriWindow !== null && !tiled && niriPos === null && buttonHeld
            onNiriGlobalChanged: {
                if (niriGlobal) {
                    heldPos = niriGlobal;
                } else {
                    dragBaseX = pressX;
                    dragBaseY = pressY;
                }
            }
            readonly property real globalX: niriGlobal ? niriGlobal[0] : heldPos[0] + (pointerReady && dragging ? motionX - dragBaseX : 0)
            readonly property real globalY: niriGlobal ? niriGlobal[1] : heldPos[1] + (pointerReady && dragging ? motionY - dragBaseY : 0)
            // the monitor whose wallpaper the glass shows: niri's, or mid-drag the one under the
            // middle of the window (where niri will drop it)
            readonly property var glassScreenObj: {
                if (niriGlobal || !dragging) return outScreen;
                const cx = globalX + width / 2;
                const cy = globalY + height / 2;
                return Quickshell.screens.find(s => cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height) || outScreen;
            }
            property real glassScreenX: globalX - (glassScreenObj ? glassScreenObj.x : 0)
            property real glassScreenY: globalY - (glassScreenObj ? glassScreenObj.y : 0)
            // the window rule's backdrop (blurred wallpaper) shows instead when the glass can't
            // line up: a column scrolled to an unknown spot, or a drag without the mouse's motion
            readonly property bool glassSuspended: (tiled && niriPos === null) || (pointerFailed && niriWindow !== null && !tiled && niriPos === null)
            // until niri lists it, guess the middle of the screen (where niri opens floating windows)
            Component.onCompleted: {
                const scr = win.screen;
                if (scr) heldPos = [scr.x + (scr.width - width) / 2, scr.y + (scr.height - height) / 2];
                NiriState.subscribe();
            }

            Process {
                running: NiriState.isNiri
                command: ["python3", Caching.qsDir + "/reusables/display/pointer_motion.py"]
                stdout: SplitParser {
                    onRead: data => {
                        if (data === "ready") { win.pointerReady = true; return; }
                        if (data === "unavailable") { win.pointerFailed = true; return; }
                        const v = data.split(" ");
                        if (v[0] === "down") {
                            win.pressX = Number(v[1]);
                            win.pressY = Number(v[2]);
                            win.buttonHeld = true;
                            return;
                        }
                        if (v[0] === "up") {
                            // let go of a drag: keep where it got to until niri reports the new spot
                            if (win.dragging && win.pointerReady)
                                win.heldPos = [win.heldPos[0] + win.motionX - win.dragBaseX, win.heldPos[1] + win.motionY - win.dragBaseY];
                            win.buttonHeld = false;
                            return;
                        }
                        if (v.length !== 2) return;
                        win.motionX = Number(v[0]);
                        win.motionY = Number(v[1]);
                    }
                }
                onExited: {
                    win.pointerReady = false;
                    win.pointerFailed = true;
                }
            }
            // until niri lists this window (it can open before niri reports it), ask again
            Timer {
                interval: 400
                repeat: true
                running: NiriState.isNiri && win.niriWindow === null
                onTriggered: NiriState.refreshWindows()
            }
            Component.onDestruction: NiriState.unsubscribe()

            // closed by niri (close-window) or anything else
            onVisibleChanged: if (!visible && app.window === win) app.closeWindow()
            onClosed: if (app.window === win) app.closeWindow()
        }
    }
}
