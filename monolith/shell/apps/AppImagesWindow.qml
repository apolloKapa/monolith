import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../core"
import "../ui"

// The AppImages window (`monolith appimages`, Mod+I, "AppImages" in the launcher): drop an
// AppImage on it and it's set up like an installed app (moved into your AppImages folder, made
// runnable, in the launcher, dock and menus with its own name and icon). Under the drop zone:
// what's being set up, and every AppImage you have, to run, take out of your apps, or delete.
FloatingWindow {
    id: win
    title: "AppImages"
    visible: AppImages.opened
    implicitWidth: 760
    implicitHeight: 680
    minimumSize: Qt.size(520, 460)
    color: Theme.m("surface", Theme.frame)
    onVisibleChanged: { if (visible) AppImages.hold(); else { AppImages.release(); AppImages.opened = false; AppImages.clearDone(); } }

    property string confirmDelete: ""

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: AppImages.opened = false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ── header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Bubble { size: 44; icon: "deployed_code" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "AppImages"; strong: true; font.pixelSize: Theme.sizeTitle + 4 }
                    Label { Layout.fillWidth: true; text: "Drop one here and it's ready to go: in " + AppImages.folder.replace(Quickshell.env("HOME"), "~") + ", in the launcher and the dock, with its own icon"; muted: true; wrapMode: Text.Wrap; font.pixelSize: Theme.sizeSmall }
                }
            }

            // ── the drop zone ──
            Rectangle {
                id: zone
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                radius: Theme.corner(170, 14)
                color: drop.containsDrag ? Qt.alpha(Theme.accent, 0.14) : Theme.container
                border.width: 2
                border.color: drop.containsDrag ? Theme.accent : Qt.alpha(Theme.text, 0.18)
                Behavior on color { ColorAnimation { duration: 140 } }
                // a dashed outline
                Canvas {
                    anchors.fill: parent
                    visible: !drop.containsDrag
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.setLineDash([8, 7]);
                        c.lineWidth = 2;
                        c.strokeStyle = Qt.alpha(Theme.text, 0.35);
                        c.beginPath();
                        c.roundedRect(1, 1, width - 2, height - 2, zone.radius, zone.radius);
                        c.stroke();
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: drop.containsDrag ? "download" : "upload_file"
                        size: 46; filled: drop.containsDrag
                        color: drop.containsDrag ? Theme.accent : Theme.subtext
                        scale: drop.containsDrag ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: drop.containsDrag ? "Let go to set it up" : "Drop AppImages here"; strong: true; font.pixelSize: Theme.sizeTitle }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "from your file manager, the browser's downloads, anywhere"; muted: true; font.pixelSize: Theme.sizeSmall }
                }
                DropArea {
                    id: drop
                    anchors.fill: parent
                    onEntered: drag => drag.accept(Qt.CopyAction)
                    onDropped: d => {
                        const files = (d.urls || []).map(u => decodeURIComponent(u.toString())).filter(u => u.startsWith("file://"));
                        if (files.length) AppImages.add(files, keepBox.checked);
                        d.accept(Qt.CopyAction);
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Toggle { id: keepBox; checked: Store.get("software.appimagesKeep", false) === true; onToggled: on => Store.set("software.appimagesKeep", on) }
                Label { Layout.fillWidth: true; text: "Leave dropped files where they are (don't move them into the folder)"; font.pixelSize: Theme.sizeSmall; wrapMode: Text.Wrap }
                Field { Layout.preferredWidth: 220; placeholder: "or type a path, then Enter"; onAccepted: v => { if (v.trim() !== "") { AppImages.add([v.trim().replace(/^~/, Quickshell.env("HOME"))], keepBox.checked); text = ""; } } }
            }

            // ── what's being set up ──
            Repeater {
                model: AppImages.jobs
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    radius: Theme.corner(50, 8)
                    color: modelData.state === "failed" ? Qt.alpha(Theme.danger, 0.14) : (modelData.state === "done" ? Qt.alpha(Theme.accent, 0.12) : Theme.containerHigh)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 12
                        Icon {
                            name: modelData.state === "working" ? "progress_activity" : (modelData.state === "done" ? "check_circle" : "error")
                            filled: modelData.state !== "working"
                            size: 22
                            color: modelData.state === "failed" ? Theme.danger : Theme.accent
                            RotationAnimation on rotation { running: modelData.state === "working"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        }
                        Label { Layout.fillWidth: true; strong: true; elide: Text.ElideMiddle
                            text: modelData.state === "working" ? "Setting up " + modelData.name + "…" : (modelData.state === "done" ? modelData.name + " is in your apps" : modelData.name + ": " + modelData.error) }
                        Button { visible: modelData.state === "done"; text: "Open"; onClicked: Quickshell.execDetached([modelData.file]) }
                    }
                }
            }

            // ── every AppImage ──
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Your AppImages"; muted: true; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Label { text: AppImages.items.length + (AppImages.items.length === 1 ? " app" : " apps"); muted: true; font.pixelSize: Theme.sizeSmall }
                Button { text: "Open folder"; icon: "folder_open"; onClicked: Quickshell.execDetached(["xdg-open", AppImages.folder]) }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: list.implicitHeight
                clip: true
                SmoothWheel {}
                Column {
                    id: list
                    width: parent.width
                    spacing: 6
                    Label { visible: AppImages.items.length === 0; text: "None yet. Drop one above."; muted: true; topPadding: 10 }
                    Repeater {
                        model: AppImages.items
                        Rectangle {
                            id: row
                            required property var modelData
                            width: list.width
                            height: 62
                            radius: Theme.corner(62, 10)
                            color: rowHover.hovered ? Theme.containerHigh : Theme.container
                            HoverHandler { id: rowHover }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                spacing: 12
                                IconImage {
                                    implicitSize: 38
                                    source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", "application-x-executable")
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { Layout.fillWidth: true; text: row.modelData.name; strong: true; elide: Text.ElideRight }
                                    Label {
                                        Layout.fillWidth: true; muted: true; font.pixelSize: Theme.sizeSmall; elide: Text.ElideRight
                                        text: (row.modelData.size / 1048576).toFixed(0) + " MB" + (row.modelData.added ? "" : "  ·  not in your apps yet")
                                            + (row.modelData.inFolder ? "" : "  ·  " + row.modelData.file.replace(Quickshell.env("HOME"), "~"))
                                    }
                                }
                                Button { text: "Run"; icon: "play_arrow"; onClicked: Quickshell.execDetached([row.modelData.file]) }
                                Button {
                                    visible: !row.modelData.added
                                    text: "Add to apps"; primary: true
                                    onClicked: AppImages.add([row.modelData.file], true)
                                }
                                Button {
                                    visible: row.modelData.added
                                    text: "Remove"
                                    onClicked: AppImages.remove(row.modelData.file, false)
                                }
                                Button {
                                    text: win.confirmDelete === row.modelData.file ? "Delete the file?" : "Delete"
                                    icon: "delete"
                                    onClicked: {
                                        if (win.confirmDelete === row.modelData.file) { AppImages.remove(row.modelData.file, true); win.confirmDelete = ""; }
                                        else { win.confirmDelete = row.modelData.file; disarm.restart(); }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Timer { id: disarm; interval: 4000; onTriggered: win.confirmDelete = "" }
}
