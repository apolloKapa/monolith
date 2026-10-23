import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Quick actions: the panel that slides out when you push the mouse against a screen
// edge (drawing, system usage, timer, notes, calculator). Stored as `quickactions` in settings.
GuideTab {
    id: qaTab

    property var cfg: Config.getSetting("quickactions", {}) || {}
    Connections {
        target: Config
        function onSettingsLoaded() { qaTab.cfg = Config.getSetting("quickactions", {}) || {}; }
    }

    function get(key, fallback) { return qaTab.cfg[key] !== undefined ? qaTab.cfg[key] : fallback; }
    function set(key, value) {
        let cur = JSON.parse(JSON.stringify(Config.getSetting("quickactions", {}) || {}));
        cur[key] = value;
        Config.setSetting("quickactions", cur);
        qaTab.cfg = cur;
    }
    // toggle one entry of a list setting (the tools, the edges)
    function toggleIn(key, all, item) {
        let list = (get(key, all) || all).slice();
        const i = list.indexOf(item);
        if (i === -1) list.push(item); else list.splice(i, 1);
        set(key, list);
    }

    readonly property bool on: get("enabled", true)
    readonly property var actionsAll: ["draw", "system", "timer", "notes", "calculator"]
    readonly property var edgesAll: ["top", "bottom", "left", "right"]

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string glyph: ""
        property bool checked: false
        signal toggled()
        implicitWidth: chipRow.implicitWidth + rootObj.s(24)
        implicitHeight: rootObj.s(32)
        radius: ThemeBackend.square ? 0 : height / 2
        color: checked ? Qt.alpha(ThemeBackend.mauve, ThemeBackend.material ? 1.0 : 0.85) : (chipMa.containsMouse ? Qt.alpha(ThemeBackend.text, 0.08) : "transparent")
        border.width: checked ? 0 : 1
        border.color: Qt.alpha(ThemeBackend.text, 0.18)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: rootObj.s(6)
            Text { visible: chip.glyph !== ""; text: chip.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: rootObj.s(14); color: chip.checked ? ThemeBackend.onPrimary : ThemeBackend.text; anchors.verticalCenter: parent.verticalCenter }
            Text { text: chip.label; font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(12); color: chip.checked ? ThemeBackend.onPrimary : ThemeBackend.text; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.toggled() }
    }

    component Slider: Draggable {
        id: sl
        property string key: ""
        property real fallback: 0
        property string unit: "ms"
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Layout.rightMargin: rootObj.s(8)
        implicitWidth: rootObj.s(220)
        implicitHeight: rootObj.s(18)
        showValueBubble: true
        valueFormatter: function(v) { return unit === "x" ? v.toFixed(1) + "×" : (v >= 1000 ? (v / 1000).toFixed(1) + " s" : Math.round(v) + " ms") }
        value: Number(qaTab.get(key, fallback))
        backgroundColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        handleColor: ThemeBackend.text
        onMoved: function(v) { sl.value = v; }
        onDragFinished: qaTab.set(key, unit === "x" ? Math.round(sl.value * 10) / 10 : Math.round(sl.value))
    }

    component Switcher: Toggle {
        property string key: ""
        property bool fallback: false
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        checked: qaTab.get(key, fallback)
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(v) { qaTab.set(key, v); }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_enabled"
                    icon: "󰀻"
                    title: I18n.t("guide.qa.enabled.title", "Quick actions panel")
                    description: I18n.t("guide.qa.enabled.desc", "Push the mouse against a screen edge to slide out a panel with drawing, system usage, a timer, notes and a calculator")
                    searchKeywords: "quick actions side menu panel edge floating enable disable"
                    Switcher { key: "enabled"; fallback: true }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_tools"
                    icon: "󰏘"
                    title: I18n.t("guide.qa.tools.title", "Tools")
                    description: I18n.t("guide.qa.tools.desc", "Which tools the panel has. Click to turn one on or off")
                    hiddenByConfig: !qaTab.on
                    searchKeywords: "tools draw system timer notes calculator features"
                    Flow {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.maximumWidth: rootObj.s(430)
                        spacing: rootObj.s(6)
                        Repeater {
                            model: [
                                { id: "draw", label: I18n.t("quickactions.tabs.draw"), glyph: "󰽉" },
                                { id: "system", label: I18n.t("quickactions.tabs.system"), glyph: "󰍛" },
                                { id: "timer", label: I18n.t("quickactions.tabs.timer"), glyph: "󰔛" },
                                { id: "notes", label: I18n.t("quickactions.tabs.notes"), glyph: "󰈙" },
                                { id: "calculator", label: I18n.t("quickactions.tabs.calculator"), glyph: "󰃬" }
                            ]
                            Chip {
                                required property var modelData
                                label: modelData.label
                                glyph: modelData.glyph
                                checked: (qaTab.get("actions", qaTab.actionsAll) || []).indexOf(modelData.id) !== -1
                                onToggled: qaTab.toggleIn("actions", qaTab.actionsAll, modelData.id)
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_edges"
                    icon: "󰹑"
                    title: I18n.t("guide.qa.edges.title", "Screen edges")
                    description: I18n.t("guide.qa.edges.desc", "Which edges open it when you push the mouse against them")
                    hiddenByConfig: !qaTab.on
                    searchKeywords: "edges top bottom left right trigger"
                    Row {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(6)
                        Repeater {
                            model: [
                                { id: "top", label: I18n.t("guide.launcher.position.top", "Top") },
                                { id: "bottom", label: I18n.t("guide.launcher.position.bottom", "Bottom") },
                                { id: "left", label: I18n.t("guide.launcher.position.left", "Left") },
                                { id: "right", label: I18n.t("guide.launcher.position.right", "Right") }
                            ]
                            Chip {
                                required property var modelData
                                label: modelData.label
                                checked: (qaTab.get("edges", qaTab.edgesAll) || []).indexOf(modelData.id) !== -1
                                onToggled: qaTab.toggleIn("edges", qaTab.edgesAll, modelData.id)
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_edge_size"
                    icon: "󰡏"
                    title: I18n.t("guide.qa.edge_size.title", "Edge sensitivity")
                    description: I18n.t("guide.qa.edge_size.desc", "How thick the strip along the edge is that opens it. Thicker is easier to hit, thinner gets in the way less")
                    hiddenByConfig: !qaTab.on
                    Slider { key: "edgeSize"; fallback: 3; from: 1; to: 12; stepSize: 1; unit: "px"; valueFormatter: function(v) { return Math.round(v) + " px" } }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_show_delay"
                    icon: "󰔛"
                    title: I18n.t("guide.qa.show_delay.title", "Wait before opening")
                    description: I18n.t("guide.qa.show_delay.desc", "How long the mouse has to stay at the edge before it opens")
                    hiddenByConfig: !qaTab.on
                    Slider { key: "showDelay"; fallback: 300; from: 0; to: 1500; stepSize: 50 }
                }
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_hide_delay"
                    icon: "󰅖"
                    title: I18n.t("guide.qa.hide_delay.title", "Wait before hiding")
                    description: I18n.t("guide.qa.hide_delay.desc", "How long it stays after the mouse leaves it")
                    hiddenByConfig: !qaTab.on
                    Slider { key: "hideDelay"; fallback: 800; from: 100; to: 5000; stepSize: 100 }
                }
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_grace"
                    icon: "󰥔"
                    title: I18n.t("guide.qa.grace.title", "Stay time when opened on purpose")
                    description: I18n.t("guide.qa.grace.desc", "When something opens it for you (the bar's system monitor, a notes widget), how long it waits before hiding")
                    hiddenByConfig: !qaTab.on
                    Slider { key: "graceDelay"; fallback: 3000; from: 500; to: 10000; stepSize: 250 }
                }
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_speed"
                    icon: "󰓅"
                    title: I18n.t("guide.qa.speed.title", "Animation speed")
                    description: I18n.t("guide.qa.speed.desc", "How fast it slides in and out. 1× is normal")
                    hiddenByConfig: !qaTab.on
                    Slider { key: "speed"; fallback: 1.0; from: 0.5; to: 3.0; stepSize: 0.1; unit: "x" }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_fullscreen"
                    icon: "󰊓"
                    title: I18n.t("guide.qa.fullscreen.title", "Over fullscreen apps")
                    description: I18n.t("guide.qa.fullscreen.desc", "Let it open while a game or video is fullscreen")
                    hiddenByConfig: !qaTab.on
                    searchKeywords: "fullscreen game video"
                    Switcher { key: "showFullscreen"; fallback: false }
                }
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_maximized"
                    icon: "󰖯"
                    title: I18n.t("guide.qa.maximized.title", "Over maximized windows")
                    description: I18n.t("guide.qa.maximized.desc", "Let it open while the focused window is maximized")
                    hiddenByConfig: !qaTab.on
                    searchKeywords: "maximized window"
                    Switcher { key: "showMaximized"; fallback: true }
                }
                SettingsRow {
                    rootObj: qaTab.rootObj
                    settingId: "qa_desktop_only"
                    icon: "󰍹"
                    title: I18n.t("guide.qa.desktop_only.title", "Only on the desktop")
                    description: I18n.t("guide.qa.desktop_only.desc", "Only open when no window has focus, so it never gets in the way of an app")
                    hiddenByConfig: !qaTab.on
                    searchKeywords: "desktop only empty no windows"
                    Switcher { key: "desktopOnly"; fallback: false }
                }
            }
        }
    }
}
