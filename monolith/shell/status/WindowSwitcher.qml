import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../core"
import "../ui"

// Alt+Tab's switcher on Hyprland (core/HyprSwitch): every window, most recent first, each with a
// live preview, its app's icon and title; the chosen one outlined in the accent. Shown on the
// screen you're on; it never takes the keyboard (the keys are Hyprland's), so a game or app
// behind it keeps working. A click picks a window too.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool here: Niri.focusedOutput !== "" ? Niri.focusedOutput === modelData.name : (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0])

    WlrLayershell.namespace: "monolith-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    visible: here
    // clicks only on the card, and only once it shows (explicit numbers: an item's region is read once)
    mask: Region {
        x: Math.round(card.x); y: Math.round(card.y)
        width: HyprSwitch.open ? Math.round(card.width) : 0
        height: HyprSwitch.open ? Math.round(card.height) : 0
    }

    // the preview's height (Settings → Windows → Alt+Tab)
    readonly property int ph: Number(Store.get("alttab.hyprSize", 170))
    readonly property int pw: Math.round(ph * 16 / 10)
    readonly property int gap: 12
    readonly property int pad: 18
    readonly property var list: HyprSwitch.list
    // as many across as fit, in rows
    readonly property int across: Math.max(1, Math.min(list.length, Math.floor((modelData.width * 0.86 - pad * 2 + gap) / (pw + gap))))
    readonly property int rows: Math.ceil(list.length / across)

    function iconOf(id) {
        const e = id ? DesktopEntries.heuristicLookup(id) : null;
        return Quickshell.iconPath(e ? e.icon : (id || ""), "application-x-executable");
    }
    function toplevelOf(id) {
        for (const t of Hyprland.toplevels.values) if (String(t.address) === id) return t.wayland;
        return null;
    }

    SmoothRect {
        id: card
        anchors.centerIn: parent
        width: win.across * (win.pw + win.gap) - win.gap + win.pad * 2
        height: Math.min(win.rows, 3) * (win.ph + 46 + win.gap) - win.gap + win.pad * 2
        radius: Theme.corner(Math.min(width, height), 22)
        color: Theme.card
        border.width: 1
        border.color: Theme.hairline
        opacity: HyprSwitch.open ? 1 : 0
        scale: HyprSwitch.open ? 1 : Theme.popScale
        Behavior on opacity { Anim { kind: HyprSwitch.open ? "enter" : "exit" } }
        Behavior on scale { Anim { kind: HyprSwitch.open ? "enter" : "exit" } }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: win.pad
            clip: true
            contentHeight: grid.height
            interactive: contentHeight > height
            // keep the chosen one in view (more than 3 rows: it scrolls)
            readonly property real wantY: Math.floor(HyprSwitch.index / win.across) * (win.ph + 46 + win.gap)
            onWantYChanged: contentY = Math.max(0, Math.min(contentHeight - height, wantY - (height - win.ph - 46) / 2))

            Flow {
                id: grid
                width: parent.width
                spacing: win.gap
                Repeater {
                    model: win.list
                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === HyprSwitch.index
                        width: win.pw
                        height: win.ph + 46

                        // the preview, outlined when chosen
                        SmoothRect {
                            id: frame
                            width: parent.width
                            height: win.ph
                            radius: Theme.corner(height, 14)
                            color: Theme.container
                            border.width: tile.chosen ? 3 : 1
                            border.color: tile.chosen ? Theme.accent : Theme.hairline
                            scale: tile.chosen ? 1.0 : 0.96
                            Behavior on scale { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }

                            // the app's icon: what shows until (or unless) there's a preview
                            IconImage {
                                anchors.centerIn: parent
                                visible: !shot.hasContent
                                implicitSize: Math.round(win.ph * 0.36)
                                source: win.iconOf(tile.modelData.app_id)
                                asynchronous: true
                            }
                            // the live preview, filling the frame inside its border: scaled to
                            // cover it, centred, cut to the frame's rounded corners (drawn at the
                            // window's own size, it ran past the frame and its corners stuck out)
                            ClippingRectangle {
                                id: clipBox
                                readonly property real inset: 5     // (past the chosen one's 3 px outline, so it never resizes)
                                x: inset; y: inset
                                width: frame.width - inset * 2
                                height: frame.height - inset * 2
                                radius: Math.max(0, frame.radius - inset)
                                color: "transparent"
                                ScreencopyView {
                                    id: shot
                                    readonly property real sw: sourceSize.width > 0 ? sourceSize.width : clipBox.width
                                    readonly property real sh: sourceSize.height > 0 ? sourceSize.height : clipBox.height
                                    readonly property real k: Math.max(clipBox.width / sw, clipBox.height / sh)
                                    width: Math.ceil(sw * k)
                                    height: Math.ceil(sh * k)
                                    x: Math.round((clipBox.width - width) / 2)
                                    y: Math.round((clipBox.height - height) / 2)
                                    captureSource: HyprSwitch.open ? win.toplevelOf(tile.modelData.id) : null
                                    live: HyprSwitch.open
                                    paintCursor: false
                                }
                            }
                        }
                        Row {
                            anchors.top: frame.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, parent.width)
                            spacing: 8
                            IconImage {
                                implicitSize: 20
                                source: win.iconOf(tile.modelData.app_id)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                width: Math.min(implicitWidth, win.pw - 28)
                                text: tile.modelData.title || tile.modelData.app_id || "Window"
                                strong: tile.chosen
                                color: tile.chosen ? Theme.text : Theme.subtext
                                font.pixelSize: Theme.sizeSmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: HyprSwitch.index = tile.index
                            onClicked: HyprSwitch.pick(tile.index)
                        }
                    }
                }
            }
        }
    }

    // blur behind it (Theme → Effects), shaped like it, only while it's fully there
    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        readonly property bool on: HyprSwitch.open
        width: on ? Math.round(card.width * card.scale) : 0
        height: on ? Math.round(card.height * card.scale) : 0
        x: Math.round(card.x + (card.width - width) / 2)
        y: Math.round(card.y + (card.height - height) / 2)
        radius: card.blurRadius * card.scale
    }
}
