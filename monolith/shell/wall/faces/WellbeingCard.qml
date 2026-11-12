import QtQuick
import "../../core"
import "../../ui"

// Wellbeing, card: today's screen time big, against the day before, the daily goal as a bar,
// the busiest apps, and (optionally) this week as a strip of little bars.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: Number(f.opt("apps", 3)) }
    readonly property bool showGoal: f.opt("showGoal", true) !== false && wd.goal > 0
    readonly property bool showWeek: f.opt("showWeek", true) !== false
    readonly property bool showDiff: f.opt("showDiff", true) !== false
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 340; dh: 150 + (wd.top.length || 1) * 30 + (f.showGoal ? 30 : 0) - 30
        Column {
            x: 18; y: 16; width: parent.width - 36
            spacing: 8
            Row {
                width: parent.width; spacing: 6
                Icon { name: "self_improvement"; size: 16; color: f.accentC; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Screen time today"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 10
                Text { text: wd.fmt(wd.total); color: f.mainC; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Black }
                Row {
                    visible: f.showDiff && wd.diffText() !== ""
                    spacing: 3
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    Icon { name: wd.diff > 0 ? "trending_up" : "trending_down"; size: 13; color: f.subC; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: wd.diffText(); color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            // the goal: a bar to it (red past it)
            Item {
                visible: f.showGoal
                width: parent.width; height: 22
                Rectangle {
                    y: 0; width: parent.width; height: 7; radius: Theme.corner(7); color: Qt.alpha(Theme.text, 0.12)
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: Math.max(7, parent.width * Math.min(1, wd.total / Math.max(1, wd.goal)))
                        color: wd.total > wd.goal ? Theme.danger : f.accentC
                        Behavior on width { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutQuint } }
                    }
                }
                Text {
                    y: 10
                    text: wd.total > wd.goal ? "Over your " + wd.fmtShort(wd.goal) + " goal by " + wd.fmtShort(wd.total - wd.goal) : wd.fmtShort(wd.goal - wd.total) + " left of your " + wd.fmtShort(wd.goal) + " goal"
                    color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 10
                }
            }
            // the busiest apps
            Repeater {
                model: wd.top
                Item {
                    required property var modelData
                    width: parent.width; height: 22
                    Image { id: ai; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: parent.modelData.icon; anchors.verticalCenter: parent.verticalCenter; asynchronous: true }
                    Text { anchors.left: ai.right; anchors.leftMargin: 7; anchors.right: at.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                           text: parent.modelData.name; elide: Text.ElideRight; color: f.mainC; font.family: Theme.fontFamily; font.pixelSize: 12 }
                    Text { id: at; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: wd.fmtShort(parent.modelData.secs); color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold }
                    Rectangle { anchors.bottom: parent.bottom; x: 23; width: (parent.width - 23) * parent.modelData.secs / Math.max(1, wd.total); height: 2; radius: 1; color: Qt.alpha(f.accentC, 0.6) }
                }
            }
            Text { visible: wd.top.length === 0; text: Wellbeing.tracking ? "Nothing yet today" : "Screen time is off (Wellbeing → gear)"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 11 }
        }
        // this week: a strip of little bars in the top corner, today in the accent
        Row {
            visible: f.showWeek
            y: 14
            anchors.right: parent.right; anchors.rightMargin: 18
            spacing: 4
            Repeater {
                model: wd.week
                Column {
                    required property var modelData
                    spacing: 2
                    Item {
                        width: 9; height: 24
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: Math.max(2, parent.height * parent.parent.modelData.secs / wd.weekMax)
                            radius: Theme.corner(9)
                            color: parent.parent.modelData.today ? f.accentC : Qt.alpha(f.mainC, parent.parent.modelData.future ? 0.08 : 0.3)
                        }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.label[0]; color: parent.modelData.today ? f.mainC : f.subC; font.family: Theme.fontFamily; font.pixelSize: 8; font.weight: Font.Bold }
                }
            }
        }
    }
    WellOpen { face: f }
}
