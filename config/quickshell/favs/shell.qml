import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// "favourite apps" menu shown to the right of rofi while it is open (started/stopped by the `launcher` script)
PanelWindow {
    id: win

    property var ids: []

    screen: Quickshell.screens.find(s => s.name === Quickshell.env("FAVS_SCREEN")) ?? Quickshell.screens[0]
    anchors { left: true }                       // only left anchored -> centred vertically, like rofi
    margins { left: parseInt(Quickshell.env("FAVS_LEFT") || "1000") }
    implicitWidth: 300
    implicitHeight: Math.max(120, col.implicitHeight + 28)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "favs"

    FileView {
        path: Quickshell.env("HOME") + "/.config/rofi/favorites"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: win.ids = text().split("\n").filter(l => l.trim() !== "")
        onLoadFailed: win.ids = []
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
        border.color: "#555555"
        border.width: 2

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 4

            Text {
                text: "favourite apps"
                color: "#a0a0a0"
                font.family: "JetBrains Mono"; font.pixelSize: 15
                bottomPadding: 6
            }
            Text {
                visible: win.ids.length === 0
                text: "none yet - press ctrl+s on an app"
                color: "#666666"
                font.family: "JetBrains Mono"; font.pixelSize: 14
                wrapMode: Text.WordWrap
                width: parent.width
            }
            Repeater {
                model: win.ids
                delegate: Rectangle {
                    required property string modelData
                    // look up through the (async-filled) application list so it updates once entries load
                    property var entry: {
                        var apps = DesktopEntries.applications.values
                        for (var i = 0; i < apps.length; i++)
                            if (apps[i].id === modelData) return apps[i]
                        return null
                    }
                    visible: entry !== null
                    width: col.width
                    height: visible ? 36 : 0
                    color: hover.containsMouse ? "#ffffff" : "transparent"

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                        spacing: 10
                        Image {
                            width: 24; height: 24
                            sourceSize: Qt.size(48, 48)
                            source: parent.parent.entry ? Quickshell.iconPath(parent.parent.entry.icon, true) : ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: parent.parent.entry ? parent.parent.entry.name : ""
                            color: hover.containsMouse ? "#000000" : "#ffffff"
                            font.family: "JetBrains Mono"; font.pixelSize: 15
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            parent.entry.execute()
                            Quickshell.execDetached(["pkill", "-x", "rofi"])
                        }
                    }
                }
            }
        }
    }
}
