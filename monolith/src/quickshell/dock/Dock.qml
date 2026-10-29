import QtQuick
import Quickshell
import "../"

Variants {
    // Settings -> Dock -> Monitors: every screen, or only the ones picked
    model: Config.screensFor("dock")

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
