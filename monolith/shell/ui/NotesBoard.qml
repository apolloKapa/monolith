import QtQuick
import "../core"

// Notes, in a list (pinned first, then recent) that opens one to read and write. Used by the
// notes widget, Tools and quick access. `live` false: a still preview (nothing to click).
Item {
    id: nb
    property bool live: true
    property string openId: ""
    // the deleted notes instead of the list
    property bool showTrash: false
    // filter the list by typing (shown once there are a few notes)
    property string filter: ""
    readonly property var shownNotes: filter.trim() === "" ? Notes.sorted
        : Notes.sorted.filter(o => (Notes.name(o) + "\n" + (o.content || "")).toLowerCase().indexOf(filter.trim().toLowerCase()) !== -1)
    property real fontSize: Theme.sizeBody
    readonly property bool anyPinned: Notes.list.some(x => x.pinned === true)
    readonly property var note: openId !== "" ? Notes.find(openId) : null
    onNoteChanged: if (openId !== "" && !note) openId = ""
    // filled once when a note opens (a binding would reset the cursor on every save)
    onOpenIdChanged: {
        const o = openId !== "" ? Notes.find(openId) : null;
        title.text = o ? (o.title || "") : "";
        body.text = o ? (o.content || "") : "";
    }

    function open(id) { openId = id; Qt.callLater(() => { if (body.text === "" && title.text === "") title.forceActiveFocus(); else body.forceActiveFocus(); }); }
    // what's typed is saved a moment after you stop
    Timer { id: save; interval: 500; onTriggered: if (nb.openId !== "") Notes.edit(nb.openId, title.text, body.text) }

    component Btn: Rectangle {
        id: b
        property string icon: ""
        property bool on: false
        property color tint: Theme.subtext
        signal hit()
        width: 28; height: 28; radius: Theme.corner(28, 8)
        color: bm.containsMouse ? Qt.alpha(Theme.containerHigh, 0.9) : (on ? Theme.accentContainer : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
        Icon { anchors.centerIn: parent; name: b.icon; size: 17; filled: b.on; color: b.on ? Theme.onAccentContainer : (bm.containsMouse ? Theme.text : b.tint) }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; enabled: nb.live; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
    }

    // ── the list ──
    Item {
        anchors.fill: parent
        // the list and a note cross-fade
        opacity: nb.openId === "" ? 1 : 0
        scale: nb.openId === "" ? 1 : Theme.popScale
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: nb.openId === "" ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: nb.openId === "" ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: nb.openId === "" ? Theme.enterCurve : Theme.exitCurve } }
        Row {
            id: head
            width: parent.width; height: 28
            spacing: 2
            Btn { visible: nb.showTrash; icon: "arrow_back"; onHit: nb.showTrash = false }
            Text {
                width: parent.width - 28 * (nb.showTrash ? 2 : 2) - 4; anchors.verticalCenter: parent.verticalCenter
                leftPadding: nb.showTrash ? 4 : 0
                text: nb.showTrash ? "Recently deleted" : Notes.list.length + (Notes.list.length === 1 ? " note" : " notes")
                color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 2; font.weight: Font.Bold
            }
            // the deleted ones (to bring back), or empty them
            Btn { visible: !nb.showTrash && nb.live; icon: "history"; on: false; onHit: nb.showTrash = true; opacity: Notes.trash.length ? 1 : 0.45 }
            Btn { visible: nb.showTrash; icon: "delete_sweep"; tint: Theme.danger; onHit: Notes.emptyTrash() }
            Btn { visible: !nb.showTrash; icon: "add"; tint: Theme.accent; onHit: nb.open(Notes.create()) }
        }
        // the filter (with a few notes)
        Rectangle {
            id: filterBox
            visible: !nb.showTrash && nb.live && Notes.list.length > 4
            y: head.height + 6; width: parent.width; height: visible ? 30 : 0
            radius: Theme.corner(30, 6)
            color: Qt.alpha(Theme.control, 0.55)
            Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.subtext }
            TextInput {
                x: 30; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter
                text: nb.filter; onTextEdited: nb.filter = text
                color: Theme.text; selectionColor: Theme.selected; clip: true
                font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 1
                Text { visible: parent.text === ""; text: "Find a note"; color: Theme.faint; font: parent.font }
            }
        }
        // ── deleted notes ──
        ListView {
            SmoothWheel {}
            visible: nb.showTrash
            y: head.height + 6; width: parent.width; height: parent.height - y
            clip: true
            spacing: 4
            model: Notes.trash
            delegate: Rectangle {
                id: trow
                required property var modelData
                width: ListView.view.width; height: 48
                radius: Theme.corner(48, 10)
                color: Qt.alpha(Theme.control, 0.55)
                Column {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - 62
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: Notes.name(trow.modelData); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize; font.weight: Font.Bold }
                    Text { width: parent.width; elide: Text.ElideRight; text: "Deleted " + Notes.when(trow.modelData.deletedAt); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Btn { icon: "content_copy"; onHit: Notes.copy(trow.modelData) }
                    Btn { icon: "restore_from_trash"; tint: Theme.accent; onHit: Notes.restore(trow.modelData.id) }
                }
            }
            Text { anchors.centerIn: parent; visible: Notes.trash.length === 0; text: "Nothing deleted"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 1 }
        }
        ListView {
            SmoothWheel { enabled: nb.live }
            id: lv
            visible: !nb.showTrash
            y: head.height + 6 + (filterBox.visible ? filterBox.height + 6 : 0); width: parent.width; height: parent.height - y
            clip: true
            spacing: 4
            interactive: nb.live
            boundsBehavior: Flickable.StopAtBounds
            model: nb.shownNotes
            // (groups only when something is pinned)
            section.property: nb.anyPinned ? "pinned" : ""
            section.delegate: Text {
                required property string section
                visible: nb.anyPinned
                height: nb.anyPinned ? 22 : 0
                text: section === "true" ? "Pinned" : "Recent"
                color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3; font.weight: Font.Bold
                verticalAlignment: Text.AlignVCenter
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                width: lv.width; height: 48
                radius: Theme.corner(48, 10)
                color: rm.containsMouse ? Qt.alpha(Theme.containerHigh, 0.85) : Qt.alpha(Theme.control, 0.55)
                Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                Column {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - (rm.containsMouse ? 92 : 0)
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: Notes.name(row.modelData); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize; font.weight: Font.Bold }
                    Text { width: parent.width; elide: Text.ElideRight; text: Notes.when(row.modelData.updatedAt); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3 }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; enabled: nb.live; cursorShape: Qt.PointingHandCursor; onClicked: nb.open(row.modelData.id) }
                Row {
                    visible: rm.containsMouse || pinB.on
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Btn { visible: rm.containsMouse; icon: "content_copy"; onHit: Notes.copy(row.modelData) }
                    Btn { id: pinB; icon: "keep"; on: row.modelData.pinned === true; onHit: Notes.togglePin(row.modelData.id) }
                    Btn { visible: rm.containsMouse; icon: "delete"; tint: Theme.danger; onHit: Notes.remove(row.modelData.id) }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: Notes.list.length === 0
                text: "No notes yet: + makes one"
                color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 1
            }
        }
    }

    // ── one note ──
    Item {
        anchors.fill: parent
        opacity: nb.openId !== "" ? 1 : 0
        scale: nb.openId !== "" ? 1 : Theme.popScale
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: nb.openId !== "" ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: nb.openId !== "" ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: nb.openId !== "" ? Theme.enterCurve : Theme.exitCurve } }
        Row {
            id: bar
            width: parent.width; height: 28
            spacing: 2
            Btn { icon: "arrow_back"; onHit: { save.stop(); Notes.edit(nb.openId, title.text, body.text); nb.openId = ""; } }
            Text { width: parent.width - 28 * 4 - 6; anchors.verticalCenter: parent.verticalCenter; leftPadding: 6; text: nb.note ? "Edited " + Notes.when(nb.note.updatedAt) : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3 }
            // the note as you see it now (title and text), to the clipboard
            Btn { icon: "content_copy"; onHit: Notes.copy({ title: title.text, content: body.text }) }
            Btn { icon: "keep"; on: !!nb.note && nb.note.pinned === true; onHit: Notes.togglePin(nb.openId) }
            Btn { icon: "delete"; tint: Theme.danger; onHit: { const id = nb.openId; nb.openId = ""; Notes.remove(id); } }
        }
        TextInput {
            id: title
            y: bar.height + 8; width: parent.width
            readOnly: !nb.live
            color: Theme.text; selectionColor: Theme.selected
            font.family: Theme.fontFamily; font.pixelSize: nb.fontSize + 3; font.weight: Font.Black
            clip: true
            onTextEdited: save.restart()
            Keys.onReturnPressed: body.forceActiveFocus()
            Text { visible: title.text === ""; text: "Title"; color: Theme.faint; font: title.font }
        }
        Flickable {
            SmoothWheel {}
            y: title.y + title.height + 8; width: parent.width; height: parent.height - y
            contentHeight: body.implicitHeight
            clip: true
            interactive: nb.live
            TextEdit {
                id: body
                width: parent.width
                readOnly: !nb.live
                wrapMode: TextEdit.Wrap
                color: Theme.text; selectionColor: Theme.selected
                font.family: Theme.fontFamily; font.pixelSize: nb.fontSize
                onTextChanged: if (activeFocus) save.restart()
                Keys.onEscapePressed: { save.stop(); Notes.edit(nb.openId, title.text, body.text); nb.openId = ""; }
                Text { visible: body.text === ""; text: "Write something…"; color: Theme.faint; font: body.font }
            }
        }
    }
}
