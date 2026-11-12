import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A picture: square corners, the whole picture. Its own picture (the editor), else the one in Settings → Desktop; animated
// GIFs play.
FaceBase {
    id: f
    readonly property string path: (f.opt("imagePath", "") || Store.get("widgets.imagePath", "")).replace(/^file:\/\//, "")
    readonly property real d: Math.min(width, height)
    Item {
        id: box
        anchors.centerIn: parent
        width: f.width; height: f.height
        Rectangle { id: shape; anchors.fill: parent; radius: 0; color: Theme.container; visible: img.status !== Image.Ready }
        AnimatedImage {
            id: img
            anchors.fill: parent
            source: f.path !== "" ? Wall.url(f.path) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            playing: f.live
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            visible: img.status === Image.Ready
            maskEnabled: false
            maskSource: mask
        }
        Rectangle { id: mask; anchors.fill: parent; radius: 0; visible: false; layer.enabled: true }
        Icon { id: noPic; anchors.centerIn: parent; anchors.verticalCenterOffset: hint.visible ? -10 : 0; visible: img.status !== Image.Ready; name: "image"; size: Math.max(16, Math.min(box.width, box.height) * 0.35); color: Theme.subtext }
        // nothing picked yet: how to pick one (when there's room for it)
        Label { id: hint; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: noPic.bottom; anchors.topMargin: 4; visible: noPic.visible && f.path === "" && box.width >= 150 && box.height >= 110; width: box.width - 20; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: f.editing ? "Double-click to pick a picture, or drop one here" : "Drop a picture here (or right-click)"; muted: true; font.pixelSize: Theme.sizeSmall }
    }
}
