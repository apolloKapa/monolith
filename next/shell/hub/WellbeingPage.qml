import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Wellbeing: today's screen time by app, and the last seven days. Right-click an app to give
// it a daily limit (off → 30 min → 1 h → 2 h → off).
Page {
    id: page
    pageId: "wellbeing"
    implicitHeight: 480

    readonly property var apps: Object.keys(Wellbeing.todayMap).map(k => ({ id: k, s: Wellbeing.todayMap[k] })).sort((a, b) => b.s - a.s)
    readonly property var week: {
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date(); d.setDate(d.getDate() - i);
            const k = Qt.formatDate(d, "yyyy-MM-dd");
            const m = Wellbeing.days[k] || {};
            out.push({ label: Qt.formatDate(d, "ddd"), s: Object.values(m).reduce((a, b) => a + b, 0), today: i === 0 });
        }
        return out;
    }
    readonly property real weekMax: Math.max(3600, ...week.map(w => w.s))
    function nameOf(id) { const e = DesktopEntries.byId(id); return e ? e.name : id; }
    function iconOf(id) { const e = DesktopEntries.byId(id); return Quickshell.iconPath(e ? e.icon : id, "application-x-executable"); }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // today
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 10)
            color: Theme.container
            Column {
                id: todayHead
                x: 18; y: 16
                Label { text: "Today"; muted: true }
                Label { text: Wellbeing.fmt(Wellbeing.todayTotal); font.pixelSize: 34; font.weight: Font.Light }
            }
            ListView {
                x: 10
                y: todayHead.y + todayHead.height + 10
                width: parent.width - 20
                height: parent.height - y - 10
                clip: true
                spacing: 6
                model: page.apps
                delegate: Pressable {
                    id: row
                    required property var modelData
                    readonly property int limit: Wellbeing.limitOf(modelData.id)
                    width: ListView.view.width
                    height: 54
                    color: Theme.containerHigh
                    onRightClicked: Wellbeing.setLimit(modelData.id, limit === 0 ? 30 : (limit === 30 ? 60 : (limit === 60 ? 120 : 0)))
                    Image { id: ai; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; sourceSize: Qt.size(60, 60); source: page.iconOf(row.modelData.id) }
                    Column {
                        anchors.left: ai.right; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        RowLayout {
                            width: parent.width
                            Label { text: page.nameOf(row.modelData.id); strong: true; Layout.fillWidth: true }
                            Label { text: Wellbeing.fmt(row.modelData.s) + (row.limit > 0 ? "  /  " + row.limit + " min" : ""); muted: true; font.pixelSize: Theme.sizeSmall }
                        }
                        Rectangle {
                            width: parent.width; height: 5; radius: 3
                            color: Theme.control
                            Rectangle {
                                width: parent.width * (row.limit > 0 ? Math.min(1, row.modelData.s / (row.limit * 60)) : row.modelData.s / Math.max(1, page.apps[0].s))
                                height: parent.height; radius: 3
                                color: row.limit > 0 && row.modelData.s >= row.limit * 60 ? Theme.danger : Theme.accent
                            }
                        }
                    }
                }
            }
            Label { anchors.centerIn: parent; visible: page.apps.length === 0; text: "Nothing yet today"; muted: true }
        }

        // the week
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            radius: Theme.corner(80, 10)
            color: Theme.container
            Label { x: 18; y: 16; text: "This week"; muted: true }
            Row {
                x: 18
                y: 60
                width: parent.width - 36
                height: parent.height - 90
                spacing: 8
                Repeater {
                    model: page.week
                    Item {
                        required property var modelData
                        width: (parent.width - 6 * 8) / 7
                        height: parent.height
                        Rectangle {
                            anchors.bottom: dayL.top; anchors.bottomMargin: 6
                            width: parent.width
                            height: Math.max(6, (parent.height - 30) * modelData.s / page.weekMax)
                            radius: Theme.corner(width)
                            color: modelData.today ? Theme.accent : Theme.control
                            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                        Label { id: dayL; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; muted: !modelData.today; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
            Label {
                x: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: "Average " + Wellbeing.fmt(page.week.reduce((a, w) => a + w.s, 0) / 7)
                muted: true
                font.pixelSize: Theme.sizeSmall
            }
        }
    }
}
