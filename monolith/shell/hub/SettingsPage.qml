import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Settings, inside the hub: sections down the left, the open one on the right (each section is
// its own file in settings/). Everything saves as you change it: the shell's own settings in
// ~/.config/monolith/next.json, displays/input/cursor/screenshots in niri's config.
Page {
    id: page
    pageId: "settings"
    implicitHeight: 680
    readonly property string section: HubState.settingsSection

    readonly property var sections: [
        ["general", "General", "person", "General"],
        ["appearance", "Appearance", "palette", "Appearance"],
        ["wallpaper", "Wallpaper", "wallpaper", "Wallpaper"],
        ["colours", "App colours", "format_paint", "Colours"],
        ["fastfetch", "Fastfetch", "terminal", "Fastfetch"],
        ["status", "Island", "toolbar", "Status"],
        ["dock", "Dock", "dock_to_bottom", "Dock"],
        ["desktop", "Desktop", "widgets", "Desktop"],
        ["windows", "Windows", "select_window", "Windows"],
        ["search", "Search", "search", "Search"],
        ["notifications", "Notifications", "notifications", "Notifications"],
        ["osd", "On-screen display", "featured_video", "Osd"],
        ["display", "Displays", "monitor", "Display"],
        ["nightlight", "Night light", "nightlight", "Night"],
        ["input", "Keyboard & mouse", "keyboard", "Input"],
        ["devices", "Mic & camera", "mic", "Devices"],
        ["idle", "Lock & idle", "lock_clock", "Idle"],
        ["capture", "Screenshots", "screenshot_region", "Capture"],
        ["software", "Software", "apps", "Software"],
        ["wellbeing", "Wellbeing", "self_improvement", "Wellbeing"],
        ["about", "About", "info", "About"]
    ]
    readonly property string file: section === "welcome" ? "Welcome" : ((sections.find(s => s[0] === section) || sections[0])[3])

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ── the sections ──
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            radius: Theme.corner(56, 6)
            color: Theme.container
            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: list
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: page.sections
                        Pressable {
                            required property var modelData
                            readonly property bool cur: page.file === modelData[3]
                            width: parent.width
                            height: 36
                            color: cur ? Theme.selected : "transparent"
                            onClicked: HubState.settingsSection = modelData[0]
                            Row {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Icon { name: modelData[2]; size: 19; filled: parent.parent.cur; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: modelData[1]; strong: parent.parent.cur; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }
        }

        // ── the open section ──
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: loader.item ? loader.item.implicitHeight : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: loader
                width: flick.width
                // loaded while the page is open; the section reloads its data each time
                active: page.current && HubState.open
                source: "settings/" + page.file + ".qml"
                onSourceChanged: flick.contentY = 0
            }
        }
    }
}
