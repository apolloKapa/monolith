import QtQuick
import QtQuick.Controls as QQC
import "../core"
import "popfit.js" as PopFit

// A drop-down for several choices at once (the keyboard's languages): shows the picked ones;
// click it for a grid of every option, with a search. A click in the grid adds one or takes it
// out, and the grid stays open for the next; the picked ones are numbered in their order.
// Options are [value, label] pairs.
SmoothRect {
    smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
    id: mp
    property var opts: []
    property var value: []              // the picked values, in order
    property int most: 0                // how many can be picked at once (0: any number)
    property string noun: "options"     // what they are, for the search's hint ("languages")
    property string hint: ""            // a line under the grid
    signal picked(var values)
    function labelOf(v) { const o = opts.find(o => String(o[0]) === String(v)); return o ? o[1] : String(v); }
    function toggle(v) {
        const cur = value.slice(), i = cur.indexOf(v);
        full = false;
        if (i >= 0) { if (cur.length === 1) return; cur.splice(i, 1); }     // (one always stays)
        else { if (most > 0 && cur.length >= most) { full = true; return; } cur.push(v); }
        picked(cur);
    }
    property bool full: false           // one more was clicked than can be picked
    property string filter: ""
    // The grid's order is set when it opens (the picked ones first, then the rest as given) and
    // kept while it's open: a cell never moves under the pointer when it's clicked.
    property var order: []
    readonly property var shown: {
        const f = filter.trim().toLowerCase();
        return f === "" ? order : order.filter(o => (o[1] + " " + o[0]).toLowerCase().indexOf(f) >= 0);
    }

    width: 300
    height: 40
    radius: Theme.corner(height)
    color: area.containsMouse || pop.visible ? Theme.containerHigh : Theme.container
    Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
    border.width: pop.visible ? 2 : Math.max(Theme.outlineW, 1)
    border.color: pop.visible ? Theme.accent : (Theme.outlineW > 0 ? Theme.outlineColor : Theme.ringTrack)

    // every picked one by name; when they don't all fit, the first and how many more
    Label { id: allNames; visible: false; strong: true; font.pixelSize: Theme.sizeSmall + 1; text: mp.value.map(v => mp.labelOf(v)).join(", ") }
    Label {
        id: names
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: arrow.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: mp.value.length === 0 ? "Choose…" : (allNames.implicitWidth <= width || mp.value.length < 2 ? allNames.text : mp.labelOf(mp.value[0]) + " + " + (mp.value.length - 1) + " more")
        strong: true
        font.pixelSize: Theme.sizeSmall + 1
    }
    Icon {
        id: arrow
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        name: "expand_more"; size: 20
        rotation: pop.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.visible ? pop.close() : mp.openList() }

    // Where the grid goes: under the field (above it when there's no room: popfit.js), its right
    // edge on the field's, as wide as the page allows up to 720.
    readonly property int cellH: 44
    property var fit: ({ y: height + 4, h: 420, up: false })
    property real popW: 560
    function openList() {
        const picked = value.map(v => opts.find(o => String(o[0]) === String(v)) || [v, String(v)]);
        order = picked.concat(opts.filter(o => value.indexOf(String(o[0])) < 0));
        const b = PopFit.bounds(mp);
        popW = Math.max(mp.width, b ? Math.min(720, mp.mapToItem(b, 0, 0).x + mp.width - 8) : 560);
        const cols = Math.max(2, Math.floor((popW - 16) / 176));
        fit = PopFit.place(mp, 16 + 44 + Math.ceil(order.length / cols) * cellH + (hint !== "" ? 30 : 0), 4);
        if (fit.h > 430) fit = { y: fit.up ? -4 - 430 : fit.y, h: 430, up: fit.up };
        pop.open();
    }

    CyberFx { target: pop.contentItem ? pop.contentItem.parent : null; p: pop.going ? 1 - pop.fx : pop.fx; going: pop.going }
    QQC.Popup {
        id: pop
        x: mp.width - width
        y: mp.fit.y
        width: mp.popW
        height: mp.fit.h
        padding: 8
        // (a press outside the field closes it: "outside the list" counted the field too, so
        // pressing the field to close it closed it on the press and the click opened it again)
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent
        transformOrigin: mp.fit.up ? QQC.Popup.BottomRight : QQC.Popup.TopRight
        // (interruptible: opening while it's still closing, or closing mid-open, carries on from
        // where it is instead of jumping to the start; closed it rests faded and zoomed out)
        opacity: 0
        scale: Theme.popScale
        // (Cyberpunk: fx runs the glitch in and the Blackwall out, CyberFx above; it doesn't fade)
        property real fx: 1
        property bool going: false
        onAboutToShow: going = false
        onAboutToHide: going = true
        enter: Transition {
            NumberAnimation { property: "fx"; from: Theme.cyber ? 0 : 1; to: 1; duration: Theme.cyber ? Theme.fxInMs : 0 }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.cyber ? 0 : Theme.popInMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
        }
        exit: Transition {
            NumberAnimation { property: "fx"; from: 1; to: 0; duration: Theme.cyber ? Theme.fxOutMs : 0 }
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.cyber ? Theme.fxOutMs : Theme.popOutMs; easing.type: Theme.cyber ? Easing.InExpo : Easing.OutCubic }
            NumberAnimation { property: "scale"; to: Theme.popScale; duration: Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
        }
        onClosed: HubState.releasePop(mp)
        onOpened: { HubState.claimPop(mp, pop.contentItem.parent); mp.full = false; mp.filter = ""; search.text = ""; search.forceActiveFocus(); grid.contentY = 0; }
        background: SmoothRect {
            radius: Theme.corner(48, 6)
            color: Theme.frame
            border.width: Math.max(1, Theme.outlineW)
            border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        }
        contentItem: Column {
            spacing: 6
            SmoothRect {
                smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                width: parent.width; height: 38
                radius: Theme.corner(38)
                color: Theme.containerHigh
                Icon { id: si; x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: Theme.subtext }
                TextInput {
                    Keys.onPressed: e => Sounds.key(e)   // (a sound for each key; never takes it)
                    id: search
                    anchors.left: si.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody
                    clip: true
                    onTextChanged: { mp.filter = text; grid.contentY = 0; }
                    // (Enter takes the first one found)
                    Keys.onReturnPressed: if (mp.filter.trim() !== "" && mp.shown.length) mp.toggle(String(mp.shown[0][0]))
                    Text { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search " + mp.opts.length + " " + mp.noun; color: Theme.subtext; font: search.font }
                }
            }
            GridView {
                id: grid
                width: parent.width
                height: pop.height - pop.padding * 2 - 44 - (foot.visible ? foot.height + 6 : 0)
                clip: true
                readonly property int cols: Math.max(2, Math.floor(width / 176))
                cellWidth: Math.floor(width / cols)
                cellHeight: mp.cellH
                model: mp.shown
                boundsBehavior: Flickable.StopAtBounds
                SmoothWheel {}
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property string v: String(modelData[0])
                    readonly property int at: mp.value.indexOf(v)       // its place among the picked (-1: not picked)
                    width: grid.cellWidth; height: grid.cellHeight
                    SmoothRect {
                        smoothing: 0
                        anchors.fill: parent; anchors.margins: 2
                        radius: Theme.corner(40, 2)
                        color: cell.at >= 0 ? Theme.accentContainer : (cellArea.containsMouse ? Theme.containerHigh : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                        Label {
                            anchors.left: parent.left; anchors.leftMargin: 12
                            anchors.right: mark.left; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData[1]
                            strong: cell.at >= 0
                            color: cell.at >= 0 ? Theme.onAccentContainer : Theme.text
                            font.pixelSize: Theme.sizeSmall + 1
                            // (a long name takes a second line before it's cut)
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            lineHeight: 0.9
                        }
                        // its number when it's picked (the first is the one the keyboard starts in); else its short name
                        Item {
                            id: mark
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(22, code.implicitWidth); height: 22
                            Label { id: code; visible: cell.at < 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: cell.v; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                            Rectangle {
                                visible: cell.at >= 0
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: (Theme.chamfer || Theme.square) ? 0 : 11
                                color: Theme.accent
                                Label { visible: mp.value.length > 1; anchors.centerIn: parent; text: String(cell.at + 1); strong: true; color: Theme.onAccent; font.pixelSize: Theme.sizeSmall }
                                Icon { visible: mp.value.length <= 1; anchors.centerIn: parent; name: "check"; size: 15; color: Theme.onAccent }
                            }
                        }
                        MouseArea { id: cellArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.play("click"); mp.toggle(cell.v); } }
                    }
                }
            }
            Label {
                id: foot
                visible: text !== ""
                width: parent.width; height: 24
                leftPadding: 6
                verticalAlignment: Text.AlignVCenter
                text: mp.full ? "That's the most there can be at once (" + mp.most + "): take one out first." : (mp.shown.length === 0 ? "Nothing matches." : mp.hint)
                color: mp.full ? Theme.danger : Theme.subtext
                font.pixelSize: Theme.sizeSmall
            }
        }
    }
}
