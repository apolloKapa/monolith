//@ pragma UseQApplication
import QtQuick
import Quickshell
import "core"
import "status"
import "hub"
import "dock"
import "wall"
import "lock"

// Monolith (next): a status line on every screen, the hub, the dock, notification popups, the OSD.
ShellRoot {
    Variants { model: Quickshell.screens; Background {} }
    Variants { model: Quickshell.screens; StatusLine {} }
    Variants { model: Quickshell.screens; Hub {} }
    Variants { model: Quickshell.screens; Dock {} }
    Variants { model: Quickshell.screens; Popups {} }
    Variants { model: Quickshell.screens; Osd {} }
    LockScreen {}
    PolkitDialog {}
    // start the services that run on their own
    Component.onCompleted: { Notifs.dnd; Idle.enabled; Wall.path; Wellbeing.loaded; Updates.available; if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    // first launch: the welcome tour
    Connections {
        target: Store
        function onLoadedChanged() { if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    }
    Timer { id: welcome; interval: 1500; onTriggered: HubState.openSettings("welcome") }
}
