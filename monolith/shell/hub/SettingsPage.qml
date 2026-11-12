import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../ui"

// Settings, inside the hub: sections down the left, the open one on the right (each section is
// its own file in settings/). Everything saves as you change it: the shell's own settings in
// ~/.config/monolith/next.json, displays/input/cursor/screenshots in niri's config.
Page {
    id: page
    pageId: "settings"
    implicitHeight: 800
    height: Math.min(implicitHeight, parent && parent.height > 0 ? parent.height : implicitHeight)
    readonly property string section: HubState.settingsSection

    // sections down the left; one with several pages unfolds them underneath it (a section with
    // a single page just opens). A page is [id, title, file in settings/]; HubState.settingsSection
    // is a page id. `gap` puts a separator above a section.
    readonly property var categories: [
        { id: "general", desc: "Who you are, the weather, updates", title: "General", icon: "person", tabs: [["general", "You & weather", "General"], ["profiles", "Profiles & backup", "Profiles"], ["about", "Updates & about", "About"]] },
        { id: "theme", desc: "How everything looks: style, colours, wallpaper, motion", title: "Appearance", icon: "palette", tabs: [["style", "Style & colours", "Styles"], ["appearance", "Dark mode, font & icons", "Appearance"], ["wallpaper", "Wallpaper", "Wallpaper"], ["playlist", "Wallpaper playlist", "WallPlaylist"], ["effects", "Effects & animations", "Effects"], ["colours", "Other apps' colours", "Colours"], ["fastfetch", "Terminal greeting", "Fastfetch"]] },
        { id: "bar", desc: "What the bar shows and where it sits", title: "Bar", icon: "toolbar", tabs: [["bar", "Layout & modules", "BarLayout"], ["status", "Auto-hide", "Status"], ["barscreens", "Bar & dock per screen", "BarScreens"]] },
        { id: "menus", desc: "The launcher and where menus open", title: "Menus & launcher", icon: "apps", tabs: [["search", "Launcher", "Search"], ["menus", "Where menus open", "Menus"]] },
        { id: "dock", desc: "Your pinned and running apps", title: "Dock", icon: "dock_to_bottom", tabs: [["dock", "Dock", "Dock"]] },
        { id: "desktop", desc: "Widgets and the screen edges", title: "Desktop", icon: "widgets", tabs: [["desktop", "Widgets", "Desktop"], ["quickaccess", "Quick access (screen edges)", "QuickAccess"]] },
        { id: "windows", desc: "Gaps, borders and how windows move", title: "Windows", icon: "select_window", tabs: [["windows", "Windows", "Windows"]] },
        { id: "display", desc: "Monitors, scaling and night light", title: "Displays", icon: "monitor", gap: true, tabs: [["display", "Monitors", "Display"], ["nightlight", "Night light", "Night"]] },
        { id: "devices", desc: "Keyboard, mouse, microphone and camera", title: "Devices", icon: "keyboard", tabs: [["input", "Keyboard & mouse", "Input"], ["devices", "Microphone & camera", "Devices"]] },
        { id: "alerts", desc: "Notifications, sounds and pop-ups", title: "Notifications", icon: "notifications", tabs: [["notifications", "Notifications", "Notifications"], ["sounds", "Sounds", "SoundSettings"], ["osd", "On-screen pop-up", "Osd"]] },
        { id: "lock", desc: "Locking, sleeping and what happens when you're away", title: "Lock & idle", icon: "lock_clock", gap: true, tabs: [["idle", "Lock & idle", "Idle"]] },
        { id: "capture", desc: "Screenshots and recordings", title: "Screenshots", icon: "screenshot_region", tabs: [["capture", "Screenshots", "Capture"]] },
        { id: "sysmon", desc: "Live graphs, the busiest apps, and warnings when it runs hot or full", title: "System monitor", icon: "monitoring", tabs: [["sysmon", "System monitor", "SysMon"]] },
        { id: "software", desc: "Apps and updates for this PC", title: "Software", icon: "deployed_code", tabs: [["software", "Software", "Software"], ["apps", "Apps", "Apps"]] },
        { id: "wellbeing", desc: "Screen time and breaks", title: "Wellbeing", icon: "self_improvement", tabs: [["wellbeing", "Wellbeing", "Wellbeing"]] }
    ]
    // ── search: every row of every page (scripts/settings_index.py reads their titles and
    // descriptions), plus the pages themselves. A result opens its page, scrolls to the row and
    // makes it glow for a moment.
    property string query: ""
    property var index: []
    Process {
        id: indexProc
        command: ["python3", Qt.resolvedUrl("../scripts/settings_index.py").toString().replace("file://", "")]
        stdout: StdioCollector { onStreamFinished: { try { page.index = JSON.parse(text); } catch (e) {} } }
    }
    onCurrentChanged: if (current && !index.length && !indexProc.running) indexProc.running = true
    // a page's file -> [its tab id, category title, tab title]
    function placeOf(file) {
        for (const c of categories) for (const t of c.tabs) if (t[2] === file) return [t[0], c.title, t[1], c.icon];
        return null;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        const words = q.split(/\s+/);
        const hit = text => words.every(w => text.indexOf(w) !== -1);
        const out = [];
        // pages first
        for (const c of categories) for (const t of c.tabs) {
            const name = (c.title + " " + t[1]).toLowerCase();
            if (hit(name + " " + (c.desc || "").toLowerCase())) out.push({ tab: t[0], title: t[1], where: c.title, desc: c.desc || "", icon: c.icon, row: "", score: t[1].toLowerCase().startsWith(q) ? 0 : 1 });
        }
        for (const e of index) {
            const pl = placeOf(e.file);
            if (!pl) continue;
            const title = e.title.toLowerCase();
            if (!hit(title + " " + e.desc.toLowerCase() + " " + pl[2].toLowerCase())) continue;
            out.push({ tab: pl[0], title: e.title, where: pl[1] + " › " + pl[2], desc: e.desc, icon: e.icon || pl[3], row: e.title,
                       score: title.startsWith(q) ? 0 : (hit(title) ? 1 : 2) });
        }
        out.sort((a, b) => a.score - b.score);
        return out.slice(0, 60);
    }
    // the row to go to once its page has loaded
    property string findRow: ""
    function go(res) {
        findRow = res.row;
        if (HubState.settingsSection === res.tab) Qt.callLater(page.seek);
        HubState.settingsSection = res.tab;
    }
    function rowsIn(item, out) {
        if (!item) return out;
        if (item.title !== undefined && item.allKeys !== undefined) out.push(item);
        for (const c of item.children) rowsIn(c, out);
        return out;
    }
    function seek() {
        if (findRow === "" || !loader.item) return;
        const row = rowsIn(loader.item, []).find(r => r.title === findRow && r.visible);
        findRow = "";
        if (!row) return;
        const y = row.mapToItem(loader.item, 0, 0).y;
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, y - 60));
        row.glow();
    }

    // the open category and tab (an unknown id shows the first)
    readonly property var category: categories.find(c => c.tabs.some(t => t[0] === section)) || categories[0]
    readonly property var tab: category.tabs.find(t => t[0] === section) || category.tabs[0]
    readonly property string file: section === "welcome" ? "Welcome" : tab[2]

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ── the sections ──
        Rectangle {
            Layout.preferredWidth: 264
            Layout.fillHeight: true
            radius: Theme.corner(56, 6)
            color: Theme.container
            border.width: Theme.outlineW
            border.color: Theme.outlineColor

            // you, on top: a click opens General
            Pressable {
                id: me
                x: 8; y: 8
                width: parent.width - 16
                height: 64
                radius: Theme.corner(height, 2)
                color: hovered ? Theme.containerHigh : "transparent"
                onClicked: HubState.settingsSection = "general"
                Avatar { id: face; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 42; scale: me.hovered ? 1.06 : 1; Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } } }
                Column {
                    anchors.left: face.right; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label { width: parent.width; text: Quickshell.env("USER") || "You"; strong: true; font.pixelSize: Theme.sizeBody + 1 }
                    Label { width: parent.width; text: "Monolith " + Updates.version; muted: true; font.pixelSize: Theme.sizeSmall }
                }
            }
            // search all settings
            Field {
                id: findField
                x: 10; y: 78
                width: parent.width - 20; height: 40
                placeholder: "Search settings"
                onTextChanged: page.query = text
                onAccepted: v => { if (page.results.length) page.go(page.results[0]); }
                Keys.onEscapePressed: { text = ""; }
                Icon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: page.query !== "" ? "close" : "search"; size: 18; color: Theme.subtext
                    MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: page.query !== ""; cursorShape: Qt.PointingHandCursor; onClicked: findField.text = "" } }
            }
            Rectangle { x: 16; y: 126; width: parent.width - 32; height: 1; color: Theme.hairline }

            // the results, in place of the sections while there's a search
            Flickable {
                SmoothWheel {}
                visible: page.query.trim() !== ""
                x: 8; y: 133
                width: parent.width - 16
                height: parent.height - y - 8
                contentHeight: resCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: resCol
                    width: parent.width
                    spacing: 2
                    Label { visible: page.results.length === 0; width: parent.width; topPadding: 16; horizontalAlignment: Text.AlignHCenter; text: page.index.length ? "Nothing found" : "Looking…"; muted: true }
                    Repeater {
                        model: page.results
                        Pressable {
                            id: res
                            required property var modelData
                            width: resCol.width
                            height: rc.implicitHeight + 16
                            color: hovered ? Theme.containerHigh : "transparent"
                            onClicked: page.go(modelData)
                            Icon { id: ri; x: 10; y: 10; name: res.modelData.icon || "tune"; size: 19; color: Theme.subtext }
                            Column {
                                id: rc
                                anchors.left: ri.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 8
                                y: 8
                                spacing: 1
                                Label { width: parent.width; text: res.modelData.title; strong: true; elide: Text.ElideRight; font.pixelSize: Theme.sizeSmall + 1 }
                                Label { width: parent.width; text: res.modelData.where; muted: true; elide: Text.ElideRight; font.pixelSize: Theme.sizeTiny + 1 }
                            }
                        }
                    }
                }
            }

            Flickable {
                SmoothWheel {}
                visible: page.query.trim() === ""
                x: 8; y: 133
                width: parent.width - 16
                height: parent.height - y - 8
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
                                id: head
                                width: parent.width
                                height: 44
                                color: sec.cur && !sec.many ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                                onClicked: HubState.settingsSection = sec.modelData.tabs[0][0]
                                // its icon on a little tile that lights up when it's the open one
                                Rectangle {
                                    id: tile
                                    x: 7; anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30
                                    radius: Theme.corner(height, -2)
                                    color: sec.cur ? Theme.accent : (head.hovered ? Theme.control : "transparent")
                                    scale: head.pressed ? 0.9 : (head.hovered && !sec.cur ? 1.08 : 1)
                                    Behavior on color { ColorAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
                                    Icon { anchors.centerIn: parent; name: sec.modelData.icon; size: 19; filled: sec.cur; color: sec.cur ? Theme.onAccent : Theme.text; Behavior on color { ColorAnimation { duration: Theme.ms(220) } } }
                                }
                                Label { x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 76; elide: Text.ElideRight; text: sec.modelData.title; strong: sec.cur }
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
                                Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                                Rectangle { x: 21; y: 2; width: 2; height: pages.implicitHeight - 4; radius: 1; color: Theme.hairline }
                                // the open page's highlight and its mark on the line: one of each per
                                // section, gliding to the page you pick (the mark stretches on its way:
                                // its head gets there first, its tail catches up)
                                Item {
                                    id: glide
                                    readonly property int at: Math.max(0, sec.modelData.tabs.findIndex(t => t[0] === page.tab[0]))
                                    readonly property real slot: 2 + at * 36
                                    property real head: slot
                                    property real tail: slot
                                    Behavior on head { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
                                    Behavior on tail { NumberAnimation { duration: Theme.ms(520); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                                    visible: sec.cur
                                    Rectangle {
                                        x: 30; y: glide.tail
                                        width: pages.width; height: 34
                                        radius: Theme.corner(height)
                                        color: Theme.selected
                                    }
                                    Rectangle {
                                        x: 20
                                        y: Math.min(glide.head, glide.tail) + 8
                                        width: 4; radius: 2
                                        height: 18 + Math.abs(glide.head - glide.tail)
                                        color: Theme.accent
                                    }
                                }
                                Column {
                                    id: pages
                                    x: 30; y: 2
                                    width: parent.width - 30
                                    spacing: 2
                                    Repeater {
                                        model: sec.many ? sec.modelData.tabs : []
                                        Pressable {
                                            id: sub
                                            required property var modelData
                                            readonly property bool on: page.tab[0] === modelData[0] && sec.cur
                                            width: pages.width
                                            height: 34
                                            color: hovered && !on ? Qt.alpha(Theme.containerHigh, 0.7) : "transparent"
                                            onClicked: HubState.settingsSection = modelData[0]
                                            Label {
                                                x: sub.hovered && !sub.on ? 15 : 12
                                                Behavior on x { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                                                anchors.verticalCenter: parent.verticalCenter; width: parent.width - 22; elide: Text.ElideRight
                                                text: sub.modelData[1]; strong: sub.on; color: sub.on ? Theme.text : Theme.subtext; font.pixelSize: Theme.sizeSmall + 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── the open page: what it is on top, its settings below ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
        Item {
            id: banner
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            visible: page.section !== "welcome"
            // the icon pops and the words slide in each time another page opens
            property real pop: 1
            NumberAnimation { id: popAnim; target: banner; property: "pop"; from: 0; to: 1; duration: Theme.ms(420); easing.type: Easing.OutCubic }
            Rectangle {
                id: mark
                x: 4; anchors.verticalCenter: parent.verticalCenter
                width: 52; height: 52
                radius: Theme.corner(height, 4)
                color: Theme.accent
                scale: 0.7 + 0.3 * banner.pop
                rotation: -18 * (1 - banner.pop)
                Icon { anchors.centerIn: parent; name: page.category.icon; size: 28; filled: true; color: Theme.onAccent }
            }
            Column {
                anchors.left: mark.right; anchors.leftMargin: 16 + 14 * (1 - banner.pop)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: banner.pop
                spacing: 2
                Row {
                    spacing: 8
                    Label { visible: page.category.tabs.length > 1 && page.tab[1] !== page.category.title; text: page.category.title; muted: true; font.pixelSize: Theme.sizeHeadline - 4; anchors.baseline: big.baseline }
                    Icon { visible: page.category.tabs.length > 1 && page.tab[1] !== page.category.title; name: "chevron_right"; size: 20; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    Label { id: big; text: page.category.tabs.length > 1 ? page.tab[1] : page.category.title; strong: true; font.pixelSize: Theme.sizeHeadline - 4 }
                }
                Label { width: parent.width; text: page.category.desc || ""; muted: true }
            }
        }
        // on Hyprland: these pages change niri's settings (its config file), which apply when you
        // log into niri; Hyprland takes its own from hyprland.conf
        Rectangle {
            readonly property var niriPages: ({ Display: "Monitors", Input: "Keyboard and mouse", Windows: "Gaps, borders and window rules", Appearance: "The cursor theme and size", Capture: "Where screenshots are saved" })
            visible: Niri.hyprland && niriPages[page.file] !== undefined
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? hyNote.implicitHeight + 20 : 0
            radius: Theme.corner(56, 6)
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: 1; border.color: Qt.alpha(Theme.accent, 0.35)
            Icon { id: hyIcon; x: 12; y: 10; name: "info"; size: 20; color: Theme.accent }
            Label {
                id: hyNote
                anchors.left: hyIcon.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 12; y: 10
                wrapMode: Text.WordWrap; font.pixelSize: Theme.sizeSmall
                text: (parent.niriPages[page.file] || "") + ": these settings are niri's, so they apply when you log into niri. On Hyprland, set them in ~/.config/hypr/hyprland.conf."
            }
        }
        Flickable {
            SmoothWheel {}
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: loader.item ? loader.item.implicitHeight + 8 : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: loader
                width: flick.width
                // loaded while the page is open; the section reloads its data each time
                active: page.current && HubState.open
                source: "settings/" + page.file + ".qml"
                onSourceChanged: { flick.contentY = 0; pageIn.restart(); popAnim.restart(); }
                // a search result: its row, once the page is laid out
                onLoaded: if (page.findRow !== "") seekLater.restart()
                Timer { id: seekLater; interval: 80; onTriggered: page.seek() }
                // the page fades in while its rows come up one after another (ui/SettingRow)
                NumberAnimation { id: pageIn; target: loader; property: "opacity"; from: 0; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
            }
            // more below: the page fades out at the bottom edge
            Rectangle {
                parent: flick
                anchors.bottom: parent.bottom
                width: parent.width; height: 28
                visible: opacity > 0.01
                opacity: Theme.see >= 1 && flick.contentHeight - flick.contentY - flick.height > 6 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Theme.frame, 0) }
                    GradientStop { position: 1; color: Theme.frame }
                }
            }
        }
        }
    }
}
