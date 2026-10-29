import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Software -> Pacman / AUR / Flatpak (CleanupPacmanTab.qml & co. set `section`):
// remove software and find what installing and removing it leaves behind. The page only counts
// (scripts/packages.py status); each button opens a terminal that lists what it found and asks
// before removing anything (packages.py clean <check>).
GuideTab {
    id: cleanupTab

    // "pacman", "aur" or "flatpak": which checks this page shows
    property string section: "pacman"
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

    function counted(c, one, many) {
        if (!c) return "";
        if (c.count === 0) return "None";
        return c.count + " " + (c.count === 1 ? one : many) + ", " + human(c.size);
    }

    readonly property var allChecks: [
        { id: "explicit", section: "pacman", icon: "󰏓", title: "Installed packages", need: "pacman",
          desc: "Packages from the Arch repos you installed yourself, biggest first. Pick any to remove. System packages and what Monolith needs aren't listed",
          found: counted(st.explicit, "package", "packages") },
        { id: "orphans", section: "pacman", icon: "󰏗", title: "Orphan packages", need: "pacman",
          desc: "Packages installed as dependencies of something you've since removed. Nothing needs them now",
          found: counted(st.orphans, "package", "packages") },
        { id: "cache", section: "pacman", icon: "󰃢", title: "Old package downloads", need: "pacman",
          desc: st.paccache ? "Old versions in pacman's cache. Keeps the newest 2 of each, to roll back with"
                            : "pacman's download cache. Install pacman-contrib to also drop old versions of installed packages",
          found: st.cache ? (st.cache.size === 0 ? "Empty" : human(st.cache.size)) : "" },
        { id: "aur", section: "aur", icon: "󰏓", title: "AUR packages", need: "pacman",
          desc: "Packages from the AUR you installed yourself, biggest first. Pick any to remove",
          found: counted(st.aur, "package", "packages") },
        { id: "aurcache", section: "aur", icon: "󰃢", title: "AUR build folders", need: "pacman",
          desc: "What yay / paru downloaded and built. Safe to empty: packages are downloaded again when they update",
          found: st.aurcache ? (st.aurcache.size === 0 ? "Empty" : human(st.aurcache.size)) : "" },
        { id: "flatapps", section: "flatpak", icon: "󰏖", title: "Flatpak apps", need: "flatpakInstalled",
          desc: "Your installed Flatpak apps, biggest first. Pick any to remove, with or without their settings and files",
          found: counted(st.flatapps, "app", "apps") },
        { id: "flatpak", section: "flatpak", icon: "󰏗", title: "Unused Flatpak runtimes", need: "flatpakInstalled",
          desc: "Runtimes and extensions that no installed Flatpak app uses any more. Flatpak lists them and asks",
          found: "" },
        { id: "flatdata", section: "flatpak", icon: "󰉖", title: "Leftover Flatpak app data", need: "flatpakInstalled",
          desc: "Settings and files in ~/.var/app from Flatpak apps that aren't installed any more",
          found: counted(st.flatdata, "folder", "folders") }
    ]
    readonly property var checks: allChecks.filter(c => c.section === section)

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
                    text: (cleanupTab.section === "flatpak" ? "Remove Flatpak apps and what they leave behind. "
                           : cleanupTab.section === "aur" ? "Remove AUR packages and what building them leaves behind. "
                           : "Remove packages and what installing them leaves behind. ")
                        + "Each check opens a terminal that lists what it found and asks before removing anything"
                        + (cleanupTab.section === "flatpak" ? "." : "; removing packages asks for your password.")
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: cleanupTab.rootObj
                    settingId: "cleanup_refresh_" + cleanupTab.section
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
