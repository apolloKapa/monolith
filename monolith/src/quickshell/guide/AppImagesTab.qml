import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> AppImages: drop an AppImage (here, or into the AppImages folder) and it becomes an
// app like any installed one: made executable, kept in the folder, and given an entry with its
// own name and icon, so the launcher, dock and menus show it (scripts/appimages.py; the folder
// is watched by AppImageWatcher).
GuideTab {
    id: appimagesTab

    property var apps: []
    property string folder: ""
    property string error: ""
    property string notice: ""
    property bool dragOver: false

    readonly property var cfg: (Config.rawSettings && Config.rawSettings.appimages) ? Config.rawSettings.appimages : ({})
    readonly property bool watch: cfg.watch !== false

    function script() { return Caching.monolithDir + "/scripts/appimages.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    // jobs run one after another (several files can be dropped at once)
    property var queue: []
    function run(args, label) {
        queue = queue.concat([{ args: args, label: label }]);
        next();
    }
    function next() {
        if (worker.running || queue.length === 0) return;
        const job = queue[0];
        queue = queue.slice(1);
        error = "";
        notice = job.label;
        worker.command = ["python3", script()].concat(job.args);
        worker.running = true;
    }

    function addFiles(urls) {
        let n = 0;
        for (const u of urls) {
            let p = decodeURIComponent(String(u).replace(/^file:\/\//, ""));
            if (!/\.appimage$/i.test(p)) continue;
            run(["add", p], "Adding " + p.split("/").pop() + "...");
            n++;
        }
        if (n === 0) error = "That isn't an AppImage (the file name ends in .AppImage)";
    }

    function setCfg(key, value) {
        let c = JSON.parse(JSON.stringify(Config.getSetting("appimages", {}) || {}));
        c[key] = value;
        Config.setSetting("appimages", c);
    }

    function iconUrl(ic) {
        if (!ic) return "";
        if (ic.startsWith("/")) return "file://" + ic;
        const p = Quickshell.iconPath(ic, true);
        return p ? (p.startsWith("/") ? "file://" + p : p) : "image://icon/" + ic;
    }

    Process {
        id: lister
        command: ["python3", appimagesTab.script(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    appimagesTab.apps = d.apps || [];
                    appimagesTab.folder = d.folder || "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: worker
        stderr: StdioCollector { id: workerErr }
        onExited: function(code) {
            if (code !== 0) appimagesTab.error = workerErr.text.trim() || "That didn't work";
            appimagesTab.notice = "";
            appimagesTab.refresh();
            appimagesTab.next();
        }
    }

    FilePicker {
        id: picker
        rootObj: appimagesTab.rootObj
        titleText: "Pick an AppImage"
        nameFilters: ["*.AppImage", "*.appimage"]
        places: [
            { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
            { name: "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
            { name: "AppImages", icon: "󰏗", path: "file://" + appimagesTab.folder }
        ]
        onFileSelected: function(filePath, fileName) {
            if (filePath) appimagesTab.addFiles([filePath]);
        }
    }

    Component.onCompleted: refresh()

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

            // the drop zone
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(132)
                radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                color: appimagesTab.dragOver ? Qt.alpha(ThemeBackend.mauve, 0.14) : Qt.alpha(ThemeBackend.surface0, 0.45)
                border.width: 2
                border.color: appimagesTab.dragOver ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.6)
                Behavior on color { ColorAnimation { duration: 150 * ThemeBackend.animScale } }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onEntered: appimagesTab.dragOver = true
                    onExited: appimagesTab.dragOver = false
                    onDropped: function(drop) {
                        appimagesTab.dragOver = false;
                        if (drop.hasUrls) {
                            appimagesTab.addFiles(drop.urls);
                            drop.acceptProposedAction();
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: rootObj.s(8)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰏗"
                        color: appimagesTab.dragOver ? ThemeBackend.mauve : ThemeBackend.subtext0
                        font.family: ThemeBackend.iconFont || ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(30)
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: appimagesTab.notice !== "" ? appimagesTab.notice : "Drop an AppImage here"
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(14)
                        font.bold: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "It goes into your AppImages folder and shows up in the launcher, dock and menus with its own icon"
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                    }
                    ClickButton {
                        Layout.alignment: Qt.AlignHCenter
                        implicitHeight: rootObj.s(30)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Or pick one..."
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        onClicked: picker.openWithOptionalPath("")
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: rootObj.s(12)
                visible: appimagesTab.error !== ""
                text: appimagesTab.error
                color: ThemeBackend.red
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                wrapMode: Text.WordWrap
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: appimagesTab.rootObj
                    settingId: "appimages_watch"
                    icon: "󰉋"
                    title: "Add from the folder by itself"
                    description: "Anything you save or move into " + (appimagesTab.folder || "~/Appimages") + " is added the same way, and removed when you delete the file"
                    searchKeywords: "appimage folder watch automatic add download install apps"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: appimagesTab.watch
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { appimagesTab.setCfg("watch", c); }
                    }
                }

                SettingsRow {
                    rootObj: appimagesTab.rootObj
                    settingId: "appimages_folder"
                    icon: "󰝰"
                    title: "AppImages folder"
                    description: "Where AppImages you add are kept"
                    searchKeywords: "appimage folder location path directory"

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: rootObj.s(260)
                        Layout.preferredHeight: rootObj.s(32)
                        text: appimagesTab.cfg.folder || "~/Appimages"
                        placeholderText: "~/Appimages"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onAccepted: newText => { appimagesTab.setCfg("folder", String(newText).trim()); folderRefresh.restart(); }
                    }
                }
            }
            Timer { id: folderRefresh; interval: 400; onTriggered: appimagesTab.refresh() }

            // the AppImages that have an app entry
            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: appimagesTab.rootObj
                    settingId: "appimages_list"
                    icon: "󰀻"
                    title: "Your AppImages"
                    description: appimagesTab.apps.length === 0 ? "None yet" : appimagesTab.apps.length + " with an app entry"
                    searchKeywords: "appimage list installed remove delete uninstall"

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Refresh"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: appimagesTab.run(["sync"], "Looking through the folder...")
                    }
                }

                Repeater {
                    model: appimagesTab.apps

                    RowLayout {
                        id: appRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(12)
                        Layout.rightMargin: rootObj.s(12)
                        spacing: rootObj.s(12)

                        Image {
                            Layout.preferredWidth: rootObj.s(36)
                            Layout.preferredHeight: rootObj.s(36)
                            sourceSize: Qt.size(rootObj.s(72), rootObj.s(72))
                            source: appimagesTab.iconUrl(appRow.modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: rootObj.s(1)
                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.name
                                elide: Text.ElideRight
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (appRow.modelData.exists ? "" : "file missing  ·  ") + appRow.modelData.path
                                elide: Text.ElideMiddle
                                color: appRow.modelData.exists ? ThemeBackend.subtext0 : ThemeBackend.red
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                            }
                        }
                        ClickButton {
                            implicitHeight: rootObj.s(28)
                            horizontalPadding: rootObj.s(12)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: "Remove"
                            textFontSize: rootObj.s(11)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onClicked: appimagesTab.run(["remove", appRow.modelData.id], "Removing " + appRow.modelData.name + "...")
                        }
                        ClickButton {
                            visible: appRow.modelData.exists
                            implicitHeight: rootObj.s(28)
                            horizontalPadding: rootObj.s(12)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: "Delete file"
                            textFontSize: rootObj.s(11)
                            accentColor: Qt.alpha(ThemeBackend.red, 0.85)
                            textColor: ThemeBackend.crust
                            onClicked: appimagesTab.run(["remove", appRow.modelData.id, "--delete"], "Deleting " + appRow.modelData.name + "...")
                        }
                    }
                }
            }
        }
    }
}
