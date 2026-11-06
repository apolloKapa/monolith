import QtQuick
import QtQuick.Effects
import Quickshell
import "../core"

// Your picture, cut to a circle (a mask, not `clip`, which only cuts to the square box), with a
// person icon until it loads. The picture: Settings → General, else the old shell's, else ~/.face.
Item {
    id: av
    property real size: 40
    property color fallback: Theme.accentContainer
    property color iconColor: Theme.onAccentContainer
    readonly property string path: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))
    implicitWidth: size
    implicitHeight: size
    Rectangle { anchors.fill: parent; radius: width / 2; color: av.fallback; visible: img.status !== Image.Ready }
    Image {
        id: img
        anchors.fill: parent
        source: Wall.url(av.path)
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(av.width * 2), Math.ceil(av.height * 2))
        asynchronous: true
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
    }
    Icon { anchors.centerIn: parent; visible: img.status !== Image.Ready; name: "person"; size: av.size * 0.55; filled: true; color: av.iconColor }
}
