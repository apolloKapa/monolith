import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Software -> Clean up: what's left over from installing and removing software
// (orphan packages, unused Flatpak runtimes, leftover Flatpak app data, old downloads).
// The page only counts (scripts/packages.py status); each button opens a terminal that lists
// what it found and asks before removing anything (packages.py clean <check>).
GuideTab {
    id: cleanupTab

    property var st: ({})
    property bool loading: false

    function script() { return Caching.monolithDir + "/scripts/packages.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        loading = true;
        statusProc.running = false;
        statusProc.running = true;
    }

    function human(n) {
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
        return i === 0 ? Math.round(n) + " B" : n.toFixed(1) + " " + units[i];
    }

    // the launcher's terminal (Settings -> Launcher -> Terminal), "kitty -e" by default
    function openTerminal(check) {
        const ls = (Config.rawSettings && Config.rawSettings.launcher) ? Config.rawSettings.launcher : {};
        const term = (ls.terminalCommand || "kitty -e").trim().split(/\s+/);
        Quickshell.execDetached(term.concat(["python3", script(), "clean", check]));
    }

    readonly property var checks: [
        { id: "explicit", icon: "󰏓", title: "Installed packages", need: "pacman",
          desc: "The packages you installed yourself, biggest first. Pick any to remove. System packages and what Monolith needs aren't listed",
          found: st.explicit ? st.explicit.count + " package" + (st.explicit.count !== 1 ? "s" : "") + ", " + human(st.explicit.size) : "" },
        { id: "orphans", icon: "󰏗", title: "Orphan packages", need: "pacman",
          desc: "Packages installed as dependencies of something you've since removed. Nothing needs them now",
          found: st.orphans ? (st.orphans.count === 0 ? "None" : st.orphans.count + " package" + (st.orphans.count !== 1 ? "s" : "") + ", " + human(st.orphans.size)) : "" },
        { id: "flatpak", icon: "󰏖", title: "Unused Flatpak runtimes", need: "flatpakInstalled",
          desc: "Runtimes and extensions that no installed Flatpak app uses any more. Flatpak lists them and asks",
          found: "" },
        { id: "flatdata", icon: "󰉖", title: "Leftover Flatpak app data", need: "flatpakInstalled",
          desc: "Settings and files in ~/.var/app from Flatpak apps that aren't installed any more",
          found: st.flatdata ? (st.flatdata.count === 0 ? "None" : st.flatdata.count + " folder" + (st.flatdata.count !== 1 ? "s" : "") + ", " + human(st.flatdata.size)) : "" },
        { id: "cache", icon: "󰃢", title: "Old package downloads", need: "pacman",
          desc: st.paccache ? "Old versions in pacman's cache (keeps the newest 2 of each) and the AUR helper's build folders"
                            : "pacman's cache and the AUR helper's build folders. Install pacman-contrib to also drop old versions",
          found: st.cache ? (st.cache.size === 0 ? "Empty" : human(st.cache.size)) : "" }
    ]

    Process {
        id: statusProc
        command: ["python3", cleanupTab.script(), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { cleanupTab.st = JSON.parse(this.text); } catch (e) {}
                cleanupTab.loading = false;
            }
        }
    }

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

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
                    text: "Find what installing and removing software leaves behind. Each check opens a terminal that lists what it found and asks before removing anything; removing packages asks for your password."
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: cleanupTab.rootObj
                    settingId: "cleanup_refresh"
                    icon: "󰑐"
                    title: "Checks"
                    description: cleanupTab.loading ? "Looking..." : "Press Refresh after cleaning to update the counts"
                    searchKeywords: "clean up cleanup installed uninstall remove orphan packages flatpak unused runtimes cache leftover data pacman aur"

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Refresh"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: cleanupTab.refresh()
                    }
                }

                Repeater {
                    model: cleanupTab.checks

                    SettingsRow {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        rootObj: cleanupTab.rootObj
                        settingId: "cleanup_" + modelData.id
                        icon: modelData.icon
                        title: modelData.title + (modelData.found ? "  ·  " + modelData.found : "")
                        description: modelData.desc
                        searchKeywords: "clean up cleanup remove " + modelData.title.toLowerCase()
                        hiddenByConfig: cleanupTab.st[modelData.need] === false
                        unavailableReason: modelData.need === "pacman" ? "Needs pacman (Arch-based systems)" : "Flatpak isn't installed"

                        ClickButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitHeight: rootObj.s(32)
                            horizontalPadding: rootObj.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: "Check"
                            textFontSize: rootObj.s(11)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.onPrimary
                            onClicked: cleanupTab.openTerminal(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
