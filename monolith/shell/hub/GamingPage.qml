import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Gaming: game mode (performance profile, do not disturb, the screen kept awake), the
// performance overlay, live CPU and GPU readings with the last two minutes as graphs, and a
// way out of a game that stopped answering.
Page {
    id: page
    pageId: "gaming"
    implicitHeight: col.implicitHeight

    // a reading: big number, what it is, a detail line, and its graph
    component Meter: Card {
        id: m
        property string value: ""
        property string detail: ""
        property var hist: []
        property color tint: Theme.accent
        Layout.fillWidth: true
        Layout.preferredHeight: 170
        Text { text: m.value; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 8; font.weight: Font.Bold }
        Label { y: 40; text: m.detail; muted: true; font.pixelSize: Theme.sizeSmall; width: parent.width }
        Spark { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 56; values: m.hist; color: m.tint }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ── game mode: a big switch with what it does ──
        Pressable {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: Theme.corner(92, 10)
            color: GameMode.active ? Theme.accentContainer : Theme.containerHigh
            onClicked: GameMode.toggle()
            Rectangle {
                id: pad
                x: 14; width: 64; height: 64
                anchors.verticalCenter: parent.verticalCenter
                radius: GameMode.active ? 20 : 32
                color: GameMode.active ? Theme.accent : Theme.control
                Behavior on radius { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                Icon { anchors.centerIn: parent; name: "sports_esports"; size: 34; filled: GameMode.active; color: GameMode.active ? Theme.onAccent : Theme.text }
            }
            Column {
                anchors.left: pad.right; anchors.leftMargin: 16
                anchors.right: gmToggle.left; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Label { text: GameMode.active ? "Game mode is on" : "Game mode"; strong: true; font.pixelSize: Theme.sizeTitle + 2; color: GameMode.active ? Theme.onAccentContainer : Theme.text }
                Label { width: parent.width; wrapMode: Text.Wrap; text: "Performance power profile, do not disturb, the screen stays awake" + (GameMode.hideIsland ? ", the island tucked away" : "") + ". Off puts it all back."; muted: true; font.pixelSize: Theme.sizeSmall }
            }
            Toggle { id: gmToggle; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; checked: GameMode.active; onToggled: GameMode.toggle() }
        }

        // ── the readings ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Meter {
                icon: "memory"; title: "CPU"
                value: Math.round(Stats.cpu * 100) + "%"
                detail: Math.round(Stats.temp) + "°C"
                hist: Stats.cpuHist
            }
            Meter {
                icon: "videogame_asset"; title: "GPU"
                value: Math.round(Stats.gpu * 100) + "%"
                detail: Math.round(Stats.gpuTemp) + "°C   ·   " + Math.round(Stats.gpuClock) + " MHz   ·   " + Math.round(Stats.gpuWatts) + " W"
                hist: Stats.gpuHist
                tint: Theme.m("tertiary", Theme.accent)
            }
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                icon: "data_usage"; title: "Memory"
                Column {
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: [["RAM", Stats.mem, Math.round(Stats.mem * 100) + "%"],
                                ["VRAM", Stats.vramTotal > 0 ? Stats.vramUsed / Stats.vramTotal : 0, Stats.vramTotal > 0 ? (Stats.vramUsed / 1073741824).toFixed(1) + " / " + (Stats.vramTotal / 1073741824).toFixed(0) + " GB" : "—"]]
                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: 5
                            Row {
                                width: parent.width
                                Label { width: parent.width / 2; text: modelData[0]; strong: true; font.pixelSize: Theme.sizeSmall + 1 }
                                Label { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall }
                            }
                            Rectangle {
                                width: parent.width; height: 10; radius: 5; color: Theme.ringTrack
                                Rectangle { height: parent.height; radius: 5; width: Math.max(10, parent.width * modelData[1]); color: Theme.accent; Behavior on width { NumberAnimation { duration: 400 } } }
                            }
                        }
                    }
                }
            }
        }

        // ── options and tools ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SettingRow {
                icon: "monitoring"; title: "Performance overlay"; desc: "CPU and GPU in a corner, over everything"
                Toggle { checked: GameMode.overlay; onToggled: on => Store.set("gaming.overlay", on) }
            }
            SettingRow {
                icon: "visibility_off"; title: "Tuck the island away"; desc: "While game mode is on"
                Toggle { checked: GameMode.hideIsland; onToggled: on => Store.set("gaming.hideIsland", on) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Button {
                Layout.fillWidth: true
                icon: "dangerous"; text: kill.armed ? "Sure? Ends " + (Niri.focusedAppId || "it") : "End the focused program"
                id: kill
                property bool armed: false
                onClicked: { if (armed) { GameMode.killFocused(); armed = false; } else { armed = true; disarm.restart(); } }
                Timer { id: disarm; interval: 4000; onTriggered: kill.armed = false }
            }
            Button { Layout.fillWidth: true; icon: "tune"; text: "GPU settings (LACT)"; onClicked: { HubState.close(); Quickshell.execDetached(["lact", "gui"]); } }
            Button { Layout.fillWidth: true; icon: "stadia_controller"; text: "Steam"; onClicked: { HubState.close(); Quickshell.execDetached(["steam"]); } }
        }
    }
}
