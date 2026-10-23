import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../launcher/SearchProviders.js" as SearchProviders

GuideTab {
    id: launcherTabRoot

    property var defaultLauncherSettings: ({
        "position": "top",
        "width": 600,
        "itemCount": 6,
        "terminalCommand": "kitty -e",
        "smartRanking": true,
        "searchProvider": "google",
        "favorites": [],
        "showRail": true,
        "gridView": false,
        "gridColumns": 5,
        "favColumns": 4,
        "appOrder": [],
        "showDescriptions": true,
        "webSearch": true
    })

    property var launcherSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["launcher"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("launcher", launcherTabRoot.defaultLauncherSettings);
        }
        return launcherTabRoot.defaultLauncherSettings;
    }

    property string currentPosition: launcherSettings && launcherSettings.position !== undefined ? launcherSettings.position : "top"
    property int currentWidth: launcherSettings && launcherSettings.width !== undefined ? launcherSettings.width : 600
    property int currentItemCount: launcherSettings && launcherSettings.itemCount !== undefined ? launcherSettings.itemCount : 6
    property string currentTerminalCommand: launcherSettings && launcherSettings.terminalCommand !== undefined ? launcherSettings.terminalCommand : "kitty -e"
    property bool currentSmartRanking: launcherSettings && launcherSettings.smartRanking !== undefined ? launcherSettings.smartRanking : true

    property bool currentShowRail: !(launcherSettings && launcherSettings.showRail === false)
    property bool currentGridView: !!(launcherSettings && launcherSettings.gridView === true)
    property int currentGridColumns: (launcherSettings && Number(launcherSettings.gridColumns) >= 3) ? Number(launcherSettings.gridColumns) : 5
    property int currentFavColumns: (launcherSettings && Number(launcherSettings.favColumns) >= 2) ? Number(launcherSettings.favColumns) : 4
    property bool currentShowDescriptions: !(launcherSettings && launcherSettings.showDescriptions === false)
    property bool currentWebSearch: !(launcherSettings && launcherSettings.webSearch === false)

    property string currentSearchProvider: launcherSettings && launcherSettings.searchProvider !== undefined ? launcherSettings.searchProvider : SearchProviders.DEFAULT_ID

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("launcher", launcherTabRoot.defaultLauncherSettings)
            : launcherTabRoot.defaultLauncherSettings;
        launcherTabRoot.launcherSettings = s;
        launcherTabRoot.currentPosition = s.position !== undefined ? s.position : "top";
        launcherTabRoot.currentWidth = s.width !== undefined ? s.width : 600;
        launcherTabRoot.currentItemCount = s.itemCount !== undefined ? s.itemCount : 6;
        launcherTabRoot.currentTerminalCommand = s.terminalCommand !== undefined ? s.terminalCommand : "kitty -e";
        launcherTabRoot.currentSmartRanking = s.smartRanking !== undefined ? s.smartRanking : true;
        launcherTabRoot.currentSearchProvider = s.searchProvider !== undefined ? s.searchProvider : SearchProviders.DEFAULT_ID;
        launcherTabRoot.currentShowRail = s.showRail !== false;
        launcherTabRoot.currentGridView = s.gridView === true;
        launcherTabRoot.currentGridColumns = Number(s.gridColumns) >= 3 ? Number(s.gridColumns) : 5;
        launcherTabRoot.currentShowDescriptions = s.showDescriptions !== false;
        launcherTabRoot.currentFavColumns = Number(s.favColumns) >= 2 ? Number(s.favColumns) : 4;
        launcherTabRoot.currentWebSearch = s.webSearch !== false;
    }

    function updateLauncherSetting(key, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("launcher", defaultLauncherSettings) || defaultLauncherSettings));
        current[key] = value;
        Config.setSetting("launcher", current);
        launcherTabRoot.launcherSettings = current;
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        property var pendingCallback: null
        onTriggered: {
            if (pendingCallback) {
                pendingCallback();
                pendingCallback = null;
            }
        }
    }

    function triggerDebounced(cb) {
        debounceTimer.pendingCallback = cb;
        debounceTimer.restart();
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
        } else {
            if (posDropdown.isOpen) posDropdown.closePopup();
            if (searchDropdown.isOpen) searchDropdown.closePopup();
        }
    }

    Component.onCompleted: {
        syncSettings();
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            launcherTabRoot.syncSettings();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            // a small launcher drawn with the layout settings below
            Rectangle {
                id: launcherPreviewCard
                Layout.fillWidth: true
                Layout.preferredHeight: lp.height + rootObj.s(24)
                radius: ThemeBackend.square ? 0 : ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)

                Rectangle {
                    id: lp
                    anchors.centerIn: parent
                    readonly property bool rail: launcherTabRoot.currentShowRail
                    readonly property real u: rootObj.s(1)
                    width: Math.min(parent.width - rootObj.s(24), rootObj.s(rail ? 520 : 360))
                    height: rootObj.s(200)
                    radius: ThemeBackend.square ? 0 : rootObj.s(16)
                    color: ThemeBackend.base
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.text, 0.1)

                    readonly property color chip: ThemeBackend.material ? ThemeBackend.surfaceContainerHigh : Qt.lighter(ThemeBackend.surface0, 1.2)
                    readonly property color ink: Qt.alpha(ThemeBackend.text, 0.35)

                    // search field (+ globe button)
                    Rectangle {
                        x: 10 * lp.u; y: 10 * lp.u
                        width: lp.width - 20 * lp.u - (launcherTabRoot.currentWebSearch ? 26 * lp.u : 0)
                        height: 20 * lp.u
                        radius: height / 2
                        color: lp.chip
                        Rectangle { x: 10 * lp.u; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.3; height: 4 * lp.u; radius: 2 * lp.u; color: lp.ink }
                    }
                    Rectangle {
                        visible: launcherTabRoot.currentWebSearch
                        x: lp.width - 30 * lp.u; y: 10 * lp.u
                        width: 20 * lp.u; height: 20 * lp.u; radius: 10 * lp.u
                        color: lp.chip
                        Text { anchors.centerIn: parent; text: "󰖟"; font.family: ThemeBackend.iconFont; font.pixelSize: 11 * lp.u; color: ThemeBackend.text }
                    }

                    // left: tabs + favourites grid
                    Item {
                        id: lpPane
                        visible: lp.rail
                        x: 10 * lp.u; y: 38 * lp.u
                        width: lp.rail ? (lp.width - 30 * lp.u) * 0.42 : 0
                        height: lp.height - 48 * lp.u
                        Rectangle {
                            width: parent.width; height: 14 * lp.u; radius: 7 * lp.u
                            color: lp.chip
                            Rectangle { width: parent.width / 3; height: parent.height; radius: parent.radius; color: ThemeBackend.mauve; opacity: 0.8 }
                        }
                        Grid {
                            y: 22 * lp.u
                            columns: launcherTabRoot.currentFavColumns
                            readonly property real cell: parent.width / columns
                            Repeater {
                                model: launcherTabRoot.currentFavColumns * 2
                                Item {
                                    width: parent.cell; height: 34 * lp.u
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 2 * lp.u; width: 16 * lp.u; height: 16 * lp.u; radius: 5 * lp.u; color: Qt.alpha(ThemeBackend.mauve, 0.35 + 0.1 * (index % 3)) }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 22 * lp.u; width: Math.min(parent.width - 4 * lp.u, 18 * lp.u); height: 3 * lp.u; radius: 1.5 * lp.u; color: lp.ink }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: lp.rail
                        x: lpPane.x + lpPane.width + 5 * lp.u; y: 38 * lp.u
                        width: 1; height: lpPane.height
                        color: Qt.alpha(ThemeBackend.text, 0.15)
                    }

                    // right: the list, or a grid
                    Item {
                        id: lpList
                        x: lp.rail ? lpPane.x + lpPane.width + 11 * lp.u : 10 * lp.u
                        y: lp.rail ? 38 * lp.u : 38 * lp.u + 20 * lp.u
                        width: lp.width - x - 10 * lp.u
                        height: lp.height - y - 10 * lp.u
                        clip: true

                        // tabs on top when there's no left pane
                        Rectangle {
                            visible: !lp.rail
                            y: -20 * lp.u
                            width: parent.width; height: 14 * lp.u; radius: 7 * lp.u
                            color: lp.chip
                            Rectangle { width: parent.width / 3; height: parent.height; radius: parent.radius; color: ThemeBackend.mauve; opacity: 0.8 }
                        }

                        Column {
                            visible: !launcherTabRoot.currentGridView
                            width: parent.width
                            spacing: 4 * lp.u
                            Repeater {
                                model: 5
                                Rectangle {
                                    width: parent.width
                                    height: (launcherTabRoot.currentShowDescriptions ? 22 : 16) * lp.u
                                    radius: height / 2
                                    color: index === 0 ? Qt.alpha(ThemeBackend.mauve, 0.22) : "transparent"
                                    Rectangle { x: 6 * lp.u; anchors.verticalCenter: parent.verticalCenter; width: 12 * lp.u; height: 12 * lp.u; radius: 4 * lp.u; color: Qt.alpha(ThemeBackend.mauve, 0.3 + 0.12 * (index % 3)) }
                                    Column {
                                        x: 24 * lp.u; anchors.verticalCenter: parent.verticalCenter; spacing: 2 * lp.u
                                        Rectangle { width: (60 + 18 * (index % 3)) * lp.u; height: 4 * lp.u; radius: 2 * lp.u; color: Qt.alpha(ThemeBackend.text, 0.55) }
                                        Rectangle { visible: launcherTabRoot.currentShowDescriptions; width: (100 + 20 * (index % 2)) * lp.u; height: 3 * lp.u; radius: 1.5 * lp.u; color: lp.ink }
                                    }
                                }
                            }
                        }

                        Grid {
                            visible: launcherTabRoot.currentGridView
                            columns: launcherTabRoot.currentGridColumns
                            readonly property real cell: parent.width / columns
                            Repeater {
                                model: launcherTabRoot.currentGridColumns * 3
                                Item {
                                    width: parent.cell; height: 38 * lp.u
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 3 * lp.u; width: 18 * lp.u; height: 18 * lp.u; radius: 6 * lp.u; color: Qt.alpha(ThemeBackend.mauve, 0.3 + 0.12 * (index % 3)) }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 26 * lp.u; width: Math.min(parent.width - 4 * lp.u, 22 * lp.u); height: 3 * lp.u; radius: 1.5 * lp.u; color: lp.ink }
                                }
                            }
                        }
                    }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰍹"
                    configKey: "launcher.position"
                    title: I18n.t("guide.launcher.position.title", "Screen Position")
                    description: I18n.t("guide.launcher.position.desc", "Select which screen edge the launcher attaches to")

                    Dropdown {
                        id: posDropdown
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
                        options: [
                            I18n.t("guide.launcher.position.top", "Top"),
                            I18n.t("guide.launcher.position.bottom", "Bottom"),
                            I18n.t("guide.launcher.position.left", "Left"),
                            I18n.t("guide.launcher.position.right", "Right"),
                            I18n.t("guide.launcher.position.center", "Center")
                        ]
                        currentIndex: {
                            if (launcherTabRoot.currentPosition === "bottom") return 1;
                            if (launcherTabRoot.currentPosition === "left") return 2;
                            if (launcherTabRoot.currentPosition === "right") return 3;
                            if (launcherTabRoot.currentPosition === "center") return 4;
                            return 0;
                        }
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(index, value) {
                            let pos = "top";
                            if (index === 1) pos = "bottom";
                            else if (index === 2) pos = "left";
                            else if (index === 3) pos = "right";
                            else if (index === 4) pos = "center";
                            launcherTabRoot.currentPosition = pos;
                            launcherTabRoot.updateLauncherSetting("position", pos);
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰘖"
                    configKey: "launcher.width"
                    title: I18n.t("guide.launcher.width.title", "Launcher Width")
                    description: I18n.t("guide.launcher.width.desc", "Total width of the launcher window in pixels")

                    NumberSelector {
                        id: widthSelector
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(150)
                        implicitHeight: rootObj.s(32)
                        from: 320
                        to: 1400
                        stepSize: 10
                        decimals: 0
                        suffix: "px"
                        value: launcherTabRoot.currentWidth
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(val) {
                            // valueChanged carries no argument: read the new value
                            val = (typeof val === "number" && !isNaN(val)) ? val : value;
                            let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                            let rounded = Math.round(num);
                            if (!isNaN(rounded) && rounded >= 320 && rounded <= 1400 && launcherTabRoot.currentWidth !== rounded) {
                                launcherTabRoot.currentWidth = rounded;
                                launcherTabRoot.triggerDebounced(function() {
                                    launcherTabRoot.updateLauncherSetting("width", rounded);
                                });
                            }
                        }
                        onTriggered: {
                            let rounded = Math.round(widthSelector.value);
                            launcherTabRoot.currentWidth = rounded;
                            launcherTabRoot.updateLauncherSetting("width", rounded);
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰅫"
                    configKey: "launcher.itemCount"
                    title: I18n.t("guide.launcher.items.title", "Visible Items")
                    description: I18n.t("guide.launcher.items.desc", "Number of search results displayed simultaneously")

                    NumberSelector {
                        id: itemsSelector
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(150)
                        implicitHeight: rootObj.s(32)
                        from: 3
                        to: 15
                        stepSize: 1
                        decimals: 0
                        value: launcherTabRoot.currentItemCount
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(val) {
                            // valueChanged carries no argument: read the new value
                            val = (typeof val === "number" && !isNaN(val)) ? val : value;
                            let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                            let rounded = Math.round(num);
                            if (!isNaN(rounded) && rounded >= 3 && rounded <= 15 && launcherTabRoot.currentItemCount !== rounded) {
                                launcherTabRoot.currentItemCount = rounded;
                                launcherTabRoot.triggerDebounced(function() {
                                    launcherTabRoot.updateLauncherSetting("itemCount", rounded);
                                });
                            }
                        }
                        onTriggered: {
                            let rounded = Math.round(itemsSelector.value);
                            launcherTabRoot.currentItemCount = rounded;
                            launcherTabRoot.updateLauncherSetting("itemCount", rounded);
                        }
                    }
                }
            }

            // layout: the rail with favourites, grid view, descriptions, the web button
            SettingsBlob {
                component LauncherToggle: Toggle {
                    property string key: ""
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) { launcherTabRoot.updateLauncherSetting(key, val); }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_rail"
                    icon: "󰐃"
                    configKey: "launcher.showRail"
                    defaultValue: true
                    title: I18n.t("guide.launcher.rail.title", "Favourites grid")
                    description: I18n.t("guide.launcher.rail.desc", "The left side of the launcher: the tabs and a grid of your favourite apps. Drag an app onto it (or right-click it) to pin it, drag tiles to reorder them")
                    searchKeywords: "favourites favorites pinned rail sidebar launcher"
                    LauncherToggle {
                        key: "showRail"
                        checked: launcherTabRoot.currentShowRail
                        onToggled: function(val) { launcherTabRoot.currentShowRail = val; }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_fav_columns"
                    icon: "󰕭"
                    configKey: "launcher.favColumns"
                    defaultValue: 4
                    title: I18n.t("guide.launcher.fav_columns.title", "Favourites per row")
                    description: I18n.t("guide.launcher.fav_columns.desc", "How many favourite apps sit side by side in the grid")
                    hiddenByConfig: !launcherTabRoot.currentShowRail
                    NumberSelector {
                        implicitWidth: rootObj.s(150)
                        implicitHeight: rootObj.s(32)
                        from: 2
                        to: 6
                        stepSize: 1
                        decimals: 0
                        value: launcherTabRoot.currentFavColumns
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(val) {
                            // valueChanged carries no argument: read the new value
                            val = (typeof val === "number" && !isNaN(val)) ? val : value;
                            const c = Math.round(val);
                            if (c >= 2 && c <= 6 && c !== launcherTabRoot.currentFavColumns) {
                                launcherTabRoot.currentFavColumns = c;
                                launcherTabRoot.updateLauncherSetting("favColumns", c);
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_order_reset"
                    icon: "󰑓"
                    configKey: "launcher.appOrder"
                    defaultValue: []
                    title: I18n.t("guide.launcher.order.title", "App order")
                    description: I18n.t("guide.launcher.order.desc", "Drag apps in the list to reorder them. Reset to go back to the automatic order")
                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: I18n.t("guide.launcher.order.reset", "Reset order")
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: launcherTabRoot.updateLauncherSetting("appOrder", [])
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_grid"
                    icon: "󰕰"
                    configKey: "launcher.gridView"
                    defaultValue: false
                    title: I18n.t("guide.launcher.grid.title", "Grid view")
                    description: I18n.t("guide.launcher.grid.desc", "Show apps as a grid of icons instead of a list")
                    searchKeywords: "grid icons view list launcher"
                    LauncherToggle {
                        key: "gridView"
                        checked: launcherTabRoot.currentGridView
                        onToggled: function(val) { launcherTabRoot.currentGridView = val; }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_grid_columns"
                    icon: "󰕭"
                    configKey: "launcher.gridColumns"
                    defaultValue: 5
                    title: I18n.t("guide.launcher.grid_columns.title", "Grid columns")
                    description: I18n.t("guide.launcher.grid_columns.desc", "Apps per row in grid view")
                    hiddenByConfig: !launcherTabRoot.currentGridView
                    NumberSelector {
                        implicitWidth: rootObj.s(150)
                        implicitHeight: rootObj.s(32)
                        from: 3
                        to: 8
                        stepSize: 1
                        decimals: 0
                        value: launcherTabRoot.currentGridColumns
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        buttonColor: ThemeBackend.surface1
                        buttonTextColor: ThemeBackend.text
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontFamily: ThemeBackend.fontFamily
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(val) {
                            // valueChanged carries no argument: read the new value
                            val = (typeof val === "number" && !isNaN(val)) ? val : value;
                            const c = Math.round(val);
                            if (c >= 3 && c <= 8 && c !== launcherTabRoot.currentGridColumns) {
                                launcherTabRoot.currentGridColumns = c;
                                launcherTabRoot.updateLauncherSetting("gridColumns", c);
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_descriptions"
                    icon: "󰦨"
                    configKey: "launcher.showDescriptions"
                    defaultValue: true
                    title: I18n.t("guide.launcher.descriptions.title", "Show descriptions")
                    description: I18n.t("guide.launcher.descriptions.desc", "The line under each app's name in the list")
                    searchKeywords: "description comment subtitle launcher"
                    LauncherToggle {
                        key: "showDescriptions"
                        checked: launcherTabRoot.currentShowDescriptions
                        onToggled: function(val) { launcherTabRoot.currentShowDescriptions = val; }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_web"
                    icon: "󰖟"
                    configKey: "launcher.webSearch"
                    defaultValue: true
                    title: I18n.t("guide.launcher.web.title", "Web search")
                    description: I18n.t("guide.launcher.web.desc", "The globe button next to the search field, and searching the web by starting with ?")
                    searchKeywords: "web search browser internet globe question mark launcher"
                    LauncherToggle {
                        key: "webSearch"
                        checked: launcherTabRoot.currentWebSearch
                        onToggled: function(val) { launcherTabRoot.currentWebSearch = val; }
                    }
                }
            }

            SettingsBlob {
                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰓥"
                    configKey: "launcher.smartRanking"
                    title: I18n.t("guide.launcher.smart_ranking.title", "Smart Rank by Usage")
                    description: I18n.t("guide.launcher.smart_ranking.desc", "Rank apps and widgets based on usage frequency and recency")

                    Toggle {
                        id: smartRankToggle
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: launcherTabRoot.currentSmartRanking
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            launcherTabRoot.currentSmartRanking = val;
                            launcherTabRoot.updateLauncherSetting("smartRanking", val);
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰆍"
                    configKey: "launcher.terminalCommand"
                    title: I18n.t("guide.launcher.terminal.title", "Terminal Command")
                    description: I18n.t("guide.launcher.terminal.desc", "Command prefix used for > executions (e.g. kitty -e, alacritty -e, foot -e)")

                    Input {
                        id: terminalInput
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(220)
                        implicitHeight: rootObj.s(32)
                        text: launcherTabRoot.currentTerminalCommand
                        placeholderText: "kitty -e"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onTextEdited: function(newText) {
                            launcherTabRoot.currentTerminalCommand = newText;
                            launcherTabRoot.triggerDebounced(function() {
                                launcherTabRoot.updateLauncherSetting("terminalCommand", newText);
                            });
                        }
                        onAccepted: function(finalText) {
                            launcherTabRoot.currentTerminalCommand = finalText;
                            launcherTabRoot.updateLauncherSetting("terminalCommand", finalText);
                        }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰖟"
                    configKey: "launcher.searchProvider"
                    defaultValue: "google"
                    title: I18n.t("guide.launcher.search.title", "Web search provider")
                    description: I18n.t("guide.launcher.search.desc", "Search engine used when a query starts with ?")

                    Dropdown {
                        id: searchDropdown
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(180)
                        implicitHeight: rootObj.s(32)
                        options: SearchProviders.names()
                        currentIndex: SearchProviders.indexOf(launcherTabRoot.currentSearchProvider)
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: rootObj.s(11)
                        onValueChanged: function(index, value) {
                            let id = SearchProviders.PROVIDERS[index].id;
                            launcherTabRoot.currentSearchProvider = id;
                            launcherTabRoot.updateLauncherSetting("searchProvider", id);
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(4)
                Layout.leftMargin: rootObj.s(4)
                Layout.rightMargin: rootObj.s(4)
                spacing: rootObj.s(12)

                Item { Layout.fillWidth: true }

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(36)
                    horizontalPadding: rootObj.s(16)
                    buttonText: I18n.t("guide.launcher.test", "Open Launcher")
                    buttonIcon: "󰵆"
                    iconFontSize: rootObj.s(16)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "toggle", "launcher"]);
                    }
                }
            }
        }
    }
}
