import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The widget editor: a full-screen area on one screen where you arrange the desktop's or the
// lock screen's widgets. Drag a widget to move it, its corner to resize it, the arrows above
// it to change its look; add widgets from the bar at the bottom. Esc or Done leaves.
PanelWindow {
    id: ed
    required property var modelData
    screen: modelData
    readonly property string mode: HubState.editWidgets
    readonly property bool shown: mode !== "" && (HubState.editScreen === "" ? modelData === Quickshell.screens[0] : HubState.editScreen === modelData.name)
    readonly property bool lockMode: mode === "lock"
    readonly property var list: shown ? WidgetLayout.on(mode, modelData.name) : []
    property string selected: ""
    property bool adding: false
    readonly property bool snap: Store.get("widgets.snap", true) !== false
    readonly property real grid: 20

    visible: shown
    WlrLayershell.namespace: "monolith-widget-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"
    onShownChanged: { selected = ""; adding = false; if (shown) keys.forceActiveFocus(); }

    function done() { HubState.editWidgets = ""; }
    function snapTo(v) { return snap ? Math.round(v / grid) * grid : v; }

    // ── what it looks like underneath: the wallpaper (blurred for the lock screen) ──
    Image {
        id: wp
        anchors.fill: parent
        source: Wall.url(Wall.pathFor(ed.modelData.name))
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(ed.width / (ed.lockMode ? 2 : 1), ed.height / (ed.lockMode ? 2 : 1))
        visible: !ed.lockMode
    }
    MultiEffect { anchors.fill: parent; source: wp; visible: ed.lockMode; blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.08 }
    Rectangle { anchors.fill: parent; visible: ed.lockMode; color: Qt.alpha(Theme.frame, 0.35) }
    // the grid
    Canvas {
        anchors.fill: parent
        visible: ed.snap
        opacity: 0.18
        onPaint: {
            const g = getContext("2d"); g.reset(); g.strokeStyle = "#ffffff"; g.lineWidth = 1;
            for (let x = 0; x < width; x += ed.grid * 2) { g.beginPath(); g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, height); g.stroke(); }
            for (let y = 0; y < height; y += ed.grid * 2) { g.beginPath(); g.moveTo(0, y + 0.5); g.lineTo(width, y + 0.5); g.stroke(); }
        }
    }
    // the lock screen's fixed parts, as guides: the password pill and the top island
    Rectangle {
        visible: ed.lockMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08 + 58
        width: 420; height: 64; radius: 32
        color: Qt.alpha(Theme.frame, 0.6)
        border.width: 2; border.color: Qt.alpha(Theme.text, 0.25)
        Label { anchors.centerIn: parent; text: "Password (stays here)"; muted: true }
    }
    // a click on nothing: no selection
    MouseArea { anchors.fill: parent; onClicked: { ed.selected = ""; ed.adding = false; } }

    // ── the widgets ──
    Repeater {
        model: ed.list
        Item {
            id: wrap
            required property var modelData
            readonly property bool sel: ed.selected === modelData.id
            property real sc: modelData.scale || 1
            width: face.implicitWidth * sc
            height: face.implicitHeight * sc
            x: Math.max(0, Math.min(modelData.x * ed.width, ed.width - width))
            y: Math.max(0, Math.min(modelData.y * ed.height, ed.height - height))
            z: sel ? 10 : 1
            WidgetFace {
                id: face
                type: wrap.modelData.type
                face: wrap.modelData.face || ""
                scale: wrap.sc
                transformOrigin: Item.TopLeft
            }
            // the frame: dashed-ish outline, solid accent when selected
            Rectangle {
                anchors.fill: parent; anchors.margins: -6
                radius: 10
                color: wrap.sel ? Qt.alpha(Theme.accent, 0.08) : "transparent"
                border.width: 2
                border.color: wrap.sel ? Theme.accent : Qt.alpha("#ffffff", 0.35)
            }
            // move: drag anywhere on it
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property point from
                onPressed: mouse => { ed.selected = wrap.modelData.id; ed.adding = false; start = mapToItem(ed.contentItem, mouse.x, mouse.y); from = Qt.point(wrap.x, wrap.y); }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                    wrap.x = Math.max(0, Math.min(ed.width - wrap.width, ed.snapTo(from.x + p.x - start.x)));
                    wrap.y = Math.max(0, Math.min(ed.height - wrap.height, ed.snapTo(from.y + p.y - start.y)));
                }
                onReleased: WidgetLayout.update(ed.mode, wrap.modelData.id, { x: wrap.x / ed.width, y: wrap.y / ed.height })
            }
            // resize: the corner handle
            Rectangle {
                visible: wrap.sel
                x: parent.width - 8; y: parent.height - 8
                width: 22; height: 22; radius: 11
                color: Theme.accent
                border.width: 3; border.color: Theme.onAccent
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.SizeFDiagCursor
                    property real startX
                    property real startSc
                    onPressed: mouse => { startX = mapToItem(ed.contentItem, mouse.x, 0).x; startSc = wrap.sc; }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const dx = mapToItem(ed.contentItem, mouse.x, 0).x - startX;
                        wrap.sc = Math.max(0.4, Math.min(3, startSc * (face.implicitWidth * startSc + dx) / Math.max(1, face.implicitWidth * startSc)));
                    }
                    onReleased: WidgetLayout.update(ed.mode, wrap.modelData.id, { scale: Math.round(wrap.sc * 100) / 100 })
                }
            }
            // its own little bar: the look, and remove
            Rectangle {
                visible: wrap.sel
                anchors.bottom: parent.top; anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40; width: wb.implicitWidth + 12
                radius: 20
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                Row {
                    id: wb
                    anchors.centerIn: parent
                    spacing: 2
                    Pressable { width: 32; height: 32; color: hovered ? Theme.containerHigh : "transparent"; onClicked: WidgetLayout.nextFace(ed.mode, wrap.modelData, -1); Icon { anchors.centerIn: parent; name: "chevron_left"; size: 20 } }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: WidgetLayout.typeName(wrap.modelData.type) + " · " + WidgetLayout.faceName(wrap.modelData.type, wrap.modelData.face); strong: true; font.pixelSize: Theme.sizeSmall + 1; leftPadding: 4; rightPadding: 4 }
                    Pressable { width: 32; height: 32; color: hovered ? Theme.containerHigh : "transparent"; onClicked: WidgetLayout.nextFace(ed.mode, wrap.modelData, 1); Icon { anchors.centerIn: parent; name: "chevron_right"; size: 20 } }
                    Rectangle { width: 1; height: 22; color: Theme.ringTrack; anchors.verticalCenter: parent.verticalCenter }
                    Pressable { width: 32; height: 32; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"; onClicked: { WidgetLayout.remove(ed.mode, wrap.modelData.id); ed.selected = ""; } Icon { anchors.centerIn: parent; name: "delete"; size: 19; color: Theme.danger } }
                }
            }
        }
    }

    // ── the toolbar ──
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        height: 52
        width: tb.implicitWidth + 16
        radius: 26
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: Theme.shadowY; shadowHorizontalOffset: Theme.shadowX }
        Row {
            id: tb
            anchors.centerIn: parent
            spacing: 8
            Icon { name: "dashboard_customize"; size: 22; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { text: "Editing"; strong: true; anchors.verticalCenter: parent.verticalCenter; rightPadding: 4 }
            Segmented {
                width: 240; height: 38
                anchors.verticalCenter: parent.verticalCenter
                opts: [["desktop", "Desktop"], ["lock", "Lock screen"]]
                value: ed.mode
                onPicked: v => { ed.selected = ""; HubState.editWidgets = v; }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Add widget"; icon: "add"; primary: ed.adding; onClicked: ed.adding = !ed.adding }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; icon: ed.snap ? "grid_on" : "grid_off"; onClicked: Store.set("widgets.snap", !ed.snap) }
            Button {
                id: resetB
                property bool armed: false
                anchors.verticalCenter: parent.verticalCenter
                text: armed ? "Sure?" : "Reset"; icon: "restart_alt"
                onClicked: { if (armed) { WidgetLayout.reset(ed.mode); armed = false; } else { armed = true; disarm.restart(); } }
                Timer { id: disarm; interval: 4000; onTriggered: resetB.armed = false }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Done"; icon: "check"; primary: true; onClicked: ed.done() }
        }
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.bottom; anchors.topMargin: 8
        text: ed.list.length === 0 ? "Nothing here yet: Add widget" : "Drag to move  ·  corner to resize  ·  arrows above it for its look  ·  Esc when done"
        color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
        font.pixelSize: Theme.sizeSmall
    }

    // ── adding: every widget, as cards along the bottom ──
    Rectangle {
        visible: ed.adding
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: Math.min(parent.width - 60, pal.implicitWidth + 24)
        height: 120
        radius: Theme.corner(120, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        Flickable {
            anchors.fill: parent; anchors.margins: 12
            contentWidth: pal.implicitWidth
            clip: true
            Row {
                id: pal
                spacing: 8
                Repeater {
                    model: WidgetLayout.types
                    Pressable {
                        required property var modelData
                        width: 110; height: 96
                        color: Theme.containerHigh
                        onClicked: { ed.selected = WidgetLayout.add(ed.mode, modelData[0], ed.modelData.name); ed.adding = false; }
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Bubble { anchors.horizontalCenter: parent.horizontalCenter; size: 44; icon: parent.parent.modelData[2] }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[1]; font.pixelSize: Theme.sizeSmall; strong: true }
                        }
                    }
                }
            }
        }
    }

    // keys
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: { if (ed.adding) ed.adding = false; else if (ed.selected !== "") ed.selected = ""; else ed.done(); }
        Keys.onDeletePressed: if (ed.selected !== "") { WidgetLayout.remove(ed.mode, ed.selected); ed.selected = ""; }
    }
}
