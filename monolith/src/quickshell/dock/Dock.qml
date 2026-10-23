import QtQuick
import Quickshell
import "../"

Variants {
    // Settings -> Dock -> Monitors: every screen, or only the ones picked
    model: {
        const picked = (Config.rawSettings && Config.rawSettings.dock && Array.isArray(Config.rawSettings.dock.screens)) ? Config.rawSettings.dock.screens : [];
        if (picked.length === 0) return Quickshell.screens;
        const list = Quickshell.screens.filter(scr => picked.indexOf(scr.name) !== -1);
        return list.length > 0 ? list : Quickshell.screens;
    }

    delegate: Component {
        Scope {
            id: dockScope
            required property var modelData

            DockExclusionWindow {
                modelData: dockScope.modelData
                dockWindow: dockPanel
            }

            DockWindow {
                id: dockPanel
                modelData: dockScope.modelData
            }
        }
    }
}
