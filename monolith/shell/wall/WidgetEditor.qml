import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The widget editor: a full-screen area on one screen where you arrange the desktop's or the
// lock screen's widgets. Drag a widget to move it, its corner to resize it; the bar above it
// has its look (a drop-down) and its settings (⚙); add widgets from the bar at the bottom.
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
    // opened from a widget's right-click menu: that one starts selected
    onShownChanged: {
        selected = shown ? HubState.editSelect : ""; adding = false; presetsOpen = false;
        HubState.editSelect = "";
        if (shown) keys.forceActiveFocus();
    }

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
    property bool optsOpen: false
    onSelectedChanged: optsOpen = false
    function setOption(id, k, v) {
        if (k.startsWith("store:")) Store.set(k.slice(6), v);
        else WidgetLayout.setOpt(mode, id, k, v);
    }
    function optionValue(item, o) { return o[0].startsWith("store:") ? Store.get(o[0].slice(6), o[3]) : WidgetLayout.opt(item, o[0], o[3]); }
    Repeater {
        model: ed.list
        Item {
            id: wrap
            required property var modelData
            readonly property bool sel: ed.selected === modelData.id
            readonly property var sz: WidgetLayout.size(modelData)
            property real ww: sz[0]
            property real hh: sz[1]
            onSzChanged: { ww = sz[0]; hh = sz[1]; }
            width: ww
            height: hh
            x: Math.max(0, Math.min(modelData.x * ed.width, ed.width - width))
            y: Math.max(0, Math.min(modelData.y * ed.height, ed.height - height))
            z: sel ? 10 : 1
            WidgetFace {
                id: face
                anchors.fill: parent
                item: wrap.modelData
                backdrop: ed.lockMode ? null : wp
                origin: Qt.point(wrap.x, wrap.y)
            }
            // the frame: a soft outline, solid accent when selected
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
                onPressed: mouse => { ed.selected = wrap.modelData.id; ed.adding = false; start = mapToItem(ed.contentItem, mouse.x, mouse.y); from = Qt.point(wrap.x, wrap.y); ed.moving = wrap; }
                onCanceled: ed.moving = null
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                    wrap.x = Math.max(0, Math.min(ed.width - wrap.width, ed.snapTo(from.x + p.x - start.x)));
                    wrap.y = Math.max(0, Math.min(ed.height - wrap.height, ed.snapTo(from.y + p.y - start.y)));
                }
                onReleased: { ed.moving = null; WidgetLayout.update(ed.mode, wrap.modelData.id, { x: wrap.x / ed.width, y: wrap.y / ed.height }); }
            }
            // resize: the corner handle, freely (inside the widget's limits and its look's shape)
            Rectangle {
                visible: wrap.sel
                x: parent.width - 8; y: parent.height - 8
                width: 22; height: 22; radius: 11
                color: Theme.accent
                border.width: 3; border.color: Theme.onAccent
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.SizeFDiagCursor
                    property point start
                    property real w0
                    property real h0
                    onPressed: mouse => { start = mapToItem(ed.contentItem, mouse.x, mouse.y); w0 = wrap.ww; h0 = wrap.hh; }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                        const c = WidgetLayout.clamp(wrap.modelData.type, wrap.modelData.face, ed.snapTo(w0 + p.x - start.x), ed.snapTo(h0 + p.y - start.y));
                        wrap.ww = Math.min(c[0], ed.width - wrap.x);
                        wrap.hh = Math.min(c[1], ed.height - wrap.y);
                    }
                    onReleased: WidgetLayout.update(ed.mode, wrap.modelData.id, { w: Math.round(wrap.ww), h: Math.round(wrap.hh) })
                }
            }
            // its own little bar: the name, the look, its settings, remove
            Rectangle {
                id: wbar
                visible: wrap.sel
                anchors.bottom: wrap.y > 70 ? parent.top : undefined
                anchors.top: wrap.y > 70 ? undefined : parent.bottom
                anchors.bottomMargin: 12; anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40; width: wb.implicitWidth + 12
                radius: 20
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                Row {
                    id: wb
                    anchors.centerIn: parent
                    spacing: 2
                    Label { anchors.verticalCenter: parent.verticalCenter; text: WidgetLayout.typeName(wrap.modelData.type); strong: true; font.pixelSize: Theme.sizeSmall + 1; leftPadding: 10; rightPadding: 6 }
                    // its look, as a drop-down (hidden when the widget has just one)
                    Dropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180; height: 32
                        visible: (WidgetLayout.faces[wrap.modelData.type] || []).length > 1
                        opts: WidgetLayout.faces[wrap.modelData.type] || []
                        value: WidgetLayout.faceId(wrap.modelData.type, wrap.modelData.face)
                        onPicked: v => WidgetLayout.setFace(ed.mode, wrap.modelData, v)
                    }
                    Pressable {
                        width: 32; height: 32
                        color: ed.optsOpen ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                        onClicked: ed.optsOpen = !ed.optsOpen
                        Icon { anchors.centerIn: parent; name: "tune"; size: 19; color: ed.optsOpen ? Theme.onAccentContainer : Theme.text }
                    }
                    Rectangle { width: 1; height: 22; color: Theme.ringTrack; anchors.verticalCenter: parent.verticalCenter }
                    Pressable { width: 32; height: 32; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"; onClicked: { WidgetLayout.remove(ed.mode, wrap.modelData.id); ed.selected = ""; } Icon { anchors.centerIn: parent; name: "delete"; size: 19; color: Theme.danger } }
                }
            }
            // its settings: under (or over) its little bar
            Rectangle {
                visible: wrap.sel && ed.optsOpen
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                y: wrap.y > 70 ? -12 - 40 - 8 - height : wrap.height + 12 + 40 + 8
                width: 340
                height: optCol.implicitHeight + 24
                radius: Theme.corner(60, 10)
                color: Theme.frame
                border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
                MouseArea { anchors.fill: parent }
                Column {
                    id: optCol
                    x: 12; y: 12; width: parent.width - 24
                    spacing: 10
                    Repeater {
                        model: WidgetLayout.optionsFor(wrap.modelData.type, wrap.modelData.face)
                        Column {
                            id: oc
                            required property var modelData
                            readonly property var val: ed.optionValue(wrap.modelData, modelData)
                            width: optCol.width
                            spacing: 4
                            Row {
                                width: parent.width
                                visible: oc.modelData[2] === "toggle"
                                Label { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; text: oc.modelData[1]; wrapMode: Text.Wrap }
                                Toggle { checked: oc.val === true; onToggled: on => ed.setOption(wrap.modelData.id, oc.modelData[0], on) }
                            }
                            Label { visible: oc.modelData[2] !== "toggle"; text: oc.modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall }
                            NumberBox {
                                visible: oc.modelData[2] === "slider"
                                width: parent.width
                                from: oc.modelData[4] ? oc.modelData[4][0] : 0; to: oc.modelData[4] ? oc.modelData[4][1] : 1
                                step: oc.modelData[4] ? oc.modelData[4][2] : 1
                                decimals: oc.modelData[0] === "opacity" ? 2 : 0
                                factor: oc.modelData[0] === "opacity" ? 100 : 1
                                unit: oc.modelData[0] === "opacity" ? "%" : (oc.modelData[0] === "lineThickness" ? "px" : "")
                                value: Number(oc.val)
                                onMoved: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            Segmented {
                                visible: oc.modelData[2] === "choice"
                                width: parent.width; height: 34
                                opts: oc.modelData[2] === "choice" ? oc.modelData[4] : []
                                value: String(oc.val)
                                onPicked: v => ed.setOption(wrap.modelData.id, oc.modelData[0], v)
                            }
                            Field {
                                visible: oc.modelData[2] === "text" || oc.modelData[2] === "file"
                                width: parent.width
                                text: String(oc.val || "")
                                placeholder: oc.modelData[2] === "file" ? "/path/to/picture.png (Enter)" : "Type, then Enter"
                                onAccepted: v => ed.setOption(wrap.modelData.id, oc.modelData[0], oc.modelData[2] === "file" ? v.trim().replace(/^~/, Wall.home) : v)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the toolbar ──
    Rectangle {
        id: bar
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        height: 52
        width: tb.implicitWidth + 16
        radius: 26
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
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
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Add widget"; icon: "add"; primary: ed.adding; onClicked: { ed.adding = !ed.adding; ed.presetsOpen = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Presets"; icon: "auto_awesome_mosaic"; primary: ed.presetsOpen; onClicked: { ed.presetsOpen = !ed.presetsOpen; ed.adding = false; } }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; icon: ed.snap ? "grid_on" : "grid_off"; onClicked: Store.set("widgets.snap", !ed.snap) }
            Button { anchors.verticalCenter: parent.verticalCenter; text: "Distances"; icon: "straighten"; primary: ed.distances; onClicked: Store.set("widgets.distances", !ed.distances) }
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
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.bottom; anchors.topMargin: 8
        text: ed.list.length === 0 ? "Nothing here yet: Add widget" : "Drag to move  ·  corner to resize  ·  its look and settings above it  ·  Esc when done"
        color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
        font.pixelSize: Theme.sizeSmall
    }

    // ── adding: every widget as a live preview card along the bottom, by category. Click adds it
    // near the middle; drag it out onto the screen to drop it where you let go. ──
    property string addCat: "all"
    property string dragType: ""                 // a card being dragged out
    property point dragPos: Qt.point(0, 0)        // the ghost's top-left, in the window
    readonly property var dragSize: dragType !== "" ? WidgetLayout.size({ type: dragType, face: "" }) : [0, 0]
    Rectangle {
        id: palette
        visible: ed.adding
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: Math.min(parent.width - 60, Math.max(cats.implicitWidth, pal.implicitWidth) + 24)
        height: 214
        radius: Theme.corner(214, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        MouseArea { anchors.fill: parent }       // clicks on the strip don't deselect
        Segmented {
            id: cats
            x: 12; y: 12
            width: Math.min(parent.width - 24, 620); height: 34
            opts: WidgetLayout.categories.map(c => [c[0], c[1]])
            value: ed.addCat
            onPicked: v => ed.addCat = v
        }
        Flickable {
            SmoothWheel { horizontal: true }
            x: 12; y: 56
            width: parent.width - 24; height: parent.height - 68
            contentWidth: pal.implicitWidth
            clip: true
            interactive: ed.dragType === ""
            Row {
                id: pal
                spacing: 8
                Repeater {
                    model: (WidgetLayout.categories.find(c => c[0] === ed.addCat) || WidgetLayout.categories[0])[3]
                    Pressable {
                        id: card
                        required property string modelData
                        readonly property var sz: WidgetLayout.size({ type: modelData, face: "" })
                        width: 150; height: 146
                        color: cardMa.containsMouse ? Theme.control : Theme.containerHigh
                        onClicked: { ed.selected = WidgetLayout.add(ed.mode, modelData, ed.modelData.name); ed.adding = false; }
                        // a still preview of the widget, scaled into the card
                        Item {
                            id: prev
                            x: 8; y: 8; width: parent.width - 16; height: 100
                            clip: true
                            WidgetFace {
                                live: false
                                item: ({ id: "preview-" + card.modelData, type: card.modelData, face: "", opts: {} })
                                width: card.sz[0]; height: card.sz[1]
                                scale: Math.min(prev.width / card.sz[0], prev.height / card.sz[1], 1)
                                anchors.centerIn: parent
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            spacing: 6
                            Icon { name: WidgetLayout.typeIcon(card.modelData); size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: WidgetLayout.typeName(card.modelData); font.pixelSize: Theme.sizeSmall; strong: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        // drag it out: past a few pixels it becomes a ghost that follows the pointer
                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            property point start
                            property bool dragging: false
                            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); dragging = false; }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                if (!dragging && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 8) { dragging = true; ed.dragType = card.modelData; }
                                if (!dragging) return;
                                const p = mapToItem(ed.contentItem, mouse.x, mouse.y);
                                ed.dragPos = Qt.point(ed.snapTo(Math.max(0, Math.min(ed.width - ed.dragSize[0], p.x - ed.dragSize[0] / 2))),
                                                      ed.snapTo(Math.max(0, Math.min(ed.height - ed.dragSize[1], p.y - ed.dragSize[1] / 2))));
                            }
                            onReleased: mouse => {
                                if (dragging) {
                                    const p = mapToItem(palette, mouse.x, mouse.y);
                                    // dropped back on the strip: nothing
                                    if (!palette.contains(p)) {
                                        ed.selected = WidgetLayout.add(ed.mode, card.modelData, ed.modelData.name, ed.dragPos.x / ed.width, ed.dragPos.y / ed.height);
                                        ed.adding = false;
                                    }
                                } else card.clicked();
                                dragging = false; ed.dragType = "";
                            }
                            onCanceled: { dragging = false; ed.dragType = ""; }
                        }
                    }
                }
            }
        }
    }
    // the dragged card: the widget itself, see-through, where it will land
    WidgetFace {
        visible: ed.dragType !== ""
        z: 90
        live: false
        opacity: 0.75
        item: ({ id: "ghost", type: ed.dragType || "clock", face: "", opts: {} })
        x: ed.dragPos.x; y: ed.dragPos.y
        width: ed.dragSize[0]; height: ed.dragSize[1]
        Rectangle { anchors.fill: parent; anchors.margins: -6; radius: 10; color: "transparent"; border.width: 2; border.color: Theme.accent }
    }

    // ── distances: while a widget moves, how far it is from each screen edge ──
    readonly property bool distances: Store.get("widgets.distances", false) === true
    property var moving: null                     // the widget being moved (its wrapper)
    Item {
        id: dist
        z: 80
        anchors.fill: parent
        readonly property var r: ed.moving ? Qt.rect(ed.moving.x, ed.moving.y, ed.moving.width, ed.moving.height)
            : (ed.dragType !== "" ? Qt.rect(ed.dragPos.x, ed.dragPos.y, ed.dragSize[0], ed.dragSize[1]) : null)
        visible: ed.distances && r !== null
        component Gap: Item {
            property bool horizontal: true
            property real len: 0
            Rectangle {
                color: Theme.accent
                width: parent.horizontal ? parent.width : 2; height: parent.horizontal ? 2 : parent.height
                anchors.centerIn: parent
            }
            Rectangle {
                visible: parent.len > 30
                anchors.centerIn: parent
                width: gl.implicitWidth + 12; height: 22; radius: 11
                color: Theme.accent
                Text { id: gl; anchors.centerIn: parent; text: Math.round(parent.parent.len) + " px"; color: Theme.onAccent; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
            }
        }
        Gap { visible: !!dist.r; horizontal: true; len: dist.r ? dist.r.x : 0; x: 0; width: len; y: dist.r ? dist.r.y + dist.r.height / 2 - 11 : 0; height: 22 }
        Gap { visible: !!dist.r; horizontal: true; len: dist.r ? ed.width - dist.r.x - dist.r.width : 0; x: dist.r ? dist.r.x + dist.r.width : 0; width: len; y: dist.r ? dist.r.y + dist.r.height / 2 - 11 : 0; height: 22 }
        Gap { visible: !!dist.r; horizontal: false; len: dist.r ? dist.r.y : 0; y: 0; height: len; x: dist.r ? dist.r.x + dist.r.width / 2 - 11 : 0; width: 22 }
        Gap { visible: !!dist.r; horizontal: false; len: dist.r ? ed.height - dist.r.y - dist.r.height : 0; y: dist.r ? dist.r.y + dist.r.height : 0; height: len; x: dist.r ? dist.r.x + dist.r.width / 2 - 11 : 0; width: 22 }
    }

    // ── presets: ready-made arrangements, replacing this screen's widgets ──
    property bool presetsOpen: false
    Rectangle {
        visible: ed.presetsOpen
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        width: prow.implicitWidth + 24
        height: 132
        radius: Theme.corner(132, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        Row {
            id: prow
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: WidgetLayout.presets
                Pressable {
                    required property var modelData
                    width: 150; height: 108
                    color: Theme.containerHigh
                    onClicked: { WidgetLayout.applyPreset(ed.mode, modelData[0], ed.modelData.name); ed.selected = ""; ed.presetsOpen = false; }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Bubble { anchors.horizontalCenter: parent.horizontalCenter; size: 44; icon: parent.parent.modelData[2] }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[1]; strong: true; font.pixelSize: Theme.sizeSmall }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData[3].length + " widgets"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                }
            }
        }
    }

    // keys
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: { if (ed.presetsOpen) ed.presetsOpen = false; else if (ed.adding) ed.adding = false; else if (ed.selected !== "") ed.selected = ""; else ed.done(); }
        Keys.onDeletePressed: if (ed.selected !== "") { WidgetLayout.remove(ed.mode, ed.selected); ed.selected = ""; }
    }
}
