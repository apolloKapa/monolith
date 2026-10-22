import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }

        // a niri keybind forwarded here (see scripts/screenshot_key.sh): "handled" when the open
        // screenshot tool used it, empty otherwise (the bind then does its normal thing)
        function key(seq: string): string {
            let overlay = screenshotLoader.item;
            return (overlay && overlay.handleKey(seq)) ? "handled" : "";
        }
    }

    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}
    LockRedactor {}

    Launcher {}
    Clipboard {}    

    Polkit {}
    WellbeingLimitOverlay {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "monolith";
        Qt.application.domain = "monolith.org";
        Qt.application.name = "monolith";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
    }
}
