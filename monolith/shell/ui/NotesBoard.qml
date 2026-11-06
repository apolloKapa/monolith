import QtQuick
import "../core"

// Notes, in a list (pinned first, then recent) that opens one to read and write. Used by the
// notes widget, Tools and quick access. `live` false: a still preview (nothing to click).
Item {
    id: nb
    property bool live: true
    property string openId: ""
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
            Text { width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; text: Notes.list.length + (Notes.list.length === 1 ? " note" : " notes"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 2; font.weight: Font.Bold }
            Btn { icon: "add"; tint: Theme.accent; onHit: nb.open(Notes.create()) }
        }
        ListView {
            id: lv
            y: head.height + 6; width: parent.width; height: parent.height - y
            clip: true
            spacing: 4
            interactive: nb.live
            boundsBehavior: Flickable.StopAtBounds
            model: Notes.sorted
            section.property: "pinned"
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
                    width: parent.width - 24 - (rm.containsMouse ? 62 : 0)
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: Notes.name(row.modelData); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize; font.weight: Font.Bold }
                    Text { width: parent.width; elide: Text.ElideRight; text: Notes.when(row.modelData.updatedAt); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3 }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; enabled: nb.live; cursorShape: Qt.PointingHandCursor; onClicked: nb.open(row.modelData.id) }
                Row {
                    visible: rm.containsMouse || pinB.on
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
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
            Text { width: parent.width - 28 * 3 - 4; anchors.verticalCenter: parent.verticalCenter; leftPadding: 6; text: nb.note ? "Edited " + Notes.when(nb.note.updatedAt) : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: nb.fontSize - 3 }
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
