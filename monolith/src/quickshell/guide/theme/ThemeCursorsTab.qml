import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Cursors: pick the mouse pointer (like the Icons page, for cursors).
// scripts/cursor_themes.py lists the installed cursor themes with previews made from their
// Xcursor files and applies one to niri (which switches at once), GTK and gsettings. "Add your
// own" takes a downloaded theme (an archive or a folder) or a single image, which becomes the
// arrow while the theme in use draws every other shape.
GuideTab {
    id: cursorsTab

    property var themes: []
    property string current: ""
    property int size: 24
    property string applying: ""
    property string error: ""
    property string notice: ""
    // the usual sizes, plus the one in use if it's something else (niri's default config has 22)
    readonly property var sizes: {
        let l = [16, 20, 24, 28, 32, 40, 48, 64];
        if (l.indexOf(size) < 0) l.push(size);
        return l.sort((a, b) => a - b);
    }

    function script() { return Caching.monolithDir + "/scripts/cursor_themes.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    function choose(id, newSize) {
        if (!id || setter.running) return;
        if (id === current && newSize === size) return;
        applying = id;
        error = "";
        notice = "";
        setter.command = ["python3", script(), "set", id, String(newSize)];
        setter.running = true;
    }

    function run(args) {
        if (worker.running) return;
        error = "";
        notice = "";
        worker.command = ["python3", script()].concat(args);
        worker.running = true;
    }

    Process {
        id: lister
        command: ["python3", cursorsTab.script(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    cursorsTab.themes = d.themes || [];
                    cursorsTab.current = d.current || "";
                    cursorsTab.size = d.size || 24;
                } catch (e) {}
            }
        }
    }

    Process {
        id: setter
        stdout: StdioCollector { id: setterOut }
        stderr: StdioCollector { id: setterErr }
        onExited: function(code) {
            if (code === 0) {
                try {
                    const d = JSON.parse(setterOut.text);
                    cursorsTab.current = d.current;
                    cursorsTab.size = d.size;
                } catch (e) {}
            } else {
                cursorsTab.error = setterErr.text.trim() || "Couldn't switch the cursor";
            }
            cursorsTab.applying = "";
        }
    }

    // add / remove
    Process {
        id: worker
        stdout: StdioCollector { id: workerOut }
        stderr: StdioCollector { id: workerErr }
        onExited: function(code) {
            if (code !== 0) {
                cursorsTab.error = workerErr.text.trim() || "That didn't work";
                return;
            }
            let d = {};
            try { d = JSON.parse(workerOut.text); } catch (e) {}
            cursorsTab.refresh();
            // a theme just added is put to use straight away
            if (d.added && d.added.length > 0) cursorsTab.choose(d.added[0], cursorsTab.size);
            if (d.removed) cursorsTab.notice = "Removed";
        }
    }

    FilePicker {
        id: addPicker
        rootObj: cursorsTab.rootObj
        titleText: "Pick a cursor theme (archive) or an image"
        nameFilters: ["*.tar.gz", "*.tgz", "*.tar.xz", "*.txz", "*.tar.bz2", "*.tar", "*.zip",
                      "*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"]
        places: [
            { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("HOME") || "") + "/Downloads" },
            { name: "Home", icon: "󰋜", path: "file://" + (Quickshell.env("HOME") || "") },
            { name: "Pictures", icon: "󰉏", path: "file://" + (Quickshell.env("HOME") || "") + "/Pictures" }
        ]
        onFileSelected: function(filePath, fileName) {
            if (filePath) cursorsTab.run(["add", String(filePath).replace(/^file:\/\//, "")]);
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

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: cursorsTab.rootObj
                    settingId: "cursor_theme"
                    icon: "󰆿"
                    title: "Cursor"
                    description: cursorsTab.themes.length === 0
                        ? "Looking for installed cursor themes..."
                        : "The mouse pointer. Apps that are already open may keep the old one until you reopen them"
                    searchKeywords: "cursor cursors mouse pointer arrow theme xcursor breeze adwaita bibata"

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: worker.running ? "Adding..." : "Add your own..."
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        onClicked: addPicker.openWithOptionalPath("")
                    }
                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Refresh"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: cursorsTab.refresh()
                    }
                }

                SettingsRow {
                    rootObj: cursorsTab.rootObj
                    settingId: "cursor_size"
                    icon: "󰩨"
                    title: "Size"
                    description: "How big the pointer is, in pixels"
                    searchKeywords: "cursor size big small large pointer"

                    Dropdown {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(120)
                        implicitHeight: rootObj.s(32)
                        options: cursorsTab.sizes.map(s => s + " px")
                        currentIndex: Math.max(0, cursorsTab.sizes.indexOf(cursorsTab.size))
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        onValueChanged: function(index, value) {
                            const s = cursorsTab.sizes[index];
                            if (s && cursorsTab.current) cursorsTab.choose(cursorsTab.current, s);
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    visible: cursorsTab.error !== "" || cursorsTab.notice !== ""
                    text: cursorsTab.error !== "" ? cursorsTab.error : cursorsTab.notice
                    color: cursorsTab.error !== "" ? ThemeBackend.red : ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    wrapMode: Text.WordWrap
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((width + columnSpacing) / (rootObj.s(300) + columnSpacing)))
                columnSpacing: rootObj.s(8)
                rowSpacing: rootObj.s(8)

                Repeater {
                    model: cursorsTab.themes

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool chosen: modelData.id === cursorsTab.current
                        readonly property bool busy: modelData.id === cursorsTab.applying

                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(104)
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

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cursorsTab.choose(card.modelData.id, cursorsTab.size)
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
                                // themes you added can go again (system ones belong to packages)
                                Text {
                                    visible: card.modelData.removable && !card.chosen
                                    text: "remove"
                                    color: removeMouse.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    MouseArea {
                                        id: removeMouse
                                        anchors.fill: parent
                                        anchors.margins: -rootObj.s(4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cursorsTab.run(["remove", card.modelData.id])
                                    }
                                }
                            }

                            // what the theme's pointers look like
                            Row {
                                id: sampleRow
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: rootObj.s(10)

                                Repeater {
                                    model: card.modelData.samples.slice(0, Math.max(1, Math.floor((sampleRow.width + sampleRow.spacing) / (rootObj.s(32) + sampleRow.spacing))))
                                    Image {
                                        required property string modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: rootObj.s(32)
                                        height: rootObj.s(32)
                                        sourceSize: Qt.size(rootObj.s(64), rootObj.s(64))
                                        source: "file://" + modelData
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        WheelScroll {}
    }
}
