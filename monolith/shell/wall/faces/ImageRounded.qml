import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A picture, shown whole, its corners rounded like the theme. Its own picture (the editor), else the one in Settings → Desktop; animated
// GIFs play.
FaceBase {
    id: f
    readonly property string path: (f.opt("imagePath", "") || Store.get("widgets.imagePath", "")).replace(/^file:\/\//, "")
    readonly property real d: Math.min(width, height)
    Item {
        id: box
        anchors.centerIn: parent
        width: f.width; height: f.height
        Rectangle { id: shape; anchors.fill: parent; radius: Theme.corner(80, 14); color: Theme.container; visible: img.status !== Image.Ready }
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
            maskEnabled: true
            maskSource: mask
        }
        // the rounding sits on the picture itself (it's shown whole, so it may not fill the box)
        Item {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                width: img.paintedWidth > 0 ? Math.round(img.paintedWidth) : parent.width
                height: img.paintedHeight > 0 ? Math.round(img.paintedHeight) : parent.height
                x: Math.round((parent.width - width) / 2); y: Math.round((parent.height - height) / 2)
                radius: Theme.corner(80, 14)
            }
        }
        Icon { id: noPic; anchors.centerIn: parent; anchors.verticalCenterOffset: hint.visible ? -10 : 0; visible: img.status !== Image.Ready; name: "image"; size: Math.max(16, Math.min(box.width, box.height) * 0.35); color: Theme.subtext }
        // nothing picked yet: how to pick one (when there's room for it)
        Label { id: hint; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: noPic.bottom; anchors.topMargin: 4; visible: noPic.visible && f.path === "" && box.width >= 150 && box.height >= 110; width: box.width - 20; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: f.editing ? "Double-click to pick a picture, or drop one here" : "Drop a picture here (or right-click)"; muted: true; font.pixelSize: Theme.sizeSmall; Balance {} }
    }
}
