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

    // categories down the left; each has tabs along the top (its sub-pages). A tab is
    // [id, title, file in settings/]. HubState.settingsSection is a tab id.
    readonly property var categories: [
        { id: "general", title: "General", icon: "person", tabs: [["general", "You & location", "General"], ["about", "About", "About"]] },
        { id: "theme", title: "Theme", icon: "palette", tabs: [["style", "Style", "Styles"], ["appearance", "Colours & icons", "Appearance"], ["wallpaper", "Wallpaper", "Wallpaper"], ["colours", "App colours", "Colours"], ["fastfetch", "Fastfetch", "Fastfetch"]] },
        { id: "bar", title: "Bar", icon: "toolbar", tabs: [["bar", "Layout & modules", "BarLayout"], ["status", "Behaviour", "Status"]] },
        { id: "menus", title: "Menus & launcher", icon: "apps", tabs: [["menus", "Where menus open", "Menus"], ["search", "Launcher", "Search"]] },
        { id: "dock", title: "Dock", icon: "dock_to_bottom", tabs: [["dock", "Dock", "Dock"]] },
        { id: "desktop", title: "Desktop", icon: "widgets", tabs: [["desktop", "Widgets", "Desktop"], ["quickaccess", "Quick access", "QuickAccess"]] },
        { id: "windows", title: "Windows", icon: "select_window", tabs: [["windows", "Gaps, borders, animations", "Windows"]] },
        { id: "display", title: "Display", icon: "monitor", tabs: [["display", "Monitors", "Display"], ["nightlight", "Night light", "Night"]] },
        { id: "alerts", title: "Notifications", icon: "notifications", tabs: [["notifications", "Notifications", "Notifications"], ["osd", "On-screen display", "Osd"]] },
        { id: "devices", title: "Devices", icon: "keyboard", tabs: [["input", "Keyboard & mouse", "Input"], ["devices", "Mic & camera", "Devices"]] },
        { id: "lock", title: "Lock & idle", icon: "lock_clock", tabs: [["idle", "Lock & idle", "Idle"]] },
        { id: "capture", title: "Screenshots", icon: "screenshot_region", tabs: [["capture", "Screenshots", "Capture"]] },
        { id: "software", title: "Software", icon: "deployed_code", tabs: [["software", "Startup, AppImages, cleanup", "Software"]] },
        { id: "wellbeing", title: "Wellbeing", icon: "self_improvement", tabs: [["wellbeing", "Wellbeing", "Wellbeing"]] }
    ]
    // the open category and tab (an unknown id shows the first)
    readonly property var category: categories.find(c => c.tabs.some(t => t[0] === section)) || categories[0]
    readonly property var tab: category.tabs.find(t => t[0] === section) || category.tabs[0]
    readonly property string file: section === "welcome" ? "Welcome" : tab[2]

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
                        model: page.categories
                        Pressable {
                            required property var modelData
                            readonly property bool cur: page.category.id === modelData.id && page.section !== "welcome"
                            width: parent.width
                            height: 40
                            color: cur ? Theme.selected : "transparent"
                            onClicked: HubState.settingsSection = modelData.tabs[0][0]
                            Row {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Icon { name: modelData.icon; size: 20; filled: parent.parent.cur; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: modelData.title; strong: parent.parent.cur; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }
        }

        // ── the open category: its tabs along the top, the open tab below ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
        Row {
            id: subTabs
            Layout.fillWidth: true
            visible: page.section !== "welcome"
            spacing: 6
            Label { text: page.category.title; strong: true; font.pixelSize: Theme.sizeTitle + 2; anchors.verticalCenter: parent.verticalCenter; rightPadding: 10 }
            Repeater {
                model: page.category.tabs.length > 1 ? page.category.tabs : []
                Pressable {
                    required property var modelData
                    readonly property bool cur: page.tab[0] === modelData[0]
                    height: 34
                    width: tl.implicitWidth + 28
                    radius: height / 2
                    color: cur ? Theme.accentContainer : Theme.containerHigh
                    onClicked: HubState.settingsSection = modelData[0]
                    Label { id: tl; anchors.centerIn: parent; text: parent.modelData[1]; strong: parent.cur; color: parent.cur ? Theme.onAccentContainer : Theme.text; font.pixelSize: Theme.sizeSmall + 1 }
                }
            }
        }
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
}
