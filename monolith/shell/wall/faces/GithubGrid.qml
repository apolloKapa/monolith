import QtQuick
import "../../core"
import "../../ui"

// GitHub: glass; someone's contributions over the last year as GitHub's grid of squares
// (weeks across, weekdays down), the total, and the day under the pointer.
FaceBase {
    id: f
    property var hovered: null
    property bool held: false
    readonly property bool want: f.live && f.visible
    onWantChanged: { if (want && !held) { GitHub.hold(); held = true; } else if (!want && held) { GitHub.release(); held = false; } }
    Component.onCompleted: if (want) { GitHub.hold(); held = true; }
    Component.onDestruction: if (held) GitHub.release()
    readonly property int pad: GitHub.days.length ? new Date(GitHub.days[0].date).getDay() : 0
    readonly property int cells: GitHub.days.length ? pad + GitHub.days.length : 7 * 53
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 560; dh: 190
        Row {
            x: 16; y: 14; spacing: 8
            Icon { name: "commit"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text { text: GitHub.user !== "" ? GitHub.user : "GitHub"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 16
            text: f.hovered ? f.hovered.count + (f.hovered.count === 1 ? " contribution" : " contributions") + " on " + Qt.formatDate(new Date(f.hovered.date), "d MMM yyyy")
                : (GitHub.state === "ok" ? GitHub.total + " contributions in the last year" : "")
            color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12
        }
        Grid {
            id: grid
            x: 16; y: 46
            rows: 7; flow: Grid.TopToBottom
            spacing: 2
            readonly property real cell: Math.min((parent.width - 32 - 52 * 2) / 53, (parent.height - 60 - 6 * 2) / 7)
            Repeater {
                model: f.cells
                Rectangle {
                    required property int index
                    readonly property var day: GitHub.days[index - f.pad]
                    width: grid.cell; height: grid.cell; radius: grid.cell * 0.25
                    opacity: index >= f.pad ? 1 : 0
                    color: day && day.level > 0 ? Qt.alpha(Theme.accent, 0.25 + 0.1875 * day.level) : Qt.alpha(Theme.text, 0.1)
                    border.width: f.hovered === day && day ? 1.5 : 0; border.color: Theme.text
                    MouseArea { anchors.fill: parent; hoverEnabled: true; enabled: !!parent.day && f.live; onEntered: f.hovered = parent.day; onExited: if (f.hovered === parent.day) f.hovered = null }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: f.live && GitHub.state !== "ok"
            text: GitHub.user === "" ? "Set your GitHub name: select this widget in the editor" : (GitHub.state === "error" ? "Couldn't load " + GitHub.user + "'s contributions" : "Loading…")
            color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 13
        }
    }
}
