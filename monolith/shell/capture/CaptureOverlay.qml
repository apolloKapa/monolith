import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The capture overlay on one screen: the frozen picture, dimmed except the selection, and (on
// the screen you're working on) the toolbar. Drag to pick a region, drag inside it to move it,
// the corners to resize it. Keys: Enter does the main action, Ctrl+C copies, E edits, T reads
// the text, Q scans a QR code, Tab switches photo/video, F the whole screen, Esc cancels.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property string name: modelData.name
    // the toolbar (and the keyboard) live on the screen with the selection, else the focused one
    readonly property bool main: Capture.screenName !== "" ? Capture.screenName === name : (Capture.focused === "" ? Quickshell.screens[0] === modelData : Capture.focused === name)
    readonly property bool mine: Capture.screenName === name
    readonly property bool screenMode: Capture.mode === "screen"

    visible: Capture.active
    WlrLayershell.namespace: "monolith-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Capture.active && main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"

    // the frozen screen (reloaded each time: the source is cleared while hidden)
    Image {
        anchors.fill: parent
        source: Capture.active ? "file://" + Capture.frozen(win.name) : ""
        cache: false
        smooth: true
        fillMode: Image.Stretch
    }

    // ── the dimming, with a hole where the selection is ──
    readonly property rect hole: screenMode ? (mine ? Qt.rect(0, 0, width, height) : Qt.rect(0, 0, 0, 0)) : (mine ? Capture.sel : Qt.rect(0, 0, 0, 0))
    readonly property color dim: Qt.rgba(0, 0, 0, 0.5)
    Rectangle { x: 0; y: 0; width: parent.width; height: win.hole.y; color: win.dim }
    Rectangle { x: 0; y: win.hole.y + win.hole.height; width: parent.width; height: parent.height - y; color: win.dim }
    Rectangle { x: 0; y: win.hole.y; width: win.hole.x; height: win.hole.height; color: win.dim }
    Rectangle { x: win.hole.x + win.hole.width; y: win.hole.y; width: parent.width - x; height: win.hole.height; color: win.dim }

    // the selection's outline, corners and size
    Rectangle {
        visible: win.mine && !win.screenMode && Capture.hasSel
        x: Capture.sel.x - 1; y: Capture.sel.y - 1
        width: Capture.sel.width + 2; height: Capture.sel.height + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        radius: 2
    }
    Repeater {
        model: win.mine && !win.screenMode && Capture.hasSel ? 4 : 0
        Rectangle {
            required property int index
            readonly property bool r: index % 2 === 1
            readonly property bool b: index >= 2
            width: 14; height: 14; radius: 7
            x: (r ? Capture.sel.x + Capture.sel.width : Capture.sel.x) - 7
            y: (b ? Capture.sel.y + Capture.sel.height : Capture.sel.y) - 7
            color: Theme.accent
            border.width: 2
            border.color: Theme.onAccent
        }
    }
    Rectangle {
        visible: win.mine && !win.screenMode && Capture.hasSel
        x: Math.min(Capture.sel.x, win.width - width - 8)
        y: Capture.sel.y > 34 ? Capture.sel.y - 30 : Capture.sel.y + Capture.sel.height + 8
        width: sizeLabel.implicitWidth + 16; height: 24
        radius: 12
        color: Theme.frame
        Label { id: sizeLabel; anchors.centerIn: parent; text: Math.round(Capture.sel.width) + " × " + Math.round(Capture.sel.height); font.pixelSize: Theme.sizeSmall; strong: true }
    }

    // ── picking ──
    MouseArea {
        anchors.fill: parent
        cursorShape: win.screenMode ? Qt.PointingHandCursor : Qt.CrossCursor
        property point start
        property string dragging: ""      // new | move | 0..3 (a corner)
        property rect from
        function corner(px, py) {
            if (!win.mine || !Capture.hasSel) return -1;
            const s = Capture.sel;
            const pts = [[s.x, s.y], [s.x + s.width, s.y], [s.x, s.y + s.height], [s.x + s.width, s.y + s.height]];
            for (let i = 0; i < 4; i++) if (Math.abs(px - pts[i][0]) < 14 && Math.abs(py - pts[i][1]) < 14) return i;
            return -1;
        }
        onPressed: mouse => {
            if (win.screenMode) { Capture.screenName = win.name; return; }
            start = Qt.point(mouse.x, mouse.y);
            from = Capture.sel;
            const c = corner(mouse.x, mouse.y);
            const s = Capture.sel;
            if (c >= 0) dragging = String(c);
            else if (win.mine && Capture.hasSel && mouse.x > s.x && mouse.x < s.x + s.width && mouse.y > s.y && mouse.y < s.y + s.height) dragging = "move";
            else { dragging = "new"; Capture.screenName = win.name; Capture.sel = Qt.rect(mouse.x, mouse.y, 0, 0); }
        }
        onPositionChanged: mouse => {
            if (!pressed || win.screenMode) return;
            const x = Math.max(0, Math.min(win.width, mouse.x)), y = Math.max(0, Math.min(win.height, mouse.y));
            if (dragging === "new") {
                Capture.sel = Qt.rect(Math.min(start.x, x), Math.min(start.y, y), Math.abs(x - start.x), Math.abs(y - start.y));
            } else if (dragging === "move") {
                const nx = Math.max(0, Math.min(win.width - from.width, from.x + x - start.x));
                const ny = Math.max(0, Math.min(win.height - from.height, from.y + y - start.y));
                Capture.sel = Qt.rect(nx, ny, from.width, from.height);
            } else if (dragging !== "") {
                // a corner: the opposite one stays put
                const c = Number(dragging);
                const ox = (c % 2 === 1) ? from.x : from.x + from.width;
                const oy = (c >= 2) ? from.y : from.y + from.height;
                Capture.sel = Qt.rect(Math.min(ox, x), Math.min(oy, y), Math.abs(x - ox), Math.abs(y - oy));
            }
        }
        onReleased: {
            // a new area drawn for a picture: done right away when that's on
            const drawn = dragging === "new";
            dragging = "";
            if (drawn && Capture.onRelease && Capture.kind === "photo" && Capture.hasSel) Capture.finish(Capture.preferred);
        }
        onDoubleClicked: if (Capture.hasSel) Capture.finish(Capture.kind === "video" ? "record" : Capture.preferred)
    }

    // ── keys ──
    Item {
        focus: win.main
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) Capture.cancel();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) Capture.finish(Capture.kind === "video" ? "record" : Capture.preferred);
            else if (event.key === Qt.Key_Tab) Capture.kind = Capture.kind === "photo" ? "video" : "photo";
            else if (event.key === Qt.Key_F) { Capture.mode = win.screenMode ? "region" : "screen"; if (Capture.mode === "screen" && Capture.screenName === "") Capture.screenName = win.name; }
            else if (Capture.kind === "photo" && ctrl && event.key === Qt.Key_C) Capture.finish("copy");
            else if (Capture.kind === "photo" && event.key === Qt.Key_E) Capture.finish("edit");
            else if (Capture.kind === "photo" && event.key === Qt.Key_T) Capture.finish("text");
            else if (Capture.kind === "photo" && event.key === Qt.Key_Q) Capture.finish("qr");
            else return;
            event.accepted = true;
        }
    }

    // ── the toolbar: a floating pill at the bottom of the main screen ──
    component Tool: Pressable {
        id: tool
        property string icon: ""
        property string text: ""
        property string key: ""
        property bool primary: false
        width: Math.max(64, col.implicitWidth + 20)
        height: 58
        radius: Theme.corner(height, 4)
        color: primary ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
        ink: primary ? Theme.onAccent : Theme.text
        enabledInput: Capture.hasSel
        opacity: Capture.hasSel ? 1 : 0.4
        Column {
            id: col
            anchors.centerIn: parent
            spacing: 1
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: tool.icon; size: 21; filled: tool.primary; color: tool.primary ? Theme.onAccent : Theme.text }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: tool.text; font.pixelSize: Theme.sizeSmall; strong: tool.primary; color: tool.primary ? Theme.onAccent : Theme.text }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: tool.key; font.pixelSize: Theme.sizeTiny; color: tool.primary ? Qt.alpha(Theme.onAccent, 0.7) : Theme.subtext }
        }
    }

    Rectangle {
        id: bar
        visible: win.main
        // the menu fades in with a little zoom as the overlay comes up
        opacity: 0
        scale: Theme.popScale
        transformOrigin: Item.Bottom
        Component.onCompleted: barIn.start()
        ParallelAnimation {
            id: barIn
            NumberAnimation { target: bar; property: "opacity"; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "scale"; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
        }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        width: row.implicitWidth + 20
        height: 78
        radius: Theme.corner(height, 12)
        color: Theme.frame
        CardShadow {}
        // drags on the toolbar don't start a selection
        MouseArea { anchors.fill: parent }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Segmented {
                    width: 200; height: 30
                    opts: [["photo", "Photo"], ["video", "Video"]]
                    value: Capture.kind
                    onPicked: v => Capture.kind = v
                }
                Segmented {
                    width: 200; height: 30
                    opts: [["region", "Region"], ["screen", "Screen"]]
                    value: Capture.mode
                    onPicked: v => { Capture.mode = v; if (v === "screen" && Capture.screenName === "") Capture.screenName = win.name; }
                }
            }
            Rectangle { width: 1; height: 50; color: Theme.ringTrack; anchors.verticalCenter: parent.verticalCenter }
            Tool { visible: Capture.kind === "photo"; icon: "save"; text: "Save"; key: Capture.preferred === "save" ? "Enter" : ""; primary: Capture.preferred === "save"; onClicked: Capture.finish("save") }
            Tool { visible: Capture.kind === "photo"; icon: "content_copy"; text: "Copy"; key: "Ctrl+C"; onClicked: Capture.finish("copy") }
            Tool { visible: Capture.kind === "photo"; icon: "edit"; text: "Edit"; key: Capture.preferred === "edit" ? "Enter" : "E"; primary: Capture.preferred === "edit"; onClicked: Capture.finish("edit") }
            Tool { visible: Capture.kind === "photo"; icon: "document_scanner"; text: "Text"; key: "T"; onClicked: Capture.finish("text") }
            Tool { visible: Capture.kind === "photo"; icon: "qr_code_scanner"; text: "QR code"; key: "Q"; onClicked: Capture.finish("qr") }
            Tool { visible: Capture.kind === "video"; icon: "radio_button_checked"; text: "Record"; key: "Enter"; primary: true; onClicked: Capture.finish("record") }
            Rectangle { width: 1; height: 50; color: Theme.ringTrack; anchors.verticalCenter: parent.verticalCenter }
            Pressable {
                width: 46; height: 46
                anchors.verticalCenter: parent.verticalCenter
                color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"
                onClicked: Capture.cancel()
                Icon { anchors.centerIn: parent; name: "close"; size: 22 }
            }
        }
        // the hint before anything is picked
        Rectangle {
            visible: !Capture.hasSel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 10
            width: hint.implicitWidth + 24; height: 30; radius: 15
            color: Theme.frame
            Label { id: hint; anchors.centerIn: parent; text: win.screenMode ? "Click a screen" : "Drag to pick an area   ·   F for the whole screen   ·   Esc to cancel"; font.pixelSize: Theme.sizeSmall }
        }
    }
}
