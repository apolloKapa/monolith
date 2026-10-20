pragma Singleton
import Quickshell
import QtQuick

// ============================================================
//  EDIT ME - look and speed of the launcher menu.
//  Save the file and the launcher reloads by itself.
// ============================================================
Singleton {
    // colours
    readonly property color bg: "#1a1a1a"
    readonly property color border: "#555555"
    readonly property color accent: "#ffffff"
    readonly property color text: "#ffffff"
    readonly property color dim: "#a0a0a0"
    readonly property color field: "#111111"
    readonly property color hoverBg: "#ffffff"
    readonly property color hoverText: "#000000"
    readonly property color hover: "#2a2a2a"

    // menu size (pixels)
    readonly property int menuWidth: 760
    readonly property int menuHeight: 580
    readonly property int lineHeight: 2
    readonly property int borderWidth: 2
    readonly property int favTile: 52
    readonly property int favGap: 8

    // font
    readonly property string font: "JetBrains Mono"

    // animation speeds (milliseconds, 0 = instant)
    // line grows sideways -> box opens downwards/upwards -> contents fade in
    readonly property int animLine: 90
    readonly property int animOpen: 130
    readonly property int animFade: 70
    readonly property int animFast: 70
    readonly property int animMove: 110
}
