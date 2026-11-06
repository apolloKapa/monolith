//@ pragma UseQApplication
import QtQuick
import Quickshell
import "core"
import "wall"
ShellRoot {
    Variants { model: Quickshell.screens; Background {} }
    WidgetEditor { id: ed; modelData: Quickshell.screens[0] }
    Timer { running: true; interval: 1500; onTriggered: { HubState.editWidgets = "desktop"; later.start(); } }
    Timer { id: later; interval: 900; onTriggered: { ed.dragType = "clock"; ed.dragPos = ed.place({ width: ed.dragSize[0], height: ed.dragSize[1] }, 763, 620, false); console.log("PLACED", ed.dragPos.x, ed.dragPos.y, JSON.stringify(ed.measures)); } }
}
