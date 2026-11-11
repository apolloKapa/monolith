import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../ui"

// Clipboard history (cliphist): newest first; the search field filters it. Click copies
// an entry back, the bin removes it.
Page {
    id: page
    pageId: "clipboard"
    readonly property bool usesQuery: true
    property string query: ""
    property var entries: []
    readonly property var shown: query.trim() === "" ? entries : entries.filter(e => e.text.toLowerCase().indexOf(query.toLowerCase()) !== -1)
    readonly property real rowH: 52
    implicitHeight: Math.max(200, Math.min(shown.length, 8) * (rowH + 6))

    onCurrentChanged: if (current) listProc.running = true
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: page.entries = text.split("\n").filter(l => l).slice(0, 200).map(l => {
                const tab = l.indexOf("\t");
                const body = l.substring(tab + 1);
                return { line: l, text: body, image: /^\[\[ binary data/.test(body) };
            })
        }
    }
    function copy(e) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", e.line]);
        HubState.close();
    }
    function remove(e) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", e.line]);
        entries = entries.filter(x => x !== e);
    }

    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
    Keys.onDownPressed: list.currentIndex = Math.min(shown.length - 1, list.currentIndex + 1)
    Keys.onReturnPressed: if (shown[list.currentIndex]) copy(shown[list.currentIndex])

    Empty {
        anchors.centerIn: parent
        width: parent.width
        visible: page.shown.length === 0
        icon: page.entries.length === 0 ? "content_paste" : "search_off"
        title: page.entries.length === 0 ? "Nothing copied yet" : "Nothing matches"
        sub: page.entries.length === 0 ? "What you copy is kept here, ready to paste again." : "Try fewer letters."
    }

    ListView {
        SmoothWheel {}
        id: list
        anchors.fill: parent
        clip: true
        spacing: 6
        model: page.shown
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Theme.moveMs
        highlight: Rectangle { radius: Theme.corner(page.rowH); color: Theme.selected }
        delegate: Pressable {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: page.rowH
            color: index === list.currentIndex ? "transparent" : Theme.containerHigh
            onClicked: page.copy(modelData)
            Bubble { id: cb; x: 8; anchors.verticalCenter: parent.verticalCenter; size: 36; icon: row.modelData.image ? "image" : "content_paste" }
            Label {
                anchors.left: cb.right; anchors.leftMargin: 12
                anchors.right: del.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.image ? row.modelData.text.replace(/^\[\[ binary data /, "Image · ").replace(/ \]\]$/, "") : row.modelData.text
                maximumLineCount: 1
            }
            Pressable {
                id: del
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34
                color: "transparent"
                onClicked: page.remove(row.modelData)
                Icon { anchors.centerIn: parent; name: "delete"; size: 18; color: Theme.subtext }
            }
        }
    }
}
