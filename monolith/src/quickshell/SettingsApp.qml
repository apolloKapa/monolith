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
            readonly property var niriPos: {
                const l = niriWindow ? niriWindow.layout : null;
                if (!l || !l.tile_pos_in_workspace_view) return null;
                const off = l.window_offset_in_tile || [0, 0];
                return [l.tile_pos_in_workspace_view[0] + off[0], l.tile_pos_in_workspace_view[1] + off[1]];
            }
            // niri reports no position while it moves the window itself (Mod+drag), but the
            // window follows the pointer 1:1 then: the glass follows the mouse's own motion
            // (pointer_motion.py) from the last position niri gave, so it keeps bending the right
            // part of the wallpaper all through the drag.
            property var heldPos: [0, 0]
            property real motionX: 0
            property real motionY: 0
            property real dragBaseX: 0
            property real dragBaseY: 0
            // motion total when the left button last went down (the drag's real start)
            property real pressX: 0
            property real pressY: 0
            property bool pointerReady: false
            onNiriPosChanged: {
                if (niriPos) {
                    heldPos = niriPos;
                } else {
                    dragBaseX = pressX;
                    dragBaseY = pressY;
                }
            }
            property real glassScreenX: niriPos ? niriPos[0] : heldPos[0] + (pointerReady ? motionX - dragBaseX : 0)
            property real glassScreenY: niriPos ? niriPos[1] : heldPos[1] + (pointerReady ? motionY - dragBaseY : 0)
            // without the mouse's motion (no input group) the glass can't know where it is
            // mid-drag: it steps aside and the window rule's backdrop (xray) shows instead
            readonly property bool glassSuspended: niriWindow !== null && niriPos === null && !pointerReady

            Process {
                running: NiriState.isNiri
                command: ["python3", Caching.qsDir + "/reusables/display/pointer_motion.py"]
                stdout: SplitParser {
                    onRead: data => {
                        if (data === "ready") { win.pointerReady = true; return; }
                        const v = data.split(" ");
                        if (v[0] === "down") {
                            win.pressX = Number(v[1]);
                            win.pressY = Number(v[2]);
                            return;
                        }
                        if (v.length !== 2) return;
                        win.motionX = Number(v[0]);
                        win.motionY = Number(v[1]);
                    }
                }
                onExited: win.pointerReady = false
            }
            Component.onCompleted: NiriState.subscribe()
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
