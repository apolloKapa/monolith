//@ pragma UseQApplication
import QtQuick
import Quickshell
import "core"
import "status"
import "island"
import "hub"
import "dock"
import "wall"
import "lock"
import "capture"
import "apps"

// Monolith: the island on every screen (bar + every page), the dock, notification popups, the OSD.
ShellRoot {
    Variants { model: Quickshell.screens; Background {} }
    Variants { model: Quickshell.screens; Reserve {} }
    Variants { model: Quickshell.screens; Island {} }
    Variants { model: Quickshell.screens; Dock {} }
    Variants { model: Quickshell.screens; Popups {} }
    Variants { model: Quickshell.screens; Osd {} }
    Variants { model: Quickshell.screens; CaptureOverlay {} }
    Variants { model: Quickshell.screens; PerfOverlay {} }
    Variants { model: Quickshell.screens; Dim {} }
    Variants { model: Quickshell.screens; WallpaperPicker {} }
    Variants { model: Quickshell.screens; DesktopMenu {} }
    AppImagesWindow {}
    Variants { model: Quickshell.screens; QuickAccess {} }
    Variants { model: Quickshell.screens; WidgetEditor {} }
    LockScreen {}
    PolkitDialog {}
    // start the services that run on their own
    Component.onCompleted: { Notifs.dnd; Idle.enabled; Wall.path; Wellbeing.loaded; Updates.available; NightLight.enabled; AppColours.targets; NiriShell.passes; if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    // first launch: the welcome tour
    Connections {
        target: Store
        function onLoadedChanged() { if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    }
    Timer { id: welcome; interval: 1500; onTriggered: HubState.openSettings("welcome") }
}
