import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// animated app launcher. toggle it with:
//   qs -c launcher ipc call launcher toggle
ShellRoot {
    id: root

    property bool open: false
    property string screenName: ""

    function show() { focusProc.running = true }
    function hide() { open = false }

    IpcHandler {
        target: "launcher"
        function toggle(): void { if (root.open) root.hide(); else root.show() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }

    // open on whichever monitor is focused
    Process {
        id: focusProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.screenName = JSON.parse(text).name } catch (e) { root.screenName = "" }
                root.open = true
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            property bool mine: root.screenName === "" || root.screenName === modelData.name
            property bool animating: false
            property real wProg: 0
            property real hProg: 0
            property real cProg: 0

            screen: modelData
            visible: (root.open && mine) || animating
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launcher"
            WlrLayershell.keyboardFocus: (root.open && mine) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Connections {
                target: root
                function onOpenChanged() {
                    if (!win.mine) return
                    if (root.open) { closeAnim.stop(); openAnim.restart() }
                    else { openAnim.stop(); closeAnim.restart() }
                }
            }

            // open: a line grows sideways, then the box opens, then the contents fade in
            SequentialAnimation {
                id: openAnim
                ScriptAction { script: { win.animating = true; menu.reset() } }
                NumberAnimation { target: win; property: "wProg"; to: 1; duration: Theme.animLine; easing.type: Easing.OutCubic }
                NumberAnimation { target: win; property: "hProg"; to: 1; duration: Theme.animOpen; easing.type: Easing.OutCubic }
                NumberAnimation { target: win; property: "cProg"; to: 1; duration: Theme.animFade }
            }
            // close: the reverse
            SequentialAnimation {
                id: closeAnim
                NumberAnimation { target: win; property: "cProg"; to: 0; duration: Theme.animFast }
                NumberAnimation { target: win; property: "hProg"; to: 0; duration: Theme.animOpen; easing.type: Easing.InCubic }
                NumberAnimation { target: win; property: "wProg"; to: 0; duration: Theme.animLine; easing.type: Easing.InCubic }
                ScriptAction { script: win.animating = false }
            }

            // click outside the menu closes it
            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Rectangle {
                id: panel
                anchors.centerIn: parent
                visible: win.wProg > 0
                width: Theme.menuWidth * win.wProg
                height: Theme.lineHeight + (Theme.menuHeight - Theme.lineHeight) * win.hProg
                color: Theme.bg
                border.color: Theme.accent
                border.width: Theme.borderWidth
                clip: true

                // swallow clicks on the panel itself
                MouseArea {
                    anchors.fill: parent
                    onClicked: menu.refocus()
                }

                Menu {
                    id: menu
                    anchors.centerIn: parent
                    width: Theme.menuWidth
                    height: Theme.menuHeight
                    opacity: win.cProg
                    active: root.open && win.mine
                    onLaunched: root.hide()
                    onCloseRequested: root.hide()
                }
            }
        }
    }
}
