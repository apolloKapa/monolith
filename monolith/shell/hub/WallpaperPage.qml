import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Wallpaper: the pictures in your wallpaper folder as a coverflow (←/→ or the wheel to browse,
// Enter or a click on the middle one to set it) or a grid. Picking one sets it everywhere and
// makes the shell's colours from it; right-click sets it for this screen only.
Page {
    id: page
    pageId: "wallpaper"
    implicitHeight: 520
    onCurrentChanged: if (current) { Wall.rescan(); flow.currentIndex = Math.max(0, Wall.images.indexOf(page.currentPath)); }
    readonly property string screenName: HubState.screenName !== "" ? HubState.screenName : Quickshell.screens[0].name
    readonly property string currentPath: Wall.pathFor(screenName)
    readonly property bool coverflow: Store.get("wallpaper.view", "flow") === "flow"
    Keys.onLeftPressed: if (coverflow) flow.decrementCurrentIndex()
    Keys.onRightPressed: if (coverflow) flow.incrementCurrentIndex()
    Keys.onReturnPressed: if (coverflow && Wall.images.length) Wall.set(Wall.images[flow.currentIndex])

    RowLayout {
        id: head
        width: parent.width
        height: 44
        Label { Layout.leftMargin: 6; text: Wall.dir.replace(Wall.home, "~") + "   ·   " + Wall.images.length + " pictures   ·   right-click: only this screen"; muted: true; Layout.fillWidth: true }
        Segmented {
            Layout.preferredWidth: 180
            height: 40
            opts: [["flow", "Coverflow"], ["grid", "Grid"]]
            value: page.coverflow ? "flow" : "grid"
            onPicked: v => Store.set("wallpaper.view", v)
        }
        Rectangle {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 40
            radius: Theme.corner(height)
            color: Theme.container
            Rectangle {
                y: 4
                x: Theme.modeName === "dark" ? 4 : parent.width / 2
                width: parent.width / 2 - 4
                height: parent.height - 8
                radius: Theme.corner(height)
                color: Theme.selected
                Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: [["dark", "Dark", "dark_mode"], ["light", "Light", "light_mode"]]
                    Pressable {
                        required property var modelData
                        width: parent.width / 2
                        height: parent.height
                        color: "transparent"
                        onClicked: Store.set("theme.mode", modelData[0])
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: modelData[2]; size: 18; filled: Theme.modeName === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData[1]; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }

    // ── coverflow: the pictures turn away on both sides of the middle one ──
    PathView {
        id: flow
        visible: page.coverflow
        y: head.height + 8
        width: parent.width
        height: page.implicitHeight - y - 40
        model: Wall.images
        pathItemCount: Math.min(9, Wall.images.length)
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: 380
        clip: true
        readonly property real cardW: Math.min(460, width * 0.5)
        readonly property real cardH: cardW * 0.6
        // the middle third gets most of the room; the sides are packed tight
        path: Path {
            startX: 0; startY: flow.height / 2
            PathAttribute { name: "turn"; value: 62 }
            PathAttribute { name: "size"; value: 0.62 }
            PathAttribute { name: "depth"; value: 0 }
            PathAttribute { name: "fade"; value: 0.35 }
            PathLine { x: flow.width * 0.33; y: flow.height / 2 }
            PathPercent { value: 0.38 }
            PathAttribute { name: "turn"; value: 48 }
            PathAttribute { name: "size"; value: 0.78 }
            PathAttribute { name: "depth"; value: 5 }
            PathAttribute { name: "fade"; value: 0.75 }
            PathLine { x: flow.width * 0.5; y: flow.height / 2 }
            PathPercent { value: 0.5 }
            PathAttribute { name: "turn"; value: 0 }
            PathAttribute { name: "size"; value: 1.0 }
            PathAttribute { name: "depth"; value: 10 }
            PathAttribute { name: "fade"; value: 1.0 }
            PathLine { x: flow.width * 0.67; y: flow.height / 2 }
            PathPercent { value: 0.62 }
            PathAttribute { name: "turn"; value: -48 }
            PathAttribute { name: "size"; value: 0.78 }
            PathAttribute { name: "depth"; value: 5 }
            PathAttribute { name: "fade"; value: 0.75 }
            PathLine { x: flow.width; y: flow.height / 2 }
            PathPercent { value: 1.0 }
            PathAttribute { name: "turn"; value: -62 }
            PathAttribute { name: "size"; value: 0.62 }
            PathAttribute { name: "depth"; value: 0 }
            PathAttribute { name: "fade"; value: 0.35 }
        }
        delegate: Item {
            id: card
            required property string modelData
            required property int index
            readonly property bool middle: PathView.isCurrentItem
            readonly property bool isCurrent: modelData === page.currentPath
            width: flow.cardW
            height: flow.cardH
            z: PathView.depth
            scale: PathView.size
            opacity: PathView.fade
            transform: Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.PathView.turn }
            Rectangle {
                anchors.fill: parent
                radius: Theme.corner(height, 6)
                color: Theme.container
                clip: true
                border.width: card.isCurrent ? 3 : 0
                border.color: Theme.accent
                Icon { anchors.centerIn: parent; visible: Wall.isVideo(card.modelData); name: "movie"; size: 48; color: Theme.subtext }
                Image {
                    anchors.fill: parent
                    anchors.margins: card.isCurrent ? 3 : 0
                    visible: !Wall.isVideo(card.modelData)
                    source: Wall.isVideo(card.modelData) ? "" : Wall.url(card.modelData)
                    sourceSize: Qt.size(640, 400)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                }
                Bubble { visible: card.isCurrent; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; size: 28; icon: "check"; on: true }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (!card.middle) { flow.currentIndex = card.index; return; }
                    if (mouse.button === Qt.RightButton) Wall.setFor(page.screenName, card.modelData);
                    else Wall.set(card.modelData);
                }
            }
        }
        // the wheel browses
        WheelHandler { onWheel: event => { if (event.angleDelta.y > 0 || event.angleDelta.x > 0) flow.decrementCurrentIndex(); else flow.incrementCurrentIndex(); } }
    }
    Label {
        visible: page.coverflow && Wall.images.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.implicitHeight - 30
        width: parent.width * 0.6
        horizontalAlignment: Text.AlignHCenter
        text: Wall.images.length ? Wall.images[flow.currentIndex].replace(/^.*\//, "") + "   ·   " + (flow.currentIndex + 1) + " / " + Wall.images.length : ""
        muted: true
        font.pixelSize: Theme.sizeSmall
    }

    GridView {
        id: grid
        visible: !page.coverflow
        y: head.height + 8
        width: parent.width
        height: page.implicitHeight - y
        clip: true
        cellWidth: width / 4
        cellHeight: cellWidth * 0.66
        model: Wall.images
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: cell
            required property string modelData
            readonly property bool isCurrent: modelData === Wall.pathFor(HubState.screenName !== "" ? HubState.screenName : Quickshell.screens[0].name)
            width: grid.cellWidth
            height: grid.cellHeight
            Pressable {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.corner(height, 2)
                color: Theme.container
                clip: true
                onClicked: Wall.set(cell.modelData)
                // right-click: only the screen the hub is on
                onRightClicked: Wall.setFor(HubState.screenName !== "" ? HubState.screenName : Quickshell.screens[0].name, cell.modelData)
                Icon { anchors.centerIn: parent; visible: Wall.isVideo(cell.modelData); name: "movie"; size: 36; color: Theme.subtext }
                Image {
                    anchors.fill: parent
                    visible: !Wall.isVideo(cell.modelData)
                    source: Wall.isVideo(cell.modelData) ? "" : Wall.url(cell.modelData)
                    sourceSize: Qt.size(320, 200)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                }
                // the current one: an accent ring and a check bubble
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: cell.isCurrent ? 3 : 0
                    border.color: Theme.accent
                }
                Bubble { visible: cell.isCurrent; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; size: 26; icon: "check"; on: true }
            }
        }
    }
}
