//@ pragma AppId monolith-appimages
//@ pragma Env MONOLITH_STANDALONE=1
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."
import "guide"

// The AppImages window (monolith appimages, Mod+I, "AppImages" in the launcher): drop an
// AppImage on it and it's set up like an installed app. The same page as Settings -> AppImages,
// in a window of its own; it quits when it's closed.
ShellRoot {
    id: app

    readonly property real uiScale: {
        let general = Config.getSetting("general", {});
        let v = general ? Number(general.uiScale) : NaN;
        return (isNaN(v) || v <= 0) ? 1.0 : v;
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    // a second `monolith appimages` brings this one forward instead of opening another
    IpcHandler {
        target: "appimages"
        function ping(): bool { return true; }
    }

    FloatingWindow {
        id: win
        title: "AppImages"
        color: ThemeBackend.base
        implicitWidth: Math.round(820 * app.uiScale)
        implicitHeight: Math.round(640 * app.uiScale)
        minimumSize: Qt.size(Math.round(480 * app.uiScale), Math.round(420 * app.uiScale))
        visible: true

        // what the Settings page expects of the window it's in
        readonly property int currentTab: 0
        readonly property int currentSubTab: -1
        function s(v) { return Math.round(v * app.uiScale); }

        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: win.s(14)
                spacing: win.s(4)

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: win.s(8)
                    spacing: win.s(12)

                    Text {
                        text: "󰏗"
                        color: ThemeBackend.mauve
                        font.family: ThemeBackend.iconFont || ThemeBackend.fontFamily
                        font.pixelSize: win.s(30)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: win.s(2)
                        Text {
                            text: "AppImages"
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: win.s(22)
                            font.weight: ThemeBackend.weightBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Drop an AppImage and it's ready to go: in your AppImages folder, in the launcher and dock, with its own icon"
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: win.s(12)
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AppImagesTab {
                        rootObj: win
                        tabIndex: 0
                    }
                }
            }
        }
    }
}
