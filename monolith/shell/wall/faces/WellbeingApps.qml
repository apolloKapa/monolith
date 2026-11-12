import QtQuick
import "../../core"
import "../../ui"

// Wellbeing, top apps: today's busiest apps with their icons, time and a bar each (against the
// busiest), today's total at the top.
FaceBase {
    id: f
    WellData { id: wd; now: f.now; apps: Number(f.opt("apps", 5)) }
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 320; dh: 60 + Math.max(2, wd.top.length) * 36
        Column {
            x: 16; y: 14; width: parent.width - 32
            spacing: 8
            Item {
                width: parent.width; height: 22
                Row {
                    spacing: 6; anchors.verticalCenter: parent.verticalCenter
                    Icon { name: "apps"; size: 16; color: f.accentC; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Today's apps"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: wd.fmtShort(wd.total); color: f.mainC; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Black }
            }
            Repeater {
                model: wd.top
                Item {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 28
                    Image { id: ic; visible: f.opt("showIcons", true) !== false; width: 22; height: 22; sourceSize: Qt.size(44, 44); source: parent.modelData.icon; asynchronous: true; anchors.verticalCenter: parent.verticalCenter }
                    Item {
                        anchors.left: ic.visible ? ic.right : parent.left; anchors.leftMargin: ic.visible ? 10 : 0; anchors.right: parent.right
                        height: parent.height
                        Text { text: parent.parent.modelData.name; width: parent.width - tt.width - 8; elide: Text.ElideRight; color: f.mainC; font.family: Theme.fontFamily; font.pixelSize: 12 }
                        Text { id: tt; anchors.right: parent.right; text: wd.fmtShort(parent.parent.modelData.secs); color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                            width: parent.width; height: 5; radius: Theme.corner(5); color: Qt.alpha(Theme.text, 0.1)
                            Rectangle { height: parent.height; radius: parent.radius; width: Math.max(5, parent.width * parent.parent.parent.modelData.secs / Math.max(1, wd.top[0].secs))
                                        color: parent.parent.parent.index === 0 ? f.accentC : Qt.alpha(f.accentC, 0.55) }
                        }
                    }
                }
            }
            Text { visible: wd.top.length === 0; text: Wellbeing.tracking ? "Nothing yet today" : "Screen time is off (Wellbeing → gear)"; color: f.subC; font.family: Theme.fontFamily; font.pixelSize: 11 }
        }
    }
    WellOpen { face: f }
}
