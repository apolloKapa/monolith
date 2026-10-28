import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"
import "../reusables"

// Island bar (Settings -> Bar -> Style -> Island): in place of the bar, one shape at the top
// of each screen. Folded it's a pill with workspaces, the time, what's playing and unread
// notifications; hover it and it grows into a panel with workspace buttons, the player, the
// date and shortcuts, then folds back when the mouse leaves.
Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property bool enabledStyle: {
                let b = Config.getSetting("bar", {});
                return b && b.style === "island";
            }
            visible: enabledStyle

            function s(v) { return Scaler.s(v); }

            WlrLayershell.namespace: "qs-island"
            WlrLayershell.layer: WlrLayer.Top
            anchors { top: true; left: true; right: true }
            implicitHeight: s(300)
            exclusiveZone: s(48)
            ReservedReport { window: win }
            color: "transparent"
            mask: Region { item: island }

            property bool expanded: false
            readonly property var outputWorkspaces: {
                let list = [];
                let all = NiriState._workspaces || {};
                for (let id in all) {
                    let w = all[id];
                    if (w && w.output === (win.screen ? win.screen.name : "")) list.push(w);
                }
                list.sort((a, b) => a.idx - b.idx);
                // niri's spare empty workspace at the end isn't a real one
                let used = {};
                let wins = NiriState._windows || {};
                for (let k in wins) if (wins[k]) used[wins[k].workspace_id] = true;
                return list.filter((w, i) => i < list.length - 1 || used[w.id] || w.is_active || w.name);
            }
            readonly property var windowsByWs: {
                let m = {};
                let wins = NiriState._windows || {};
                for (let k in wins) { let w = wins[k]; if (w) m[w.workspace_id] = (m[w.workspace_id] || 0) + 1; }
                return m;
            }

            // monolith ipc call island toggle: unfold / fold the island on the main screen
            IpcHandler {
                target: "island"
                enabled: win.modelData === Quickshell.screens[0]
                function toggle(): void { foldTimer.stop(); win.expanded = !win.expanded; }
            }

            Component.onCompleted: NiriState.subscribe()
            Component.onDestruction: NiriState.unsubscribe()

            property date now: new Date()
            Timer { interval: 1000; repeat: true; running: win.visible; onTriggered: win.now = new Date() }

            Timer {
                id: foldTimer
                interval: 380
                onTriggered: win.expanded = false
            }

            function run(target) {
                win.expanded = false;
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "toggle", target]);
            }

            component Glyph: Text {
                color: ThemeBackend.text
                font.family: ThemeBackend.iconFont
                font.pixelSize: win.s(14)
            }
            component Label: Text {
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: win.s(13)
                elide: Text.ElideRight
            }
            component Pill: Rectangle {
                id: pill
                property string glyph: ""
                property string tip: ""
                property bool active: false
                signal clicked()
                implicitWidth: win.s(38)
                implicitHeight: win.s(38)
                radius: ThemeBackend.rad(win.s(12))
                color: active ? ThemeBackend.mauve : (pillMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.8))
                Behavior on color { ColorAnimation { duration: (120) * ThemeBackend.animScale } }
                Glyph {
                    anchors.centerIn: parent
                    text: pill.glyph
                    color: pill.active ? ThemeBackend.crust : ThemeBackend.text
                    font.pixelSize: win.s(16)
                }
                MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
            }

            Rectangle {
                id: island
                readonly property real foldedW: foldedRow.implicitWidth + win.s(28)
                readonly property real foldedH: win.s(38)
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.s(6)
                width: win.expanded ? Math.max(win.s(780), foldedW) : foldedW
                height: win.expanded ? win.s(262) : foldedH
                radius: win.expanded ? ThemeBackend.rad(win.s(26)) : ThemeBackend.rad(height / 2)
                color: Qt.alpha(ThemeBackend.base, ThemeBackend.opaqueStyle ? 1 : Math.max(0.82, ThemeBackend.elementOpacity))
                clip: true
                Behavior on width { NumberAnimation { duration: (320) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
                Behavior on height { NumberAnimation { duration: (320) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
                Behavior on radius { NumberAnimation { duration: (240) * ThemeBackend.animScale } }

                WallpaperBlur {
                    z: -1
                    anchors.fill: parent
                    radius: parent.radius
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) { foldTimer.stop(); win.expanded = true; }
                        else foldTimer.restart();
                    }
                }

                // ── folded: always visible along the top ──
                RowLayout {
                    id: foldedRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (island.foldedH - height) / 2
                    spacing: win.s(14)

                    Row {
                        spacing: win.s(5)
                        Repeater {
                            model: win.outputWorkspaces
                            Rectangle {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: modelData.is_active ? win.s(18) : win.s(7)
                                height: win.s(7)
                                radius: ThemeBackend.rad(height / 2)
                                color: modelData.is_active ? ThemeBackend.mauve : (win.windowsByWs[modelData.id] ? ThemeBackend.subtext1 : Qt.alpha(ThemeBackend.subtext0, 0.4))
                                Behavior on width { NumberAnimation { duration: (200) * ThemeBackend.animScale } }
                            }
                        }
                    }

                    Label {
                        text: Qt.formatDateTime(win.now, DateTime.is12Hour ? "h:mm AP" : "HH:mm")
                        font.weight: ThemeBackend.weightBold
                    }

                    RowLayout {
                        visible: MprisController.hasActivePlayer && MprisController.trackTitle !== ""
                        spacing: win.s(6)
                        Glyph { text: MprisController.isPlaying ? "󰎆" : "󰏤"; color: ThemeBackend.mauve }
                        Label {
                            Layout.maximumWidth: win.s(220)
                            text: MprisController.trackTitle
                            color: ThemeBackend.subtext1
                            font.pixelSize: win.s(12)
                        }
                    }

                    RowLayout {
                        readonly property int unread: NotificationManager.globalNotificationHistory ? NotificationManager.globalNotificationHistory.count : 0
                        visible: unread > 0
                        spacing: win.s(4)
                        Glyph { text: "󰂚"; color: ThemeBackend.subtext1 }
                        Label { text: parent.unread; font.pixelSize: win.s(11); color: ThemeBackend.subtext1 }
                    }
                }

                // ── unfolded ──
                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: island.foldedH + win.s(8)
                    anchors.margins: win.s(18)
                    spacing: win.s(18)
                    opacity: win.expanded && island.height > win.s(200) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: (180) * ThemeBackend.animScale } }

                    // workspaces
                    ColumnLayout {
                        Layout.preferredWidth: win.s(200)
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignTop
                        spacing: win.s(8)
                        Caption { text: I18n.t("island.workspaces", "Workspaces") }
                        GridLayout {
                            columns: 5
                            rowSpacing: win.s(6)
                            columnSpacing: win.s(6)
                            Repeater {
                                model: win.outputWorkspaces
                                Rectangle {
                                    required property var modelData
                                    Layout.preferredWidth: win.s(34)
                                    Layout.preferredHeight: win.s(34)
                                    radius: ThemeBackend.rad(win.s(10))
                                    color: modelData.is_active ? ThemeBackend.mauve : (wsMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.8))
                                    border.width: !modelData.is_active && win.windowsByWs[modelData.id] ? 1 : 0
                                    border.color: Qt.alpha(ThemeBackend.text, 0.25)
                                    Label {
                                        anchors.centerIn: parent
                                        text: String(parent.modelData.name || parent.modelData.idx).replace(/^d\d+-/, "")
                                        color: parent.modelData.is_active ? ThemeBackend.crust : ThemeBackend.text
                                        font.pixelSize: win.s(12)
                                        font.weight: ThemeBackend.weightBold
                                    }
                                    MouseArea {
                                        id: wsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", parent.modelData.name ? parent.modelData.name : String(parent.modelData.idx)])
                                    }
                                }
                            }
                        }
                    }

                    // player
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: win.s(14)
                        Rectangle {
                            Layout.preferredWidth: win.s(150)
                            Layout.preferredHeight: win.s(150)
                            radius: ThemeBackend.rad(win.s(16))
                            color: ThemeBackend.surface0
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: MprisController.currentArtUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                            Glyph { anchors.centerIn: parent; visible: !MprisController.currentArtUrl; text: "󰝚"; font.pixelSize: win.s(46); color: ThemeBackend.subtext0 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: win.s(4)
                            Label {
                                Layout.fillWidth: true
                                text: MprisController.hasActivePlayer ? (MprisController.trackTitle || "—") : I18n.t("dashboard.nothing_playing", "Nothing playing")
                                font.pixelSize: win.s(16)
                                font.weight: ThemeBackend.weightBold
                            }
                            Label { Layout.fillWidth: true; text: MprisController.trackArtist || ""; color: ThemeBackend.subtext1; font.pixelSize: win.s(12) }
                            Item { Layout.fillHeight: true }
                            RowLayout {
                                spacing: win.s(8)
                                opacity: MprisController.hasActivePlayer ? 1 : 0.4
                                Pill { glyph: "󰒮"; onClicked: { let p = MprisController.activePlayer; if (p && p.canGoPrevious) p.previous(); } }
                                Pill { glyph: MprisController.isPlaying ? "󰏤" : "󰐊"; active: true; onClicked: { let p = MprisController.activePlayer; if (p && p.canTogglePlaying) p.togglePlaying(); } }
                                Pill { glyph: "󰒭"; onClicked: { let p = MprisController.activePlayer; if (p && p.canGoNext) p.next(); } }
                            }
                        }
                    }

                    // date + shortcuts
                    ColumnLayout {
                        Layout.preferredWidth: win.s(200)
                        Layout.fillWidth: false
                        Layout.alignment: Qt.AlignTop
                        spacing: win.s(2)
                        Label { text: win.now.toLocaleDateString(Qt.locale(), "dddd"); color: ThemeBackend.subtext0; font.pixelSize: win.s(12) }
                        Label { text: win.now.toLocaleDateString(Qt.locale(), "d MMMM"); font.pixelSize: win.s(22); font.weight: Font.Bold }
                        RowLayout {
                            visible: Weather.isReady
                            spacing: win.s(6)
                            Glyph { text: Weather.currentIcon; color: Weather.currentHex; font.pixelSize: win.s(16) }
                            Label { text: Weather.currentTempFormatted; color: ThemeBackend.subtext1 }
                        }
                        Item { Layout.preferredHeight: win.s(10) }
                        GridLayout {
                            columns: 4
                            rowSpacing: win.s(6)
                            columnSpacing: win.s(6)
                            Pill { glyph: "󰀻"; onClicked: win.run("launcher") }
                            Pill { glyph: "󰕮"; onClicked: win.run("overview") }
                            Pill { glyph: "󰕰"; onClicked: win.run("dashboard") }
                            Pill { glyph: "󰒓"; onClicked: win.run("settings") }
                            Pill { glyph: "󰌌"; onClicked: win.run("cheatsheet") }
                            Pill { glyph: "󰂚"; onClicked: win.run("notifications") }
                            Pill { glyph: "󰕾"; onClicked: win.run("volume") }
                            Pill { glyph: "󰐥"; onClicked: win.run("session") }
                        }
                    }
                }
            }
        }
    }
}
