import QtQuick
import Quickshell
import "../../"
import ".."

// The frame shared by Monolith's panels that open in the master window (overview, dashboard,
// cheatsheet, session, switcher): themed background in the current style, intro/exit animation
// (Main.qml calls startExit), keyboard focus when shown. Put the panel's contents inside it.
Item {
    id: shell
    visible: false
    focus: true

    // false for full-screen panels that draw their own backdrop
    property bool framed: true
    property color backgroundColor: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
    property real padding: s(18)
    property real intro: 0
    // what gets keyboard focus when the panel opens (e.g. its search field); the panel itself if unset
    property Item focusTarget: null
    default property alias content: inner.data
    // called each time the panel opens (reset search fields, refresh data...)
    signal opened()

    function s(val) {
        return Scaler.s(val);
    }

    function takeFocus() {
        if (shell.focusTarget) shell.focusTarget.forceActiveFocus();
        else shell.forceActiveFocus();
    }

    function close() {
        Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "close"]);
    }

    property var exitCallback: null
    function startExit(onFinished) {
        introAnim.stop();
        shell.exitCallback = onFinished;
        exitAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            exitAnim.stop();
            shell.intro = 0;
            introAnim.restart();
            shell.opened();
            shell.takeFocus();
            focusTimer.restart();
        } else {
            introAnim.stop();
            exitAnim.stop();
            shell.intro = 0;
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: shell.takeFocus()
    }

    NumberAnimation {
        id: introAnim
        target: shell
        property: "intro"
        to: 1
        duration: (260) * ThemeBackend.animScale
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: exitAnim
        NumberAnimation { target: shell; property: "intro"; to: 0; duration: (170) * ThemeBackend.animScale; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (shell.exitCallback) {
                    let cb = shell.exitCallback;
                    shell.exitCallback = null;
                    cb();
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: shell.intro
        scale: 0.96 + 0.04 * shell.intro
        transform: Translate { y: shell.s(14) * (1 - shell.intro) }

        Rectangle {
            anchors.fill: parent
            visible: shell.framed
            radius: ThemeBackend.borderRadius
            color: shell.backgroundColor
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
            }
        }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: shell.framed ? shell.padding : 0
        }
    }
}
