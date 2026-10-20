import QtQuick
import Quickshell

ShellRoot {
    id: root
    property alias page: keep.page
    PersistentProperties { id: keep; reloadableId: "settingsState"; property int page: 0 }
    readonly property var names: ["Displays", "Sound", "Network", "Bluetooth", "System", "Bar", "Power", "Themes", "Wallpaper", "Launcher"]
    readonly property var files: ["DisplaysPage.qml", "SoundPage.qml", "NetworkPage.qml", "BluetoothPage.qml", "SystemPage.qml", "BarPage.qml", "PowerPage.qml", "ThemesPage.qml", "WallpaperPage.qml", "LauncherPage.qml"]

    FloatingWindow {
        title: "Settings"
        implicitWidth: 860
        implicitHeight: 600
        color: "#1a1a1a"

        Rectangle {
            anchors.fill: parent
            color: "#1a1a1a"
            border.color: "#ffffff"
            border.width: 2
            Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
            Shortcut { sequence: "Up"; onActivated: root.page = Math.max(0, root.page - 1) }
            Shortcut { sequence: "Left"; onActivated: root.page = Math.max(0, root.page - 1) }
            Shortcut { sequence: "Down"; onActivated: root.page = Math.min(root.names.length - 1, root.page + 1) }
            Shortcut { sequence: "Right"; onActivated: root.page = Math.min(root.names.length - 1, root.page + 1) }
        }

        Column {
            id: side
            x: 18
            y: 18
            width: 130
            spacing: 4
            Repeater {
                model: root.names
                delegate: Btn {
                    required property string modelData
                    required property int index
                    width: side.width
                    label: modelData
                    active: root.page === index
                    onClicked: root.page = index
                }
            }
        }

        Lbl {
            x: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: "up/down: pages   esc: close"
            width: side.width
            wrapMode: Text.WordWrap
        }

        Loader {
            id: ld
            transform: Translate { id: slideT }
            opacity: 0
            onLoaded: fade.restart()
            ParallelAnimation { id: fade; NumberAnimation { target: ld; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic } NumberAnimation { target: slideT; property: "x"; from: 24; to: 0; duration: 260; easing.type: Easing.OutCubic } }
            anchors.left: side.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            source: Qt.resolvedUrl(root.files[root.page])
        }
    }
}
