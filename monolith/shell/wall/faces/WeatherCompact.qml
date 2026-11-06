import QtQuick
import "../../core"
import "../../ui"

// Weather, compact: glass; the condition's icon in its colour and the temperature, side by side
// (or stacked when narrow).
FaceBase {
    id: f
    WeatherTone { id: wt }
    readonly property bool wide: width > height * 1.15
    readonly property real m: Math.max(6, Math.min(16, Math.min(width, height) * 0.08))
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 14) }
    Grid {
        anchors.centerIn: parent
        columns: f.wide ? 2 : 1
        spacing: f.m * 0.5
        Item {
            width: f.wide ? (f.width - 2 * f.m) / 2 : f.width - 2 * f.m
            height: f.wide ? f.height - 2 * f.m : (f.height - 2 * f.m) / 2
            Icon { anchors.centerIn: parent; name: wt.icon; filled: true; size: Math.min(parent.width, parent.height) * 0.7; color: wt.color }
        }
        Item {
            width: f.wide ? (f.width - 2 * f.m) / 2 : f.width - 2 * f.m
            height: f.wide ? f.height - 2 * f.m : (f.height - 2 * f.m) / 2
            Text { anchors.centerIn: parent; text: wt.temp; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.min(parent.width, parent.height) * 0.5 }
        }
    }
}
