pragma Singleton
import Quickshell
import QtQuick
// ============================================================
//  EDIT ME - every colour, size and speed of the bar lives here.
//  Save the file and the bar reloads by itself.
// ============================================================
Singleton {
   // which screens get a bar (empty list = every screen)
   readonly property var screens: ["DP-1","DP-2"]
   // workspace homes: names starting with a prefix belong to that monitor, all other named ones to mainOutput
   readonly property string mainOutput: "DP-1"
   readonly property var homes: ({ "d2-": "DP-2" })

   // modules on/off
   readonly property bool showWorkspaces: true
   readonly property bool showStats: true
   readonly property bool showClock: true
   readonly property bool showTray: true
   readonly property bool showPower: true
   // colours
   readonly property color bg: "#1a1a1a"
   readonly property color border: "#555555"
   readonly property color text: "#ffffff"
   readonly property color dim: "#a0a0a0"
   readonly property color hoverBg: "#ffffff"
   readonly property color hoverText: "#000000"
   readonly property color hover: "#2a2a2a"
   // sizes (pixels)
   readonly property int barHeight: 40
   readonly property int borderWidth: 2
   readonly property int pad: 14
   readonly property int spacing: 12
   readonly property int trayIcon: 18
   // how long a power button must be held, in milliseconds
   readonly property int holdTime: 1000
   // font
   readonly property string font: "JetBrainsMono Nerd Font"
   readonly property int fontSmall: 14
   readonly property int fontBig: 18
   // animation speeds (milliseconds, 0 = no animation)
   readonly property int animFast: 120
   readonly property int animNormal: 140
   readonly property int animSlow: 450
}
