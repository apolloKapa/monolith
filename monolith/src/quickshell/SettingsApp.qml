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
            window.visible = true;
        }

        function isOpen(): bool {
            return window.visible;
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

    FloatingWindow {
        id: window

        title: I18n.t("widgets.guide.name", "Settings")
        color: "transparent"
        implicitWidth: Math.round(1200 * app.uiScale)
        implicitHeight: Math.round(750 * app.uiScale)
        minimumSize: Qt.size(Math.round(480 * app.uiScale), Math.round(400 * app.uiScale))
        // started hidden at login (settings.sh prewarm) and kept running after it's closed,
        // so opening settings only shows the window instead of starting a new quickshell
        visible: Quickshell.env("MONOLITH_SETTINGS_HIDDEN") !== "1"

        GuidePopup {
            id: popup
            anchors.fill: parent
            standalone: true
            visible: window.visible
            onExitRequested: window.visible = false
        }
    }
}
