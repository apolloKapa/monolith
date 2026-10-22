import QtQuick
import "../"
import "redactor"

Item {
    id: clockModule
    required property var screenRoot

    property var currentTime: new Date()
    readonly property bool concealed: screenRoot.inputActive || screenRoot.centerReveal > 0.02
    // Shrink on screens smaller than the layout, never stretch (stretching pixelates and oversizes)
    readonly property real fit: Math.min(1, width / LockLayoutStore.refW, height / LockLayoutStore.refH)

    anchors.fill: parent
    opacity: clockModule.concealed ? 0.0 : 1.0
    scale: clockModule.concealed ? 0.92 : 1.0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: (180) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

    Item {
        width: clockModule.width / clockModule.fit
        height: clockModule.height / clockModule.fit
        anchors.centerIn: parent
        scale: clockModule.fit

        LockLayoutView {
            anchors.fill: parent
            scope: "screen"
            ctx: clockModule.screenRoot
            spreadX: width / LockLayoutStore.refW
            spreadY: height / LockLayoutStore.refH
        }
    }
}
