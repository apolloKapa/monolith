import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A picture widget's body, in one of three frames:
//   "rounded"  the whole picture, its own corners rounded like the theme's
//   "square"   the whole picture, square corners
//   "circle"   a circle the size of the widget's shorter side, the picture cropped to fill it
// The picture is the widget's own (picked in the editor), else the one in Settings → Desktop; a
// GIF plays while the widget is live. With none, a placeholder with a hint on how to pick one.
Item {
    id: frame
    required property var face
    property string shape: "rounded"
    readonly property bool circle: shape === "circle"
    readonly property string path: (face.opt("imagePath", "") || Store.get("widgets.imagePath", "")).replace(/^file:\/\//, "")
    readonly property bool loaded: pic.status === Image.Ready
    readonly property real themeCorner: Theme.corner(80, 14)
    width: circle ? Math.min(face.width, face.height) : face.width
    height: circle ? width : face.height
    anchors.centerIn: parent

    // the empty frame (no picture yet, or still loading)
    SmoothRect { visible: !frame.loaded && frame.shape === "rounded"; smoothing: 0; anchors.fill: parent; radius: frame.themeCorner; color: Theme.container }
    Rectangle { visible: !frame.loaded && frame.shape !== "rounded"; anchors.fill: parent; radius: frame.circle ? width / 2 : 0; color: Theme.container }

    AnimatedImage {
        id: pic
        visible: false
        anchors.fill: parent
        asynchronous: true
        playing: frame.face.live
        fillMode: frame.circle ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        source: frame.path !== "" ? Wall.url(frame.path) : ""
    }
    MultiEffect {
        visible: frame.loaded
        anchors.fill: parent
        source: pic
        maskEnabled: frame.shape !== "square"
        maskSource: frame.circle ? disc : fitted
    }
    // the circle's cut
    Rectangle { id: disc; visible: false; anchors.fill: parent; radius: width / 2; antialiasing: true; layer.enabled: true; layer.smooth: true }
    // the rounded frame's cut: the size the picture is actually drawn at (shown whole, it may not
    // fill the frame), so the rounding sits on the picture's own corners
    Item {
        id: fitted
        visible: false
        anchors.fill: parent
        layer.enabled: true
        SmoothRect {
            smoothing: 0   // (round in most styles; Cyberpunk cuts a corner instead)
            width: pic.paintedWidth > 0 ? Math.round(pic.paintedWidth) : parent.width
            height: pic.paintedHeight > 0 ? Math.round(pic.paintedHeight) : parent.height
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            radius: frame.themeCorner
        }
    }

    // no picture: an icon, and (with room for it) how to pick one
    Icon {
        id: placeholder
        visible: !frame.loaded
        anchors.centerIn: parent
        anchors.verticalCenterOffset: howTo.visible ? -10 : 0
        name: "image"
        size: Math.max(16, Math.min(frame.width, frame.height) * 0.35)
        color: Theme.subtext
    }
    Label {
        id: howTo
        visible: placeholder.visible && frame.path === "" && frame.width >= 150 && frame.height >= 110
        width: frame.width - 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: placeholder.bottom
        anchors.topMargin: 4
        renderType: Text.CurveRendering
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: frame.face.editing ? "Double-click to pick a picture, or drop one here" : "Drop a picture here (or right-click)"
        muted: true
        font.pixelSize: Theme.sizeSmall
        Balance {}
    }
}
