import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"

// Dashboard (monolith msg toggle dashboard): one overlay with the day at a glance.
// Left: clock, weather, month. Middle: what's playing, recent notifications.
// Right: pomodoro and the todo list.
PopupShell {
    id: root

    property date now: new Date()
    property int monthOffset: 0
    focusTarget: todoInput.field

    onOpened: {
        root.now = new Date();
        root.monthOffset = 0;
        todoInput.clear();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias body: cardBody.data
        Layout.fillWidth: true
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.surface0, Math.max(0.5, ThemeBackend.elementOpacity * 0.7))
        border.width: ThemeBackend.outlined ? ThemeBackend.outlineInner : 0
        border.color: ThemeBackend.outlineColor

        RowLayout {
            id: cardHead
            visible: card.title !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.s(14)
            spacing: root.s(8)
            Text {
                text: card.icon
                visible: card.icon !== ""
                color: ThemeBackend.mauve
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.s(15)
            }
            Text {
                Layout.fillWidth: true
                text: card.title
                color: ThemeBackend.subtext1
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
                font.weight: Font.Bold
            }
        }
        Item {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: cardHead.visible ? cardHead.bottom : parent.top
            anchors.margins: root.s(14)
        }
    }

    component RoundButton: Rectangle {
        id: btn
        property string glyph: ""
        property bool primary: false
        signal clicked()
        width: root.s(primary ? 46 : 36)
        height: width
        radius: ThemeBackend.rad(width / 2)
        color: primary ? ThemeBackend.mauve : (btnMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface1, 0.6))
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.primary ? ThemeBackend.crust : ThemeBackend.text
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(btn.primary ? 20 : 15)
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: root.s(14)

        // ── left: time, weather, month ──
        ColumnLayout {
            Layout.preferredWidth: root.s(340)
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: root.s(14)

            Card {
                Layout.preferredHeight: root.s(170)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Text {
                        text: Qt.formatDateTime(root.now, DateTime.is12Hour ? "h:mm" : "HH:mm")
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(64)
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                        color: ThemeBackend.subtext1
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(15)
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        spacing: root.s(8)
                        Text {
                            text: Weather.currentIcon || "󰖐"
                            color: Weather.currentHex
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(20)
                        }
                        Text {
                            text: Weather.isReady ? Weather.currentTempFormatted : I18n.t("dashboard.no_weather", "no weather (set a location in Settings → General)")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(Weather.isReady ? 16 : 11)
                        }
                    }
                }
            }

            Card {
                id: monthCard
                Layout.fillHeight: true
                readonly property date shown: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1)
                title: shown.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                icon: "󰃭"

                RowLayout {
                    anchors.right: parent.right
                    y: -root.s(32)
                    spacing: root.s(4)
                    RoundButton { glyph: "󰅁"; width: root.s(26); onClicked: root.monthOffset -= 1 }
                    RoundButton { glyph: "󰅂"; width: root.s(26); onClicked: root.monthOffset += 1 }
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 7
                    rowSpacing: root.s(2)
                    columnSpacing: root.s(2)

                    Repeater {
                        model: 7
                        Text {
                            required property int index
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            // weeks start on Monday
                            text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).substring(0, 2)
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                        }
                    }
                    Repeater {
                        model: 42
                        Rectangle {
                            required property int index
                            readonly property int lead: (monthCard.shown.getDay() + 6) % 7
                            readonly property date day: new Date(monthCard.shown.getFullYear(), monthCard.shown.getMonth(), index - lead + 1)
                            readonly property bool inMonth: day.getMonth() === monthCard.shown.getMonth()
                            readonly property bool today: day.toDateString() === root.now.toDateString()
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height, root.s(34))
                                height: width
                                radius: ThemeBackend.rad(width / 2)
                                color: parent.today ? ThemeBackend.mauve : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.day.getDate()
                                color: parent.today ? ThemeBackend.crust : (parent.inMonth ? ThemeBackend.text : Qt.alpha(ThemeBackend.subtext0, 0.45))
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(12)
                                font.weight: parent.today ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        // ── middle: media, notifications ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.s(14)

            Card {
                Layout.preferredHeight: root.s(170)
                readonly property var player: MprisController.activePlayer

                RowLayout {
                    anchors.fill: parent
                    spacing: root.s(16)

                    Rectangle {
                        Layout.preferredWidth: root.s(142)
                        Layout.preferredHeight: root.s(142)
                        radius: ThemeBackend.rad(root.s(12))
                        color: ThemeBackend.surface1
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: MprisController.currentArtUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !MprisController.currentArtUrl
                            text: "󰝚"
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(48)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.s(4)
                        Text {
                            Layout.fillWidth: true
                            text: MprisController.hasActivePlayer ? (MprisController.trackTitle || "—") : I18n.t("dashboard.nothing_playing", "Nothing playing")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(18)
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: MprisController.trackArtist || ""
                            color: ThemeBackend.subtext1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            spacing: root.s(10)
                            opacity: MprisController.hasActivePlayer ? 1 : 0.4
                            RoundButton { glyph: "󰒮"; onClicked: { let p = MprisController.activePlayer; if (p && p.canGoPrevious) p.previous(); } }
                            RoundButton { glyph: MprisController.isPlaying ? "󰏤" : "󰐊"; primary: true; onClicked: { let p = MprisController.activePlayer; if (p && p.canTogglePlaying) p.togglePlaying(); } }
                            RoundButton { glyph: "󰒭"; onClicked: { let p = MprisController.activePlayer; if (p && p.canGoNext) p.next(); } }
                        }
                    }
                }
            }

            Card {
                Layout.fillHeight: true
                title: I18n.t("dashboard.notifications", "Notifications")
                icon: "󰂚"

                ListView {
                    id: notifList
                    anchors.fill: parent
                    clip: true
                    spacing: root.s(6)
                    model: NotificationManager.globalNotificationHistory
                    delegate: Rectangle {
                        required property string appName
                        required property string summary
                        required property string body
                        width: notifList.width
                        height: nCol.implicitHeight + root.s(16)
                        radius: ThemeBackend.rad(root.s(10))
                        color: Qt.alpha(ThemeBackend.surface1, 0.55)
                        ColumnLayout {
                            id: nCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: root.s(10)
                            spacing: root.s(2)
                            Text {
                                Layout.fillWidth: true
                                text: "<b>" + (parent.parent.summary || parent.parent.appName) + "</b>  <font color='" + ThemeBackend.subtext0 + "'>" + parent.parent.appName + "</font>"
                                textFormat: Text.StyledText
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(12)
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: parent.parent.body
                                color: ThemeBackend.subtext1
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: notifList.count === 0
                        text: I18n.t("dashboard.no_notifications", "All caught up")
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                    }
                }
            }
        }

        // ── right: pomodoro, todo ──
        ColumnLayout {
            Layout.preferredWidth: root.s(360)
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: root.s(14)

            Card {
                Layout.preferredHeight: root.s(220)
                title: Pomodoro.phaseName + (Pomodoro.done > 0 ? "  ·  " + Pomodoro.done + " " + I18n.t("pomodoro.done", "done") : "")
                icon: "󰔟"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.s(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Pomodoro.label
                        color: Pomodoro.running ? ThemeBackend.text : ThemeBackend.subtext1
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(52)
                        font.weight: Font.Bold
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(6)
                        radius: ThemeBackend.rad(height / 2)
                        color: Qt.alpha(ThemeBackend.surface1, 0.7)
                        Rectangle {
                            width: parent.width * Pomodoro.progress
                            height: parent.height
                            radius: parent.radius
                            color: Pomodoro.phase === "focus" ? ThemeBackend.mauve : ThemeBackend.green
                            Behavior on width { NumberAnimation { duration: (400) * ThemeBackend.animScale } }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: root.s(10)
                        RoundButton { glyph: "󰑐"; onClicked: Pomodoro.reset() }
                        RoundButton { glyph: Pomodoro.running ? "󰏤" : "󰐊"; primary: true; onClicked: Pomodoro.toggle() }
                        RoundButton { glyph: "󰒭"; onClicked: Pomodoro.skip() }
                    }
                }
            }

            Card {
                Layout.fillHeight: true
                title: I18n.t("dashboard.todo", "Todo") + (Todo.openCount > 0 ? "  ·  " + Todo.openCount : "")
                icon: "󰄲"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.s(8)

                    SearchBox {
                        id: todoInput
                        Layout.fillWidth: true
                        icon: "󰐕"
                        placeholderText: I18n.t("dashboard.todo_add", "Add a task and press Enter")
                        onAccepted: { Todo.add(text); clear(); }
                    }

                    ListView {
                        id: todoList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: root.s(4)
                        model: Todo.items
                        delegate: Rectangle {
                            id: todoRow
                            required property var modelData
                            width: todoList.width
                            height: root.s(36)
                            radius: ThemeBackend.rad(root.s(8))
                            color: rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : "transparent"
                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Todo.toggle(todoRow.modelData.id)
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.s(8)
                                anchors.rightMargin: root.s(6)
                                spacing: root.s(10)
                                Text {
                                    text: todoRow.modelData.done ? "󰄲" : "󰄱"
                                    color: todoRow.modelData.done ? ThemeBackend.green : ThemeBackend.subtext0
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(17)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: todoRow.modelData.text
                                    color: todoRow.modelData.done ? ThemeBackend.subtext0 : ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(13)
                                    font.strikeout: todoRow.modelData.done
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: rowMa.containsMouse
                                    text: "󰅖"
                                    color: ThemeBackend.red
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(14)
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -root.s(6)
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Todo.remove(todoRow.modelData.id)
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: todoList.count === 0
                            text: I18n.t("dashboard.todo_empty", "Nothing to do")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: Todo.items.length > Todo.openCount
                        text: I18n.t("dashboard.todo_clear", "Clear done")
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        font.underline: clearMa.containsMouse
                        MouseArea { id: clearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Todo.clearDone() }
                    }
                }
            }
        }
    }
}
