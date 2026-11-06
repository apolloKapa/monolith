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
        Icon { anchors.centerIn: parent; visible: img.status !== Image.Ready; name: "image"; size: Math.max(16, Math.min(box.width, box.height) * 0.35); color: Theme.subtext }
    }
}
