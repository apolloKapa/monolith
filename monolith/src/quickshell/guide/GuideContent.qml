import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "../reusables/buttons"

Item {
    id: contentArea
    required property var popup
    property alias searchInput: searchField
    property alias searchResults: resultsList

    readonly property real searchHeaderHeight: popup.s(64)

    // after a Reset button: rebuild the page that's open so its controls show the defaults,
    // keeping where it was scrolled to
    function findFlickable(item, depth) {
        if (!item || depth > 6) return null;
        if (item.contentY !== undefined && item.contentHeight !== undefined) return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; i++) {
            const f = contentArea.findFlickable(kids[i], depth + 1);
            if (f) return f;
        }
        return null;
    }
    function reloadCurrentPage() {
        const wrapper = contentRepeater.itemAt(popup.currentTab);
        if (!wrapper) return;
        const loader = wrapper.hasSubtabs ? wrapper.subLoadersRepeater.itemAt(popup.currentSubTab) : wrapper.singleLoader;
        if (!loader) return;
        const flick = contentArea.findFlickable(loader.item, 0);
        const y = flick ? flick.contentY : 0;
        loader.source = "";
        loader.ensureLoaded();
        Qt.callLater(function() {
            const f = contentArea.findFlickable(loader.item, 0);
            if (f) f.contentY = Math.min(y, Math.max(0, f.contentHeight - f.height));
        });
    }
    Timer {
        id: resetReloadTimer
        interval: 200
        onTriggered: contentArea.reloadCurrentPage()
    }
    Connections {
        target: SettingsDefaults
        function onResetDone(path) { resetReloadTimer.restart(); }
    }

    // page header: the section in small type, the page's name big under it
    Item {
        id: crumb
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: popup.s(22)
        anchors.rightMargin: popup.s(22)
        height: crumbCol.implicitHeight + popup.s(18)

        function tabName(t) {
            return t ? I18n.t("guide.tabs." + (t.key || t.id).toLowerCase(), t.name || t.id) : "";
        }
        readonly property var tab: popup.currentTabModel
        readonly property var sub: (tab && tab.subtabs && popup.currentSubTab >= 0) ? tab.subtabs[popup.currentSubTab] : null

        readonly property string pageDesc: {
            const d = (crumb.sub && crumb.sub.desc) ? crumb.sub.desc : (crumb.tab && crumb.tab.desc ? crumb.tab.desc : "");
            const key = "guide.tabs." + ((crumb.sub || crumb.tab || {}).key || "") + "_desc";
            return d !== "" ? I18n.t(key, d) : "";
        }

        Column {
            id: crumbCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: popup.s(8)
            spacing: popup.s(2)
            Text {
                visible: crumb.sub !== null
                text: crumb.tabName(crumb.tab)
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Medium
                font.pixelSize: popup.s(13)
                color: ThemeBackend.mauve
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: crumb.tabName(crumb.sub !== null ? crumb.sub : crumb.tab)
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Normal
                font.pixelSize: popup.s(28)
                color: ThemeBackend.text
            }
            // what this page is for, in one line
            Text {
                visible: crumb.pageDesc !== ""
                width: parent.width
                topPadding: popup.s(2)
                wrapMode: Text.WordWrap
                text: crumb.pageDesc
                font.family: ThemeBackend.fontFamily
                font.pixelSize: popup.s(13)
                color: ThemeBackend.subtext0
            }
        }
    }

    Item {
        id: body
        anchors.top: crumb.bottom
        anchors.topMargin: popup.s(4)
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    Repeater {
        id: contentRepeater
        model: popup.tabsModel
        delegate: Item {
            id: tabContentWrapper
            x: 0
            y: 0

            property int parentTabIndex: index
            property int tabIndex: parentTabIndex
            property var tabData: modelData
            property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)
            property alias singleLoader: singleTabLoader
            property alias subLoadersRepeater: subRepeat

            property bool isCurrent: popup.currentTab === parentTabIndex
            visible: isCurrent || opacity > 0.001
            opacity: isCurrent ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: (140) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
            }

            Binding {
                target: tabContentWrapper
                property: "width"
                value: body.width
                when: tabContentWrapper.visible
            }

            Binding {
                target: tabContentWrapper
                property: "height"
                value: body.height
                when: tabContentWrapper.visible
            }

            Loader {
                id: singleTabLoader
                anchors.fill: parent
                asynchronous: false
                active: !tabContentWrapper.hasSubtabs
                visible: !tabContentWrapper.hasSubtabs && tabContentWrapper.visible
                property int tabIndex: tabContentWrapper.parentTabIndex
                property int subTabIndex: -1

                function ensureLoaded() {
                    if (status === Loader.Null && tabData.file) {
                        setSource(tabData.file, {
                            "rootObj": popup,
                            "tabIndex": tabContentWrapper.parentTabIndex
                        });
                    }
                }

                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.warn("Guide tab failed to load:", source);
                    }
                }

                onLoaded: {
                    popup.registerTabSearchItems(item);
                    Qt.callLater(function() {
                        popup.registerTabSearchItems(singleTabLoader.item);
                    });
                }

                Component.onCompleted: {
                    // only the page being opened: the rest load one by one once the window is up
                    // (searchLoadTimer), so Settings doesn't build every page before it appears
                    if (popup.currentTab === tabContentWrapper.parentTabIndex) ensureLoaded();
                }

                Connections {
                    target: popup
                    function onCurrentTabChanged() {
                        if (popup.currentTab === tabContentWrapper.parentTabIndex && !tabContentWrapper.hasSubtabs) singleTabLoader.ensureLoaded();
                    }
                    function onRequestLoad(order) {
                        if (order === popup.tabLoadOrder(tabContentWrapper.parentTabIndex, -1)) singleTabLoader.ensureLoaded();
                    }
                }

                Connections {
                    target: singleTabLoader.item
                    ignoreUnknownSignals: true
                    function onSearchItemsChanged() {
                        popup.registerTabSearchItems(singleTabLoader.item);
                    }
                    function onSearchEntriesChanged() {
                        popup.registerTabSearchItems(singleTabLoader.item);
                    }
                }
            }

            Repeater {
                id: subRepeat
                model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                delegate: Loader {
                    id: subTabLoader
                    anchors.fill: parent
                    asynchronous: false
                    property int subIndex: index
                    property int tabIndex: tabContentWrapper.parentTabIndex
                    property int subTabIndex: subIndex
                    property var subData: modelData

                    property bool isSubCurrent: popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex
                    visible: isSubCurrent || opacity > 0.001
                    opacity: isSubCurrent ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: (140) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
                    }

                    function ensureLoaded() {
                        if (status === Loader.Null && subData.file) {
                            setSource(subData.file, {
                                "rootObj": popup,
                                "tabIndex": tabContentWrapper.parentTabIndex
                            });
                            if (item && item.subTabIndex !== undefined) {
                                item.subTabIndex = subIndex;
                            }
                        }
                    }

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.warn("Guide tab failed to load:", source);
                        }
                    }

                    onLoaded: {
                        if (item && item.subTabIndex !== undefined) {
                            item.subTabIndex = subIndex;
                        }
                        popup.registerTabSearchItems(item);
                        Qt.callLater(function() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        });
                    }

                    Component.onCompleted: {
                        if (isSubCurrent) ensureLoaded();
                    }

                    Connections {
                        target: popup
                        function onCurrentTabChanged() {
                            if (popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                        }
                        function onCurrentSubTabChanged() {
                            if (popup.currentTab === tabContentWrapper.parentTabIndex && popup.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                        }
                        function onRequestLoad(order) {
                            if (order === popup.tabLoadOrder(tabContentWrapper.parentTabIndex, subIndex)) subTabLoader.ensureLoaded();
                        }
                    }

                    Connections {
                        target: subTabLoader.item
                        ignoreUnknownSignals: true
                        function onSearchItemsChanged() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        }
                        function onSearchEntriesChanged() {
                            popup.registerTabSearchItems(subTabLoader.item);
                        }
                    }
                }
            }
        }
    }
    }

    Rectangle {
        id: searchOverlay
        anchors.fill: parent
        color: ThemeBackend.base
        visible: popup.searchActive
        z: 10

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: contentArea.searchHeaderHeight

            Input {
                id: searchField
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: popup.s(20)
                anchors.rightMargin: popup.s(20)
                implicitHeight: popup.s(38)
                height: popup.s(38)
                placeholderText: I18n.t("guide.search.placeholder", "Search settings...")
                showClearButton: true
                fontPixelSize: popup.s(12)
                baseColor: Qt.alpha(ThemeBackend.surface0, 0.6)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.4)
                cornerRadius: ThemeBackend.borderRadius

                onTextEdited: (txt) => {
                    popup.searchQuery = txt;
                    popup.searchSelectedIndex = 0;
                }
                onCleared: {
                    popup.searchQuery = "";
                    popup.searchSelectedIndex = 0;
                }

                Keys.onEscapePressed: (event) => {
                    if (popup.searchQuery !== "") {
                        searchField.text = "";
                        popup.searchQuery = "";
                    } else {
                        popup.closeSearch();
                    }
                    event.accepted = true;
                }
                Keys.onDownPressed: (event) => { popup.navigateSearch(1); event.accepted = true; }
                Keys.onUpPressed: (event) => { popup.navigateSearch(-1); event.accepted = true; }
                Keys.onReturnPressed: (event) => { popup.activateSelectedSearch(); event.accepted = true; }
                Keys.onEnterPressed: (event) => { popup.activateSelectedSearch(); event.accepted = true; }
            }
        }

        GuideSearchResults {
            id: resultsList
            popup: contentArea.popup
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: popup.s(16)
            anchors.rightMargin: popup.s(16)
            anchors.bottomMargin: popup.s(8)
        }
    }
}
