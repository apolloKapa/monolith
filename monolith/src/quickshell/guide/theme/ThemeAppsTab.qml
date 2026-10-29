import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Apps: let other apps follow Monolith's colours (scripts/app_theming.py).
// Switching one on adds a marked block or one setting to that app's config; switching it off
// puts the config back exactly as it was.
GuideTab {
    id: appsTab

    readonly property var apps: [
        { id: "gtk", icon: "󰏘", title: "GTK apps", desc: "GTK 3 and GTK 4 / libadwaita apps (Files, Settings, most GNOME apps), and the system light/dark setting follows the theme. Takes effect when they restart" },
        { id: "qt", icon: "󰟓", title: "Qt and KDE apps", desc: "Qt apps that use qt5ct / qt6ct (VLC, OBS...) and KDE / Kirigami apps that don't (WiVRn, Dolphin...), through a Monolith KDE colour scheme. Takes effect when they restart" },
        { id: "flatpak", icon: "󰏖", title: "Flatpak apps", desc: "Lets Flatpak apps (PortProton, Bottles...) read the GTK and KDE colours above, and drops per-app overrides that pin them to another theme. Switch GTK and Qt on too. Takes effect when they restart" },
        { id: "foot", icon: "󰆍", title: "foot", desc: "The foot terminal. New windows use the colours" },
        { id: "alacritty", icon: "󰆍", title: "Alacritty", desc: "The Alacritty terminal" },
        { id: "btop", icon: "󰍛", title: "btop", desc: "The btop system monitor" },
        { id: "rofi", icon: "󰀻", title: "rofi", desc: "rofi menus (the keybind launcher)" }
    ]

    property var status: ({})
    property string error: ""
    property string busy: ""

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    function setApp(id, on) {
        appsTab.error = "";
        appsTab.busy = id;
        toggleProc.command = ["python3", Caching.monolithDir + "/scripts/app_theming.py", on ? "enable" : "disable", id];
        toggleProc.running = true;
    }

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    Process {
        id: statusProc
        command: ["python3", Caching.monolithDir + "/scripts/app_theming.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { appsTab.status = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: toggleProc
        stderr: StdioCollector { id: toggleErr }
        onExited: (code) => {
            if (code !== 0) appsTab.error = (toggleErr.text || "").trim().split("\n").pop();
            appsTab.busy = "";
            appsTab.refresh();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: col.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    Layout.margins: rootObj.s(12)
                    wrapMode: Text.WordWrap
                    text: "Give other apps your Monolith colours, from your wallpaper or colour preset, and keep them in step whenever the theme changes. "
                        + "Monolith only adds a marked block (or one setting) to the app's config; switching it off puts the file back exactly as it was. "
                        + "kitty, cava and fastfetch follow the theme too, unless you switch that off below."
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    Layout.rightMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(12)
                    visible: appsTab.error !== ""
                    wrapMode: Text.WordWrap
                    text: "󰀦  " + appsTab.error
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: appsTab.rootObj
                    settingId: "theme_terminal_colors"
                    icon: "󰆍"
                    configKey: "theme.terminalColors"
                    defaultValue: true
                    title: "kitty, cava and fastfetch"
                    description: "Recolour them with the theme. Switch off if another shell on this PC themes them (the installer does this when it finds Serpantinum)"
                    searchKeywords: "kitty cava fastfetch terminal colours colors theme serpantinum"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: Matugen.terminalColors
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            let t = JSON.parse(JSON.stringify(Config.getSetting("theme", {}) || {}));
                            t.terminalColors = val;
                            Config.setSetting("theme", t);
                        }
                    }
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                Repeater {
                    model: appsTab.apps

                    SettingsRow {
                        id: row
                        required property var modelData
                        readonly property var st: appsTab.status[modelData.id] || {}
                        Layout.fillWidth: true
                        rootObj: appsTab.rootObj
                        settingId: "app_theming_" + modelData.id
                        icon: modelData.icon
                        title: modelData.title
                        description: modelData.desc
                        searchKeywords: "app theming colours colors gtk qt kde kirigami flatpak dark light terminal follow theme matugen " + modelData.id
                        hiddenByConfig: row.st.available === false
                        unavailableReason: modelData.title + " isn't installed"

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: row.st.enabled === true
                            enabled: row.st.available !== false && appsTab.busy === ""
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(val) { appsTab.setApp(row.modelData.id, val); }
                        }
                    }
                }
            }
        }
    }
}
