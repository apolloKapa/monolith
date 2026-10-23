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

            SettingsBlob {
                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    icon: "󰍹"
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
                    title: I18n.t("guide.launcher.rail.title", "Favourites rail")
                    description: I18n.t("guide.launcher.rail.desc", "A slim column on the left with the tabs and your favourite apps. Right-click an app to pin or unpin it")
                    searchKeywords: "favourites favorites pinned rail sidebar launcher"
                    LauncherToggle {
                        key: "showRail"
                        checked: launcherTabRoot.currentShowRail
                        onToggled: function(val) { launcherTabRoot.currentShowRail = val; }
                    }
                }

                SettingsRow {
                    rootObj: launcherTabRoot.rootObj
                    settingId: "launcher_grid"
                    icon: "󰕰"
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
