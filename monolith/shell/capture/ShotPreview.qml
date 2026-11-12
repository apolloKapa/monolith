import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../core"
import "../ui"

// After a screenshot: a small card with it slides in at a corner of the screen it was taken on
// (Settings → Screenshots → Preview), for a few seconds (the pointer on it keeps it). Click the
// picture to edit it; under it: Edit, Copy, Pin, its folder, Delete.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool here: Capture.previewScreen !== "" ? Capture.previewScreen === modelData.name : modelData === Quickshell.screens[0]
    readonly property bool shown: Capture.previewFile !== "" && here
    readonly property string file: Capture.previewFile
    readonly property string corner: Store.get("capture.previewCorner", "bottom-right")
    readonly property bool onRight: corner.indexOf("right") !== -1
    readonly property bool onTop: corner.indexOf("top") !== -1

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-shot-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: onTop; bottom: !onTop; left: !onRight; right: onRight }
    margins { top: 64; bottom: 24; left: 24; right: 24 }
    implicitWidth: 340
    implicitHeight: 280
    color: "transparent"
    mask: Region { item: card }

    // how long it stays; the pointer on it holds it
    Timer {
        id: life
        interval: Math.max(2, Number(Store.get("capture.previewTime", 6))) * 1000
        running: win.shown && !hov.hovered
        onTriggered: Capture.closePreview()
    }
    Connections { target: Capture; function onPreviewStampChanged() { if (win.shown) { life.restart(); runOut.restart(); } } }
    HoverHandler { id: hov; onHoveredChanged: if (!hovered && win.shown) { life.restart(); runOut.restart(); } }
    // a thin line running out while it waits
    property real remain: 1
    NumberAnimation { id: runOut; target: win; property: "remain"; from: 1; to: 0; duration: life.interval }
    onShownChanged: if (shown) { life.restart(); runOut.restart(); }

    // the last one stays in `shownFile` while the card slides away
    property string shownFile: ""
    onFileChanged: if (file !== "") shownFile = file

    Rectangle {
        id: card
        width: parent.width
        height: col.implicitHeight + 20
        anchors.bottom: win.onTop ? undefined : parent.bottom
        radius: Theme.corner(80, 12)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        CardShadow {}
        opacity: win.shown ? 1 : 0
        transform: Translate { x: win.shown ? 0 : (win.onRight ? 60 : -60) }
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: col
            x: 10; y: 10
            width: parent.width - 20
            spacing: 8
            Pressable {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: Theme.corner(80, 6)
                color: Theme.container
                clip: true
                onClicked: { Capture.edit(win.shownFile, Capture.previewSaved ? win.shownFile : ""); Capture.closePreview(); }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    Image { anchors.fill: parent; source: win.shownFile !== "" ? Wall.url(win.shownFile) : ""; sourceSize: Qt.size(640, 360); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false }
                }
                // it goes in a moment: a thin line running out
                Rectangle {
                    anchors.bottom: parent.bottom; height: 3; color: Theme.accent; radius: 1.5
                    width: parent.width * (hov.hovered ? 1 : win.remain)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                component Act: Pressable {
                    property string icon: ""
                    property string tip: ""
                    property bool danger: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: hovered ? (danger ? Qt.alpha(Theme.danger, 0.2) : Theme.containerHigh) : "transparent"
                    Icon { anchors.centerIn: parent; name: parent.icon; size: 20 }
                }
                Act { icon: "edit"; onClicked: { Capture.edit(win.shownFile, Capture.previewSaved ? win.shownFile : ""); Capture.closePreview(); } }
                Act { icon: "content_copy"; onClicked: { Capture.copyFile(win.shownFile); Capture.closePreview(); } }
                Act { icon: "push_pin"; onClicked: { Capture.pin(win.shownFile, win.modelData.name, null); Capture.closePreview(); } }
                Act { visible: Capture.previewSaved; icon: "folder_open"; onClicked: { Capture.openFolder(win.shownFile); Capture.closePreview(); } }
                Act { visible: Capture.previewSaved; icon: "delete"; danger: true; onClicked: Capture.deleteShot(win.shownFile) }
                Act { icon: "close"; onClicked: Capture.closePreview() }
            }
        }
    }
}
