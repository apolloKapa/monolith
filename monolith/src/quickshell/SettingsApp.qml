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
            // closed by niri (close-window) or anything else
            onVisibleChanged: if (!visible && app.window === win) app.closeWindow()
            onClosed: if (app.window === win) app.closeWindow()
        }
    }
}
