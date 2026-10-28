import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Icons: pick the icon pack apps and Monolith draw (like KDE's Icons page).
// scripts/icon_themes.py lists the installed packs with a few sample icons each, and applies one
// to Qt apps (qt6ct/qt5ct), GTK 3/4 (settings.ini) and gsettings. Monolith reads its icons when
// it starts, so it restarts itself a moment after a change to show the new ones; the restart
// closes Settings too, so it comes straight back on this page.
// Below the packs, one app at a time can get another icon (from any pack, or an image file):
// icon_themes.py writes it into the app's .desktop copy in ~/.local/share/applications, which
// Monolith and every other launcher, dock and menu read.
GuideTab {
    id: iconsTab

    property var themes: []
    property string current: ""
    property string applying: ""
    property string error: ""

    // ---- one app's icon ----
    readonly property var apps: {
        let seen = {}, out = [];
        for (const e of DesktopEntries.applications.values) {
            if (!e || e.noDisplay || seen[e.id]) continue;
            seen[e.id] = true;
            out.push(e);
        }
        return out.sort((a, b) => String(a.name).localeCompare(String(b.name)));
    }
    property string appQuery: ""
    readonly property var shownApps: {
        const q = appQuery.trim().toLowerCase();
        return q === "" ? apps : apps.filter(e => String(e.name).toLowerCase().indexOf(q) >= 0 || String(e.id).toLowerCase().indexOf(q) >= 0);
    }
    property var overrides: ({})      // app id -> icon, for the apps given one here
    // the app being changed, by id: its DesktopEntry is replaced when its .desktop file changes
    property string editingId: ""
    readonly property var editing: editingId === "" ? null : (apps.find(e => e.id === editingId) || null)
    property string iconQuery: ""
    property var iconResults: []
    property string appError: ""

    function iconUrl(ic) {
        if (!ic) return "";
        ic = String(ic);
        if (ic.startsWith("file://") || ic.startsWith("image://")) return ic;
        if (ic.startsWith("/")) return "file://" + ic;
        const p = Quickshell.iconPath(ic, true);
        return p ? (p.startsWith("/") ? "file://" + p : p) : "image://icon/" + ic;
    }

    function editApp(entry) {
        editingId = entry.id;
        appError = "";
        // start from icons named like the app
        iconQuery = String(entry.id).split(".").pop().toLowerCase();
        searchIcons();
    }

    function searchIcons() {
        iconSearch.running = false;
        iconSearch.command = ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "search", iconQuery];
        iconSearch.running = true;
    }

    function setAppIcon(icon) {
        if (editingId === "" || appIconSetter.running) return;
        appError = "";
        appIconSetter.command = icon === ""
            ? ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "app-icon-reset", editingId]
            : ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "app-icon", editingId, icon];
        appIconSetter.running = true;
    }

    function readOverrides() {
        overridesReader.running = false;
        overridesReader.running = true;
    }

    Process {
        id: overridesReader
        command: ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "app-overrides"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { iconsTab.overrides = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: iconSearch
        stdout: StdioCollector {
            onStreamFinished: {
                try { iconsTab.iconResults = JSON.parse(this.text); } catch (e) { iconsTab.iconResults = []; }
            }
        }
    }

    Process {
        id: appIconSetter
        stderr: StdioCollector { id: appIconErr }
        onExited: function(code) {
            if (code !== 0) iconsTab.appError = appIconErr.text.trim() || "Couldn't change the icon";
            iconsTab.readOverrides();
        }
    }

    Timer {
        id: iconSearchDebounce
        interval: 250
        onTriggered: iconsTab.searchIcons()
    }

    FilePicker {
        id: imagePicker
        rootObj: iconsTab.rootObj
        titleText: "Pick an image for the icon"
        nameFilters: ["*.png", "*.svg", "*.svgz", "*.xpm", "*.jpg", "*.jpeg", "*.webp", "*.ico"]
        places: [
            { name: "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
            { name: "Pictures", icon: "󰉏", path: "file://" + (Quickshell.env("HOME") || "") + "/Pictures" },
            { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
            { name: "Icons", icon: "󰀻", path: "file:///usr/share/icons" }
        ]
        onFileSelected: function(filePath, fileName) {
            if (filePath) iconsTab.setAppIcon(String(filePath).replace(/^file:\/\//, ""));
        }
    }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    function choose(id) {
        if (!id || id === current || setter.running) return;
        applying = id;
        error = "";
        setter.command = ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "set", id];
        setter.running = true;
    }

    Process {
        id: lister
        command: ["python3", Caching.monolithDir + "/scripts/icon_themes.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    iconsTab.themes = d.themes || [];
                    iconsTab.current = d.current || "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: setter
        stderr: StdioCollector { id: setterErr }
        onExited: function(code) {
            if (code === 0) {
                iconsTab.current = iconsTab.applying;
                restartShell.restart();
            } else {
                iconsTab.error = setterErr.text.trim() || "Couldn't switch the icon pack";
            }
            iconsTab.applying = "";
        }
    }

    // Monolith picks its icons up when it starts: restart it once the choice settles, then
    // reopen Settings here (detached, so it outlives this window)
    Timer {
        id: restartShell
        interval: 1200
        onTriggered: Quickshell.execDetached(["bash", "-c",
            "monolith restart >/dev/null 2>&1; sleep 0.6; bash \"$1\" open theme theme_icons", "_",
            Caching.monolithDir + "/scripts/settings.sh"])
    }

    Component.onCompleted: { refresh(); readOverrides(); }

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

                SettingsRow {
                    rootObj: iconsTab.rootObj
                    settingId: "icon_pack"
                    icon: "󰀻"
                    title: "Icon pack"
                    description: iconsTab.themes.length === 0
                        ? "Looking for installed icon packs..."
                        : "The icons apps, the launcher, dock and overview use. Install more into ~/.local/share/icons"
                    searchKeywords: "icon icons pack theme papirus breeze adwaita app icons look"

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Refresh"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: iconsTab.refresh()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    visible: iconsTab.error !== ""
                    text: iconsTab.error
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    wrapMode: Text.WordWrap
                }
            }

            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((width + columnSpacing) / (rootObj.s(300) + columnSpacing)))
                columnSpacing: rootObj.s(8)
                rowSpacing: rootObj.s(8)

                Repeater {
                    model: iconsTab.themes

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool chosen: modelData.id === iconsTab.current
                        readonly property bool busy: modelData.id === iconsTab.applying

                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(118)
                        radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                        color: cardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, cardMouse.containsMouse ? 0.7 : 0.45)
                        border.width: chosen ? 2 : 1
                        border.color: chosen ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface1, 0.5)
                        Behavior on color { ColorAnimation { duration: 150 * ThemeBackend.animScale } }

                        GlassFill {
                            id: cardGlass
                            anchors.fill: parent
                            radius: ThemeBackend.rad(parent.radius)
                            tintColor: Qt.alpha(ThemeBackend.surface0, 0.45)
                            tintAmount: 0.25
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(12)
                            spacing: rootObj.s(8)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(6)

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.name
                                    elide: Text.ElideRight
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    font.bold: true
                                }
                                Text {
                                    visible: card.chosen || card.busy
                                    text: card.busy ? "applying..." : "in use"
                                    color: card.chosen ? ThemeBackend.mauve : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                }
                            }

                            // what the pack's icons look like
                            Row {
                                id: sampleRow
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: rootObj.s(8)

                                Repeater {
                                    // as many as fit whole: a cut-off icon at the edge looked broken
                                    model: card.modelData.samples.slice(0, Math.max(1, Math.floor((sampleRow.width + sampleRow.spacing) / (rootObj.s(30) + sampleRow.spacing))))
                                    Image {
                                        required property string modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: rootObj.s(30)
                                        height: rootObj.s(30)
                                        sourceSize: Qt.size(rootObj.s(60), rootObj.s(60))
                                        source: "file://" + modelData
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.comment && card.modelData.comment !== card.modelData.name ? card.modelData.comment : ""
                                elide: Text.ElideRight
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: iconsTab.choose(card.modelData.id)
                        }
                    }
                }
            }

            // ---- one app's icon ----
            SettingsBlob {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(6)

                SettingsRow {
                    rootObj: iconsTab.rootObj
                    settingId: "app_icon"
                    icon: "󰏫"
                    title: "One app's icon"
                    description: "Give a single app another icon, from any pack or an image file"
                    searchKeywords: "app icon change custom single one edit application icon image"

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: rootObj.s(200)
                        Layout.preferredHeight: rootObj.s(32)
                        text: iconsTab.appQuery
                        placeholderText: "Search apps"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onTextEdited: newText => iconsTab.appQuery = newText
                    }
                }

                // the app being changed
                Rectangle {
                    Layout.fillWidth: true
                    visible: iconsTab.editingId !== ""
                    implicitHeight: editorCol.implicitHeight + rootObj.s(24)
                    radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                    color: Qt.alpha(ThemeBackend.surface0, 0.55)
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.mauve, 0.5)

                    ColumnLayout {
                        id: editorCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: rootObj.s(12)
                        spacing: rootObj.s(10)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: rootObj.s(12)

                            Image {
                                Layout.preferredWidth: rootObj.s(48)
                                Layout.preferredHeight: rootObj.s(48)
                                sourceSize: Qt.size(rootObj.s(96), rootObj.s(96))
                                source: iconsTab.editing ? iconsTab.iconUrl(iconsTab.editing.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(2)
                                Text {
                                    Layout.fillWidth: true
                                    text: iconsTab.editing ? iconsTab.editing.name : ""
                                    elide: Text.ElideRight
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(14)
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: iconsTab.appError !== "" ? iconsTab.appError
                                        : "Click an icon below to use it" + (appIconSetter.running ? "  ·  saving..." : "")
                                    elide: Text.ElideRight
                                    color: iconsTab.appError !== "" ? ThemeBackend.red : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                }
                            }
                            ClickButton {
                                implicitHeight: rootObj.s(32)
                                horizontalPadding: rootObj.s(14)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: "Choose image..."
                                textFontSize: rootObj.s(11)
                                accentColor: ThemeBackend.surface1
                                textColor: ThemeBackend.text
                                onClicked: imagePicker.openWithOptionalPath("")
                            }
                            ClickButton {
                                visible: iconsTab.overrides[iconsTab.editingId] !== undefined
                                implicitHeight: rootObj.s(32)
                                horizontalPadding: rootObj.s(14)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: "Use original"
                                textFontSize: rootObj.s(11)
                                accentColor: ThemeBackend.surface1
                                textColor: ThemeBackend.text
                                onClicked: iconsTab.setAppIcon("")
                            }
                            ClickButton {
                                implicitHeight: rootObj.s(32)
                                horizontalPadding: rootObj.s(14)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: "Done"
                                textFontSize: rootObj.s(11)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.crust
                                onClicked: iconsTab.editingId = ""
                            }
                        }

                        Input {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rootObj.s(32)
                            text: iconsTab.iconQuery
                            placeholderText: "Search icons in every pack (folder, firefox, music...)"
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onTextEdited: newText => { iconsTab.iconQuery = newText; iconSearchDebounce.restart(); }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: rootObj.s(6)

                            Repeater {
                                model: iconsTab.iconResults
                                Rectangle {
                                    id: iconTile
                                    required property var modelData
                                    width: rootObj.s(52)
                                    height: rootObj.s(52)
                                    radius: ThemeBackend.rad(rootObj.s(8))
                                    color: tileMouse.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.8) : Qt.alpha(ThemeBackend.surface0, 0.6)
                                    border.width: iconsTab.editing && iconsTab.editing.icon === modelData.name ? 2 : 0
                                    border.color: ThemeBackend.mauve

                                    Image {
                                        anchors.centerIn: parent
                                        width: rootObj.s(34)
                                        height: rootObj.s(34)
                                        sourceSize: Qt.size(rootObj.s(68), rootObj.s(68))
                                        source: "file://" + iconTile.modelData.path
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: iconsTab.setAppIcon(iconTile.modelData.name)
                                    }
                                    // the icon's name, so similar-looking ones can be told apart
                                    Rectangle {
                                        visible: tileMouse.containsMouse
                                        z: 10
                                        anchors.top: parent.bottom
                                        anchors.topMargin: rootObj.s(4)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: tipText.implicitWidth + rootObj.s(12)
                                        height: tipText.implicitHeight + rootObj.s(6)
                                        radius: ThemeBackend.rad(rootObj.s(6))
                                        color: ThemeBackend.crust
                                        Text {
                                            id: tipText
                                            anchors.centerIn: parent
                                            text: iconTile.modelData.name + "  ·  " + iconTile.modelData.pack
                                            color: ThemeBackend.text
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: rootObj.s(10)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: iconsTab.iconResults.length === 0 && !iconSearch.running
                            text: "No icons called that"
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj.s(11)
                        }
                    }
                }

                // every app; the ones given an icon here are outlined
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: rootObj.s(4)
                    spacing: rootObj.s(6)

                    Repeater {
                        model: iconsTab.shownApps
                        Rectangle {
                            id: appTile
                            required property var modelData
                            readonly property bool custom: iconsTab.overrides[modelData.id] !== undefined
                            width: rootObj.s(96)
                            height: rootObj.s(84)
                            radius: ThemeBackend.rad(rootObj.s(10))
                            color: appMouse.containsMouse || iconsTab.editingId === modelData.id
                                ? Qt.alpha(ThemeBackend.surface1, 0.8) : Qt.alpha(ThemeBackend.surface0, 0.45)
                            border.width: custom ? 2 : 0
                            border.color: ThemeBackend.mauve

                            Column {
                                anchors.centerIn: parent
                                spacing: rootObj.s(6)
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: rootObj.s(36)
                                    height: rootObj.s(36)
                                    sourceSize: Qt.size(rootObj.s(72), rootObj.s(72))
                                    source: iconsTab.iconUrl(appTile.modelData.icon)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                }
                                Text {
                                    width: rootObj.s(86)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: appTile.modelData.name
                                    elide: Text.ElideRight
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(10)
                                }
                            }
                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: iconsTab.editApp(appTile.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
