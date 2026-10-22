import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Window switcher (monolith msg toggle switcher): every window on every workspace, most
// recently used first, with the previous one already picked. Tab / arrows move, Enter or a
// click switches; when opened from an Alt keybind, letting go of Alt switches too.
PopupShell {
    id: root

    property var windows: []
    property var workspaces: ({})
    property int current: 0
    property bool altHeld: false

    onOpened: {
        root.windows = [];
        root.current = 0;
        root.altHeld = true;
        loader.running = true;
    }

    function pick(i) {
        let w = root.windows[i];
        if (!w) return;
        root.close();
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(w.id)]);
    }

    function step(d) {
        let n = root.windows.length;
        if (n > 0) root.current = (root.current + d + n) % n;
    }

    function iconFor(appId) {
        let e = AppMatcher.entry(AppMatcher.resolve(appId));
        let name = e && e.icon ? e.icon : appId;
        return Quickshell.iconPath(name, true) || Quickshell.iconPath(String(appId).toLowerCase(), true) || "";
    }

    Process {
        id: loader
        command: ["sh", "-c", "printf '{\"windows\":%s,\"workspaces\":%s}' \"$(niri msg -j windows)\" \"$(niri msg -j workspaces)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text);
                    let ws = {};
                    for (let w of d.workspaces) ws[w.id] = w;
                    let wins = d.windows.slice();
                    let ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0;
                    wins.sort((a, b) => (b.is_focused - a.is_focused) || (ts(b) - ts(a)));
                    root.workspaces = ws;
                    root.windows = wins;
                    root.current = wins.length > 1 ? 1 : 0;
                } catch (e) {
                    root.windows = [];
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true;
        } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.step(-1); event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.pick(root.current); event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Alt && root.altHeld && root.windows.length > 0) {
            root.altHeld = false;
            root.pick(root.current);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(12)

        Text {
            text: I18n.t("switcher.title", "Windows")
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            font.weight: Font.DemiBold
        }

        ListView {
            id: list
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width, contentWidth)
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: root.s(10)
            clip: true
            model: root.windows
            currentIndex: root.current
            highlightMoveDuration: (160) * ThemeBackend.animScale
            preferredHighlightBegin: width / 2 - root.s(85)
            preferredHighlightEnd: width / 2 + root.s(85)
            highlightRangeMode: ListView.ApplyRange

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: index === root.current
                readonly property var ws: root.workspaces[modelData.workspace_id]

                width: root.s(170)
                height: list.height
                radius: ThemeBackend.borderRadius
                color: sel ? Qt.alpha(ThemeBackend.mauve, 0.22) : (cardMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.5))
                border.width: sel ? 2 : (ThemeBackend.outlined ? ThemeBackend.outlineInner : 0)
                border.color: sel ? ThemeBackend.mauve : ThemeBackend.outlineColor
                Behavior on color { ColorAnimation { duration: (120) * ThemeBackend.animScale } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(12)
                    spacing: root.s(8)

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Image {
                            id: icon
                            anchors.centerIn: parent
                            width: root.s(64); height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: root.iconFor(card.modelData.app_id)
                            visible: status === Image.Ready
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !icon.visible
                            text: (card.modelData.app_id || "?").charAt(0).toUpperCase()
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(40)
                            font.weight: Font.Bold
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.title || card.modelData.app_id
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (card.modelData.app_id || "") + (card.ws ? "  ·  " + (card.ws.name || card.ws.idx) + (card.ws.output ? " " + card.ws.output : "") : "")
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(10)
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(card.index)
                }
            }
        }
    }
}
