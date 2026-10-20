import Quickshell
import Quickshell.Io
import QtQuick

// workspace switcher for one output, driven by the niri event stream
Row {
    id: root
    property string output: ""
    property var all: []
    spacing: 6

    // workspaces of this output: named ones, the active one, and any that hold windows
    function homeOf(w) {
        if (w.name === null) return w.output
        var keys = Object.keys(Theme.homes)
        for (var i = 0; i < keys.length; i++)
            if (w.name.indexOf(keys[i]) === 0) return Theme.homes[keys[i]]
        return Theme.mainOutput
    }

    readonly property var shownList: {
        var l = []
        for (var i = 0; i < all.length; i++) {
            var w = all[i]
            if (root.homeOf(w) !== output) continue
            if (w.name !== null || w.is_active || w.active_window_id !== null) l.push(w)
        }
        l.sort(function(a, b) { return a.idx - b.idx })
        return l
    }

    Component.onCompleted: lister.running = true

    Process {
        id: lister
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.all = JSON.parse(text) } catch (e) { }
            }
        }
    }

    // any workspace/window event -> re-read the list (debounced)
    Process {
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                if (/Workspace|WindowOpenedOrChanged|WindowClosed/.test(line)) debounce.restart()
            }
        }
    }
    Timer { id: debounce; interval: 60; onTriggered: lister.running = true }

    Repeater {
        model: root.shownList.length

        delegate: Rectangle {
            id: box
            required property int index
            property var ws: root.shownList[index]
            property bool active: ws ? ws.is_active : false
            property string label: ws ? (ws.name !== null ? ws.name : String(ws.idx)) : ""

            implicitWidth: Math.max(26, lbl.implicitWidth + 16)
            width: active ? implicitWidth + 8 : implicitWidth
            height: 26
            color: active ? Theme.hoverBg : (ma.containsMouse ? Theme.hover : "transparent")
            border.color: active ? Theme.hoverBg : Theme.border
            border.width: 1

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: lbl
                anchors.centerIn: parent
                text: box.label
                color: box.active ? Theme.hoverText : (ma.containsMouse ? Theme.text : Theme.dim)
                font.family: Theme.font
                font.pixelSize: Theme.fontSmall
                font.bold: box.active
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (!box.ws) return
                    var nm = box.ws.name
                    var ref = (nm !== null && !/^[0-9]+$/.test(nm)) ? nm : String(box.ws.idx)
                    Quickshell.execDetached(["sh", "-c", "niri msg action focus-monitor " + box.ws.output + " && niri msg action focus-workspace " + ref])
                }
            }
        }
    }
}
