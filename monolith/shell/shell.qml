//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
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
    // windows that are rarely up (the capture overlay, the wallpaper picker, the widget editor,
    // the welcome…) exist only while they're used, plus a moment to animate away: hidden windows
    // still cost memory on every screen
    component Lazy: Item {
        property bool when: false
        property int linger: 800
        readonly property bool on: when || after.running
        Timer { id: after; interval: parent.linger; onTriggered: tidy.restart() }
        onWhenChanged: if (!when) after.restart()
    }
    // once something big has gone (a window above, a menu): a garbage collection a moment later,
    // so what it held (its objects, the pictures they kept) is let go instead of waiting
    Timer { id: tidy; interval: 1500; onTriggered: gc() }
    Connections { target: HubState; function onOpenChanged() { if (!HubState.open) tidy.restart(); } }
    Variants { model: Quickshell.screens; Background {} }
    Variants { model: Quickshell.screens; Reserve {} }
    Variants { model: Quickshell.screens; Frame {} }
    Variants { model: Quickshell.screens; Island {} }
    Variants { model: Quickshell.screens; SideBar {} }
    Variants { model: Quickshell.screens; Dock {} }
    Variants { model: Quickshell.screens; Popups {} }
    Variants { model: Quickshell.screens; Thrown {} }
    Lazy { id: peekL; when: HubState.peekScreen !== "" }
    Variants { model: peekL.on ? Quickshell.screens : []; MediaPeek {} }
    Lazy { id: notifL; when: HubState.dropScreen !== "" && HubState.dropKind === "notifications"; linger: 400 }
    Variants { model: notifL.on ? Quickshell.screens : []; NotifDrop {} }
    Lazy { id: soundL; when: HubState.dropScreen !== "" && HubState.dropKind === "sound"; linger: 400 }
    Variants { model: soundL.on ? Quickshell.screens : []; SoundDrop {} }
    Lazy { id: trayL; when: HubState.dropScreen !== "" && HubState.dropKind === "tray"; linger: 400 }
    Variants { model: trayL.on ? Quickshell.screens : []; TrayMenu {} }
    Lazy { id: sysL; when: HubState.dropScreen !== "" && HubState.dropKind === "system"; linger: 400 }
    Variants { model: sysL.on ? Quickshell.screens : []; SysDrop {} }
    Variants { model: Quickshell.screens; Osd {} }
    Lazy { id: capL; when: Capture.active || Capture.freezing; linger: 300 }
    Variants { model: capL.on ? Quickshell.screens : []; CaptureOverlay {} }
    // (kept until the Blackwall has taken it, with the Cyberpunk style)
    Lazy { id: prevL; when: Capture.previewFile !== ""; linger: Math.max(600, Theme.fxOutMs + 150) }
    Variants { model: prevL.on ? Quickshell.screens : []; ShotPreview {} }
    Variants { model: Capture.pins.map(p => p.id); Pin {} }
    Variants { model: Capture.countdown > 0 ? Quickshell.screens : []; Countdown {} }
    LazyLoader { active: Capture.editFile !== ""; ShotEditor {} }
    Variants { model: GameMode.overlay ? Quickshell.screens : []; PerfOverlay {} }
    Lazy { id: dimL; when: Idle.dimming }
    Variants { model: dimL.on ? Quickshell.screens : []; Dim {} }
    // shutting down, restarting, logging out, sleeping: the screens blur and say so
    Variants { model: Power.going !== "" ? Quickshell.screens : []; Goodbye {} }
    Lazy { id: wallL; when: HubState.wallOpen; linger: 1200 }
    Variants { model: wallL.on ? Quickshell.screens : []; WallpaperPicker {} }
    Lazy { id: menuL; when: HubState.deskMenu.screen !== ""; linger: 400 }
    Variants { model: menuL.on ? Quickshell.screens : []; DesktopMenu {} }
    LazyLoader { active: AppImages.opened; AppImagesWindow {} }
    Lazy { id: welcomeL; when: HubState.welcomeOpen; linger: 1500 }
    Variants { model: welcomeL.on ? Quickshell.screens : []; Welcome {} }
    Variants { model: Quickshell.screens; QuickAccess {} }
    // Alt+Tab on Hyprland (niri has its own): there while you cycle
    Variants { model: HyprSwitch.active ? Quickshell.screens : []; WindowSwitcher {} }
    Lazy { id: editL; when: HubState.editWidgets !== ""; linger: 400 }
    Variants { model: editL.on ? Quickshell.screens : []; WidgetEditor {} }
    LockScreen {}
    PolkitDialog {}
    // start the services that run on their own
    Component.onCompleted: { Notifs.dnd; AudioBalance.value; HyprMouse.held; Idle.enabled; Wall.path; Wellbeing.loaded; Updates.available; NightLight.enabled; AppColours.targets; NiriShell.passes; AltTab.follow; HyprSwitch.on; Profiles.current; if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    // the icon font (Material Symbols Rounded): every icon is drawn with it. Not there (a fresh
    // install, a distro without it): fetch it, then restart so the shell can use it
    Process {
        id: iconFont
        running: Qt.fontFamilies().indexOf("Material Symbols Rounded") === -1
        command: ["sh", Qt.resolvedUrl("scripts/icon-font.sh").toString().replace("file://", "")]
        onExited: code => { if (code === 10) Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/monolith", "restart"]); }
    }
    // the Cyberpunk style's icons (Material Symbols Sharp), fetched the same way once it's picked
    Process {
        running: Theme.chamfer && !Theme.sharpIcons && !iconFont.running
        command: ["sh", Qt.resolvedUrl("scripts/icon-font.sh").toString().replace("file://", ""), "Sharp"]
        onExited: code => { if (code === 10) Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/monolith", "restart"]); }
    }
    // first launch: the welcome tour
    Connections {
        target: Store
        function onLoadedChanged() { if (Store.loaded && Store.get("welcome.done", false) !== true) welcome.start(); }
    }
    Timer { id: welcome; interval: 1800; onTriggered: HubState.openWelcome() }
}
