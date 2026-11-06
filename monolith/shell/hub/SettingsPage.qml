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

    // sections down the left; one with several pages unfolds them underneath it (a section with
    // a single page just opens). A page is [id, title, file in settings/]; HubState.settingsSection
    // is a page id. `gap` puts a separator above a section.
    readonly property var categories: [
        { id: "general", title: "General", icon: "person", tabs: [["general", "You & weather", "General"], ["about", "Updates & about", "About"]] },
        { id: "theme", title: "Appearance", icon: "palette", tabs: [["style", "Style & colours", "Styles"], ["appearance", "Dark mode, font & icons", "Appearance"], ["wallpaper", "Wallpaper", "Wallpaper"], ["effects", "Effects & animations", "Effects"], ["colours", "Other apps' colours", "Colours"], ["fastfetch", "Terminal greeting", "Fastfetch"]] },
        { id: "bar", title: "Bar", icon: "toolbar", tabs: [["bar", "Layout & modules", "BarLayout"], ["status", "Auto-hide", "Status"], ["barscreens", "Bar & dock per screen", "BarScreens"]] },
        { id: "menus", title: "Menus & launcher", icon: "apps", tabs: [["search", "Launcher", "Search"], ["menus", "Where menus open", "Menus"]] },
        { id: "dock", title: "Dock", icon: "dock_to_bottom", tabs: [["dock", "Dock", "Dock"]] },
        { id: "desktop", title: "Desktop", icon: "widgets", tabs: [["desktop", "Widgets", "Desktop"], ["quickaccess", "Quick access (screen edges)", "QuickAccess"]] },
        { id: "windows", title: "Windows", icon: "select_window", tabs: [["windows", "Windows", "Windows"]] },
        { id: "display", title: "Displays", icon: "monitor", gap: true, tabs: [["display", "Monitors", "Display"], ["nightlight", "Night light", "Night"]] },
        { id: "devices", title: "Devices", icon: "keyboard", tabs: [["input", "Keyboard & mouse", "Input"], ["devices", "Microphone & camera", "Devices"]] },
        { id: "alerts", title: "Notifications", icon: "notifications", tabs: [["notifications", "Notifications", "Notifications"], ["sounds", "Sounds", "SoundSettings"], ["osd", "On-screen pop-up", "Osd"]] },
        { id: "lock", title: "Lock & idle", icon: "lock_clock", gap: true, tabs: [["idle", "Lock & idle", "Idle"]] },
        { id: "capture", title: "Screenshots", icon: "screenshot_region", tabs: [["capture", "Screenshots", "Capture"]] },
        { id: "software", title: "Software", icon: "deployed_code", tabs: [["software", "Software", "Software"]] },
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
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            radius: Theme.corner(56, 6)
            color: Theme.container
            Flickable {
                SmoothWheel {}
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
                        Column {
                            id: sec
                            required property var modelData
                            readonly property bool cur: page.category.id === modelData.id && page.section !== "welcome"
                            readonly property bool many: modelData.tabs.length > 1
                            width: list.width
                            spacing: 2
                            // a thin line between groups
                            Item {
                                visible: !!sec.modelData.gap
                                width: parent.width; height: 11
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 10; width: parent.width - 20; height: 1; color: Theme.hairline }
                            }
                            Pressable {
                                width: parent.width
                                height: 40
                                color: sec.cur && !sec.many ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                                onClicked: HubState.settingsSection = sec.modelData.tabs[0][0]
                                Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: sec.modelData.icon; size: 20; filled: sec.cur; color: sec.cur ? Theme.accent : Theme.text }
                                Label { x: 42; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; elide: Text.ElideRight; text: sec.modelData.title; strong: sec.cur }
                                // it has pages: an arrow that turns as it unfolds
                                Icon {
                                    visible: sec.many
                                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    name: "expand_more"; size: 18; color: Theme.subtext
                                    rotation: sec.cur ? 0 : -90
                                    Behavior on rotation { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
                                }
                            }
                            // its pages, unfolding under it, indented along a line
                            Item {
                                visible: sec.many
                                width: parent.width
                                height: sec.cur ? pages.implicitHeight + 4 : 0
                                clip: true
                                Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
                                Rectangle { x: 21; y: 2; width: 2; height: pages.implicitHeight - 4; radius: 1; color: Theme.hairline }
                                Column {
                                    id: pages
                                    x: 30; y: 2
                                    width: parent.width - 30
                                    spacing: 2
                                    Repeater {
                                        model: sec.many ? sec.modelData.tabs : []
                                        Pressable {
                                            required property var modelData
                                            readonly property bool on: page.tab[0] === modelData[0] && sec.cur
                                            width: pages.width
                                            height: 32
                                            color: on ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                                            onClicked: HubState.settingsSection = modelData[0]
                                            Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20; elide: Text.ElideRight; text: parent.modelData[1]; strong: parent.on; color: parent.on ? Theme.text : Theme.subtext; font.pixelSize: Theme.sizeSmall + 1 }
                                        }
                                    }
                                }
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
        // the open page's name (and its section's, when it has several pages)
        Column {
            Layout.fillWidth: true
            visible: page.section !== "welcome"
            spacing: 0
            Label { visible: page.category.tabs.length > 1; text: page.category.title; muted: true; font.pixelSize: Theme.sizeSmall }
            Label { text: page.category.tabs.length > 1 ? page.tab[1] : page.category.title; strong: true; font.pixelSize: Theme.sizeTitle + 2 }
        }
        Flickable {
            SmoothWheel {}
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
                onSourceChanged: { flick.contentY = 0; pageIn.restart(); }
                // a page comes in like the menus do: fading up from a little lower
                transform: Translate { id: lift }
                ParallelAnimation {
                    id: pageIn
                    NumberAnimation { target: loader; property: "opacity"; from: 0; to: 1; duration: Theme.shortMs; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lift; property: "y"; from: 10; to: 0; duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
                }
            }
        }
        }
    }
}
