import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// search box + draggable favourites + app list
Item {
    id: menu

    property bool active: false
    signal launched()
    signal closeRequested()

    property string query: ""
    property int sel: 0

    // favourites file, shared with the old rofi setup (one desktop-entry id per line)
    readonly property string favPath: Quickshell.env("HOME") + "/.config/rofi/favorites"
    property var stableIds: []   // the set of favourites (changes only when one is added/removed)
    property var order: []       // display order (changes while dragging)

    // installed apps matching the search text
    readonly property var results: {
        var apps = DesktopEntries.applications.values
        var q = query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (a.noDisplay) continue
            if (q !== "") {
                var hay = (a.name + " " + (a.genericName || "") + " " + (a.keywords ? a.keywords.join(" ") : "")).toLowerCase()
                if (hay.indexOf(q) < 0) continue
            }
            out.push(a)
        }
        out.sort(function(x, y) {
            if (q !== "") {
                var xs = x.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                var ys = y.name.toLowerCase().indexOf(q) === 0 ? 0 : 1
                if (xs !== ys) return xs - ys
            }
            return x.name.localeCompare(y.name)
        })
        return out
    }

    function findEntry(id) {
        var apps = DesktopEntries.applications.values
        for (var i = 0; i < apps.length; i++)
            if (apps[i].id === id) return apps[i]
        return null
    }
    function isFav(id) { return order.indexOf(id) >= 0 }
    function save(ids) { favFile.setText(ids.join(String.fromCharCode(10)) + String.fromCharCode(10)) }
    function toggleFav(id) {
        var ids = order.slice()
        var i = ids.indexOf(id)
        if (i >= 0) ids.splice(i, 1)
        else ids.push(id)
        stableIds = ids.slice()
        order = ids
        save(ids)
    }
    function launch(entry) {
        if (!entry) return
        entry.execute()
        menu.launched()
    }
    function move(d) {
        var n = results.length
        if (n === 0) return
        sel = Math.max(0, Math.min(n - 1, sel + d))
        list.positionViewAtIndex(sel, ListView.Contain)
    }
    function refocus() { input.forceActiveFocus() }
    function reset() {
        input.text = ""
        query = ""
        sel = 0
        focusTimer.restart()
    }

    onActiveChanged: if (active) focusTimer.restart()
    Timer { id: focusTimer; interval: 60; onTriggered: input.forceActiveFocus() }

    FileView {
        id: favFile
        path: menu.favPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var lines = text().split(String.fromCharCode(10)).map(l => l.trim()).filter(l => l !== "")
            if (strip.dragId !== "") return
            if (lines.join(",") === menu.order.join(",")) return
            if (lines.slice().sort().join(",") !== menu.stableIds.slice().sort().join(",")) menu.stableIds = lines.slice()
            menu.order = lines
        }
        onLoadFailed: { menu.stableIds = []; menu.order = [] }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 10

        // ---- search ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: Theme.field
            border.color: Theme.border
            border.width: 1

            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.text
                selectedTextColor: Theme.hoverText
                font.family: Theme.font
                font.pixelSize: 18
                clip: true
                onTextChanged: { menu.query = text; menu.sel = 0 }

                Keys.onEscapePressed: menu.closeRequested()
                Keys.onDownPressed: menu.move(1)
                Keys.onUpPressed: menu.move(-1)
                Keys.onReturnPressed: menu.launch(menu.results[menu.sel])
                Keys.onEnterPressed: menu.launch(menu.results[menu.sel])
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                        var e = menu.results[menu.sel]
                        if (e) menu.toggleFav(e.id)
                        event.accepted = true
                    }
                }
            }
            Text {
                visible: input.text === ""
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "search apps..."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 18
            }
        }

        // ---- favourites ----
        Text { text: "favourites  (drag to reorder, right-click to remove)"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }

        Item {
            id: strip
            Layout.fillWidth: true
            property int tile: Theme.favTile
            property int gap: Theme.favGap
            property int cols: Math.max(1, Math.floor((width + gap) / (tile + gap)))
            property string dragId: ""
            property string hoverId: ""
            property real dragX: 0
            property real dragY: 0
            Layout.preferredHeight: Math.max(tile, Math.ceil(Math.max(1, menu.order.length) / cols) * (tile + gap) - gap)

            Text {
                visible: menu.order.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "none yet - press ctrl+s on an app, or click its star"
                color: "#666666"
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: menu.stableIds

                delegate: Rectangle {
                    id: tl
                    required property string modelData
                    property var entry: menu.findEntry(modelData)
                    property int slot: menu.order.indexOf(modelData)
                    property bool dragged: strip.dragId === modelData

                    visible: entry !== null && slot >= 0
                    width: strip.tile
                    height: strip.tile
                    x: dragged ? strip.dragX - width / 2 : Math.max(0, slot % strip.cols) * (strip.tile + strip.gap)
                    y: dragged ? strip.dragY - height / 2 : Math.floor(Math.max(0, slot) / strip.cols) * (strip.tile + strip.gap)
                    z: dragged ? 10 : 0
                    scale: dragged ? 1.12 : 1.0
                    color: (dragged || strip.hoverId === modelData) ? Theme.hover : Theme.field
                    border.color: dragged ? Theme.accent : Theme.border
                    border.width: dragged ? 2 : 1

                    Behavior on x { enabled: !tl.dragged; NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !tl.dragged; NumberAnimation { duration: Theme.animMove; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Image {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        sourceSize: Qt.size(64, 64)
                        source: tl.entry ? Quickshell.iconPath(tl.entry.icon, true) : ""
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property string pressedId: ""
                property bool moved: false
                property real pressX: 0
                property real pressY: 0

                function indexAt(x, y) {
                    var step = strip.tile + strip.gap
                    var col = Math.floor(x / step)
                    var row = Math.floor(y / step)
                    if (col < 0 || row < 0 || col >= strip.cols) return -1
                    if (x - col * step > strip.tile || y - row * step > strip.tile) return -1
                    var i = row * strip.cols + col
                    return i < menu.order.length ? i : -1
                }

                onExited: strip.hoverId = ""
                onPressed: mouse => {
                    pressX = mouse.x
                    pressY = mouse.y
                    moved = false
                    var i = indexAt(mouse.x, mouse.y)
                    pressedId = i >= 0 ? menu.order[i] : ""
                }
                onPositionChanged: mouse => {
                    if (!pressed) {
                        var h = indexAt(mouse.x, mouse.y)
                        strip.hoverId = h >= 0 ? menu.order[h] : ""
                        return
                    }
                    if (pressedId === "") return
                    if (!moved && Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) < 8) return
                    moved = true
                    strip.dragId = pressedId
                    strip.dragX = mouse.x
                    strip.dragY = mouse.y
                    var step = strip.tile + strip.gap
                    var col = Math.max(0, Math.min(strip.cols - 1, Math.floor(mouse.x / step)))
                    var row = Math.max(0, Math.floor(mouse.y / step))
                    var target = Math.min(menu.order.length - 1, row * strip.cols + col)
                    var cur = menu.order.indexOf(pressedId)
                    if (target !== cur && cur >= 0) {
                        var o = menu.order.slice()
                        o.splice(cur, 1)
                        o.splice(target, 0, pressedId)
                        menu.order = o
                    }
                }
                onReleased: mouse => {
                    if (pressedId === "") return
                    if (moved) {
                        strip.dragId = ""
                        menu.save(menu.order)
                    } else if (mouse.button === Qt.RightButton) {
                        menu.toggleFav(pressedId)
                    } else {
                        menu.launch(menu.findEntry(pressedId))
                    }
                    pressedId = ""
                    moved = false
                }
            }
        }

        // name of the hovered favourite
        Text {
            Layout.preferredHeight: 14
            property var e: strip.hoverId !== "" ? menu.findEntry(strip.hoverId) : null
            text: e ? e.name : " "
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }

        // ---- app list ----
        Text { text: "apps"; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: menu.results

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 40
                color: menu.sel === index ? Theme.hoverBg : (rowMa.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Image {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    sourceSize: Qt.size(52, 52)
                    source: Quickshell.iconPath(row.modelData.icon, true)
                }
                Text {
                    x: 48
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48 - 56
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: menu.sel === row.index ? Theme.hoverText : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                }
                Text {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: menu.isFav(row.modelData.id) ? "★" : "☆"
                    color: menu.sel === row.index ? Theme.hoverText : Theme.dim
                    font.pixelSize: 18
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: menu.sel = row.index
                    onClicked: menu.launch(row.modelData)
                }
                MouseArea {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 48
                    onClicked: menu.toggleFav(row.modelData.id)
                }
            }
        }

        Text {
            text: "enter launch   ctrl+s favourite   up/down select   esc close"
            color: "#666666"
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
