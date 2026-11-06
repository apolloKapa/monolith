import QtQuick
import Quickshell
import "../../core"
import "../../ui"

// GitHub: glass; someone's contributions as GitHub's grid of squares (weeks across, weekdays
// down). Click the name to change it right here; scroll over the grid (or the arrows) to go
// through the years; click a day to keep it shown; the total opens the profile.
FaceBase {
    id: f
    property var hovered: null
    property var picked: null
    property bool editing: false
    property bool held: false
    readonly property bool want: f.live && f.visible
    onWantChanged: { if (want && !held) { GitHub.hold(); held = true; } else if (!want && held) { GitHub.release(); held = false; } }
    Component.onCompleted: if (want) { GitHub.hold(); held = true; }
    Component.onDestruction: if (held) GitHub.release()
    Connections { target: GitHub; function onDaysChanged() { f.picked = null; f.hovered = null; } }
    readonly property int pad: GitHub.days.length ? new Date(GitHub.days[0].date).getDay() : 0
    readonly property int cells: GitHub.days.length ? pad + GitHub.days.length : 7 * 53
    readonly property var shown: hovered || picked
    readonly property string period: GitHub.year === 0 ? "the last year" : String(GitHub.year)

    // a small round button
    component Btn: Rectangle {
        id: b
        property string icon: ""
        property bool on: true
        signal hit()
        width: 28; height: 28; radius: Theme.corner(28, 8)
        opacity: on ? 1 : 0.35
        color: Qt.alpha(bm.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
        Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
        Icon { anchors.centerIn: parent; name: b.icon; size: 16; color: bm.containsMouse ? Theme.accent : Theme.subtext }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; enabled: f.live && b.on; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
    }

    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 560; dh: 190
        // the name (click to change it)
        Row {
            x: 16; y: 12; height: 28; spacing: 8
            Icon { name: "commit"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                visible: !f.editing
                anchors.verticalCenter: parent.verticalCenter
                height: 28; width: un.implicitWidth + 16; radius: Theme.corner(28, 8)
                color: um.containsMouse ? Qt.alpha(Theme.control, 0.85) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                Text { id: un; anchors.centerIn: parent; text: GitHub.user !== "" ? GitHub.user : "Set your GitHub name"; color: GitHub.user !== "" ? Theme.text : Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 15 }
                MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; enabled: f.live; cursorShape: Qt.IBeamCursor; onClicked: { f.editing = true; input.text = GitHub.user; input.forceActiveFocus(); input.selectAll(); } }
            }
            Rectangle {
                visible: f.editing
                anchors.verticalCenter: parent.verticalCenter
                height: 28; width: 200; radius: Theme.corner(28, 8)
                color: Qt.alpha(Theme.control, 0.9)
                border.width: 1.5; border.color: Theme.accent
                TextInput {
                    id: input
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text; selectionColor: Theme.selected
                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 13
                    clip: true
                    onAccepted: { GitHub.setUser(text); f.editing = false; }
                    Keys.onEscapePressed: f.editing = false
                    onActiveFocusChanged: if (!activeFocus) f.editing = false
                    Text { visible: input.text === ""; text: "username, then Enter"; color: Theme.subtext; font: input.font; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        // the year, refresh, the profile
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; y: 12
            spacing: 4
            Btn { icon: "chevron_left"; on: GitHub.year !== 2008; onHit: GitHub.stepYear(-1) }
            Text { width: 74; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: GitHub.year === 0 ? "Last year" : GitHub.year; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12 }
            Btn { icon: "chevron_right"; on: GitHub.year !== 0; onHit: GitHub.stepYear(1) }
            Item { width: 4; height: 1 }
            Btn { icon: "refresh"; on: GitHub.user !== ""; onHit: GitHub.fetch() }
            Btn { icon: "open_in_new"; on: GitHub.user !== ""; onHit: Quickshell.execDetached(["xdg-open", "https://github.com/" + GitHub.user]) }
        }
        Grid {
            id: grid
            x: 16; y: 50
            rows: 7; flow: Grid.TopToBottom
            spacing: 2
            readonly property real cell: Math.min((parent.width - 32 - 52 * 2) / 53, (parent.height - 50 - 40 - 6 * 2) / 7)
            Repeater {
                model: f.cells
                Rectangle {
                    required property int index
                    readonly property var day: GitHub.days[index - f.pad]
                    width: grid.cell; height: grid.cell; radius: grid.cell * 0.25
                    opacity: index >= f.pad ? 1 : 0
                    color: day && day.level > 0 ? Qt.alpha(Theme.accent, 0.25 + 0.1875 * day.level) : Qt.alpha(Theme.text, 0.1)
                    border.width: day && (f.hovered === day || f.picked === day) ? 1.5 : 0; border.color: Theme.text
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; enabled: !!parent.day && f.live
                        cursorShape: Qt.PointingHandCursor
                        onEntered: f.hovered = parent.day
                        onExited: if (f.hovered === parent.day) f.hovered = null
                        onClicked: f.picked = f.picked === parent.day ? null : parent.day
                    }
                }
            }
            // scrolling over the grid goes through the years
            WheelHandler {
                enabled: f.live
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0
                onWheel: e => { acc += e.angleDelta.y; if (Math.abs(acc) >= 120) { GitHub.stepYear(acc > 0 ? 1 : -1); acc = 0; } }
            }
        }
        // the day (hovered or picked) or the total, which opens the profile
        Rectangle {
            x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            height: 26; width: info.implicitWidth + 16; radius: Theme.corner(26, 8)
            color: im.containsMouse ? Qt.alpha(Theme.control, 0.85) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
            Text {
                id: info
                anchors.centerIn: parent
                text: f.shown ? f.shown.count + (f.shown.count === 1 ? " contribution" : " contributions") + " on " + Qt.formatDate(new Date(f.shown.date), "dddd, d MMM yyyy")
                    : (GitHub.state === "ok" ? GitHub.total + " contributions in " + f.period : "")
                color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12
            }
            MouseArea { id: im; anchors.fill: parent; hoverEnabled: true; enabled: f.live && GitHub.user !== ""; cursorShape: Qt.PointingHandCursor
                onClicked: f.picked ? (f.picked = null) : Quickshell.execDetached(["xdg-open", "https://github.com/" + GitHub.user]) }
        }
        Text {
            anchors.centerIn: parent
            visible: f.live && GitHub.state !== "ok"
            text: GitHub.user === "" ? "Click “Set your GitHub name” above" : (GitHub.state === "error" ? "Couldn't load " + GitHub.user + "'s contributions" : "Loading…")
            color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 13
        }
    }
}
