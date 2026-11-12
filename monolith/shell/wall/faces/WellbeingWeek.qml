import QtQuick
import "../../core"
import "../../ui"

// Wellbeing, week: Monday to Sunday as bars (today in the accent, the days to come faint), the
// week's total and the daily average, and the daily goal as a dashed line across.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: 0 }
    readonly property bool goalLine: f.opt("goalLine", true) !== false && wd.goal > 0
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 360; dh: 200
        Item {
            x: 18; y: 14; width: parent.width - 36; height: parent.height - 28
            Row {
                id: head
                width: parent.width; spacing: 6
                Icon { name: "bar_chart"; size: 16; color: f.accentC; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "This week"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Column {
                anchors.right: parent.right; anchors.top: parent.top
                Text { anchors.right: parent.right; text: wd.fmtShort(wd.weekTotal); color: f.mainC; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.Black }
                Text { visible: f.opt("showAverage", true) !== false; anchors.right: parent.right; text: wd.fmtShort(Math.round(wd.weekTotal / wd.weekDays)) + " a day"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 10 }
            }
            Item {
                id: chart
                y: 46; width: parent.width; height: parent.height - y
                readonly property real barsH: height - 18
                Row {
                    anchors.fill: parent
                    spacing: (width - 7 * 26) / 6
                    Repeater {
                        model: wd.week
                        Item {
                            required property var modelData
                            width: 26; height: chart.height
                            Rectangle {
                                anchors.bottom: lbl.top; anchors.bottomMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 18
                                height: Math.max(3, chart.barsH * parent.modelData.secs / wd.weekMax)
                                radius: Theme.corner(18)
                                color: parent.modelData.today ? f.accentC : Qt.alpha(f.mainC, parent.modelData.future ? 0.07 : (wd.goal > 0 && parent.modelData.secs > wd.goal ? 0.5 : 0.28))
                                Behavior on height { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutQuint } }
                            }
                            Text {
                                visible: f.opt("showTimes", false) === true && parent.modelData.secs > 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: chart.barsH - Math.max(3, chart.barsH * parent.modelData.secs / wd.weekMax) - 18
                                text: wd.fmtShort(parent.modelData.secs).replace(" ", ""); color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 8
                            }
                            Text { id: lbl; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.label
                                   color: parent.modelData.today ? f.mainC : f.subC; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: parent.modelData.today ? Font.Black : Font.Normal }
                        }
                    }
                }
                // the goal, dashed across
                Row {
                    visible: f.goalLine
                    y: chart.barsH - chart.barsH * wd.goal / wd.weekMax - 1
                    spacing: 4
                    Repeater { model: Math.max(0, Math.floor(chart.width / 8)); Rectangle { width: 4; height: 1.5; color: Qt.alpha(f.accentC, 0.7) } }
                }
            }
        }
    }
    WellOpen { face: f }
}
