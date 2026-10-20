import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var files: []
    property string current: ""
    property string status: "Click a picture to use it as your wallpaper."
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    function refresh() { ls.running = true; cur.running = true }
    function pick(name) {
        Quickshell.execDetached(["setwall", dir + "/" + name])
        current = dir + "/" + name
        status = "Wallpaper set: " + name
    }
    function random() {
        if (files.length === 0) return
        pick(files[Math.floor(Math.random() * files.length)])
    }

    Component.onCompleted: refresh()
    Process {
        id: ls
        command: ["ls", "-1", pg.dir]
        stdout: StdioCollector {
            onStreamFinished: pg.files = text.split("\n").filter(l => l.toLowerCase().match(/[.](png|jpe?g|webp|bmp)$/))
        }
    }
    Process {
        id: cur
        command: ["cat", Quickshell.env("HOME") + "/.config/wallpaper"]
        stdout: StdioCollector { onStreamFinished: pg.current = text.trim() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            spacing: 8
            Btn { label: "Random"; onClicked: pg.random() }
            Btn { label: "Refresh"; onClicked: pg.refresh() }
            Btn { label: "Open folder"; onClicked: Quickshell.execDetached(["thunar", pg.dir]) }
        }
        Lbl { text: "WALLPAPERS  (" + pg.files.length + " in ~/Pictures/Wallpapers)" }
        Lbl { visible: pg.files.length === 0; text: "No pictures found. Put png, jpg or webp files in ~/Pictures/Wallpapers." }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            property int cols: Math.max(1, Math.floor(width / 190))
            cellWidth: width / cols
            cellHeight: cellWidth * 0.62
            model: pg.files

            delegate: Item {
                id: cell
                required property string modelData
                property string full: pg.dir + "/" + modelData
                property bool sel: full === pg.current
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "#111111"
                    border.width: cell.sel ? 3 : 1
                    border.color: cell.sel ? "#ffffff" : "#555555"
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + cell.full
                        sourceSize: Qt.size(360, 230)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: (ma.containsMouse || cell.sel) ? 1.0 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 20
                        color: "#1a1a1a"
                        opacity: ma.containsMouse ? 0.9 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            width: parent.width - 12
                            elide: Text.ElideMiddle
                            text: cell.modelData
                            color: "#ffffff"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                        }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pg.pick(cell.modelData) }
                }
            }
        }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
