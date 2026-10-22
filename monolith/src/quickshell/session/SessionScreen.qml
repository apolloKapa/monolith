import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Session screen (monolith msg toggle session): lock, log out, suspend, hibernate, reboot,
// shut down. Arrow keys / Tab move, Enter picks, or press the underlined letter. The ones
// that end your session ask for a second press, so a stray click can't shut the PC down.
PopupShell {
    id: root
    framed: false

    property int current: 0
    property string armed: ""
    property bool canHibernate: false

    readonly property var actions: [
        { id: "lock", key: "L", icon: "󰌾", label: I18n.t("session.lock", "Lock"), script: "/scripts/lock.sh", confirm: false },
        { id: "logout", key: "E", icon: "󰗽", label: I18n.t("session.logout", "Log out"), script: "/scripts/system/exit.sh", confirm: true },
        { id: "suspend", key: "S", icon: "󰤄", label: I18n.t("session.suspend", "Suspend"), script: "/scripts/system/suspend.sh", confirm: false },
        { id: "hibernate", key: "H", icon: "󰒲", label: I18n.t("session.hibernate", "Hibernate"), script: "/scripts/system/hibernate.sh", confirm: true },
        { id: "reboot", key: "R", icon: "󰑓", label: I18n.t("session.reboot", "Reboot"), script: "/scripts/system/reboot.sh", confirm: true },
        { id: "poweroff", key: "P", icon: "󰐥", label: I18n.t("session.poweroff", "Shut down"), script: "/scripts/system/poweroff.sh", confirm: true }
    ].filter(a => a.id !== "hibernate" || root.canHibernate)

    onOpened: {
        root.current = 0;
        root.armed = "";
        hibernateProbe.running = true;
    }

    function run(i) {
        let a = root.actions[i];
        if (!a) return;
        root.current = i;
        if (a.confirm && root.armed !== a.id) {
            root.armed = a.id;
            disarm.restart();
            return;
        }
        root.close();
        Quickshell.execDetached(["bash", Caching.monolithDir + a.script]);
    }

    Process {
        id: hibernateProbe
        command: ["bash", Caching.monolithDir + "/scripts/system/can_hibernate.sh"]
        onExited: (code) => root.canHibernate = code === 0
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    Keys.onPressed: (event) => {
        let n = root.actions.length;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
            root.current = (root.current + 1) % n; root.armed = ""; event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.current = (root.current - 1 + n) % n; root.armed = ""; event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.run(root.current); event.accepted = true;
        } else {
            let k = event.text.toUpperCase();
            for (let i = 0; i < n; i++) {
                if (root.actions[i].key === k) { root.run(i); event.accepted = true; return; }
            }
        }
    }

    // dim the screen; clicking outside the buttons closes
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.crust, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: root.s(26)

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(54)
            font.weight: Font.Bold
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.s(14)

            Repeater {
                model: root.actions

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.current === index
                    readonly property bool isArmed: root.armed === modelData.id

                    Layout.preferredWidth: root.s(132)
                    Layout.preferredHeight: root.s(132)
                    radius: ThemeBackend.rad(root.s(18))
                    color: isArmed ? ThemeBackend.red : (sel ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface0, Math.max(0.75, ThemeBackend.elementOpacity)))
                    scale: tileMa.pressed ? 0.95 : (sel ? 1.05 : 1.0)
                    Behavior on color { ColorAnimation { duration: (160) * ThemeBackend.animScale } }
                    Behavior on scale { NumberAnimation { duration: (180) * ThemeBackend.animScale; easing.type: Easing.OutBack } }

                    WallpaperBlur {
                        z: -1
                        anchors.fill: parent
                        radius: parent.radius
                        nestLevel: 0
                        visible: !tile.sel && !tile.isArmed
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.s(8)
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            color: (tile.sel || tile.isArmed) ? ThemeBackend.crust : ThemeBackend.text
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(38)
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.isArmed ? I18n.t("session.confirm", "Again to confirm") : tile.modelData.label
                            color: (tile.sel || tile.isArmed) ? ThemeBackend.crust : ThemeBackend.subtext1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(tile.isArmed ? 11 : 13)
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { if (root.current !== tile.index) { root.current = tile.index; root.armed = ""; } }
                        onClicked: root.run(tile.index)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: I18n.t("session.hint", "←/→ to move · Enter or the first letter to pick · Esc to close")
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
        }
    }
}
