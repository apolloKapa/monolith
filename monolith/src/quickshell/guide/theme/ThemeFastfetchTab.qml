import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Fastfetchlings: fastfetch looks you switch between with a click
// (scripts/fastfetch_presets.py). Presets are fastfetch configs in ~/.config/monolith/fastfetch
// that can use theme colours; you write them in a terminal editor, and each tile shows what
// fastfetch prints with it.
GuideTab {
    id: ffTab

    property var presets: []
    property string active: ""
    property string presetsDir: ""
    property bool haveFastfetch: true
    property string error: ""
    property string busy: ""          // the preset an action is running on
    property string renaming: ""      // the preset whose name is being edited
    property string confirmDelete: "" // the preset whose delete was clicked once
    property bool loaded: false

    // a Delete click arms it for a few seconds; a second click within that deletes
    onConfirmDeleteChanged: if (confirmDelete !== "") disarm.restart()
    Timer {
        id: disarm
        interval: 4000
        onTriggered: ffTab.confirmDelete = ""
    }

    readonly property string script: Caching.monolithDir + "/scripts/fastfetch_presets.py"

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    // runs one action; `then` gets the printed output (e.g. a new preset's name)
    property var _then: null
    function run(args, then) {
        if (actionProc.running) return;
        ffTab.error = "";
        ffTab.busy = args.length > 1 ? args[1] : args[0];
        ffTab._then = then || null;
        actionProc.command = ["python3", ffTab.script].concat(args);
        actionProc.running = true;
    }

    // opens the preset in a terminal editor; the tiles refresh when that terminal closes
    function edit(name) {
        ffTab.error = "";
        editProc.command = ["python3", ffTab.script, "edit", name];
        editProc.running = true;
    }

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    Process {
        id: listProc
        command: ["python3", ffTab.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    ffTab.presets = d.presets || [];
                    ffTab.active = d.active || "";
                    ffTab.presetsDir = d.dir || "";
                    ffTab.haveFastfetch = d.fastfetch !== false;
                } catch (e) {}
                ffTab.loaded = true;
            }
        }
        stderr: StdioCollector { id: listErr }
        onExited: (code) => { if (code !== 0) ffTab.error = (listErr.text || "").trim().split("\n").pop(); }
    }

    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOut }
        stderr: StdioCollector { id: actionErr }
        onExited: (code) => {
            if (code !== 0) ffTab.error = (actionErr.text || "").trim().split("\n").pop();
            else if (ffTab._then) ffTab._then((actionOut.text || "").trim());
            ffTab._then = null;
            ffTab.busy = "";
            ffTab.refresh();
        }
    }

    Process {
        id: editProc
        stderr: StdioCollector { id: editErr }
        onExited: (code) => {
            if (code !== 0 && (editErr.text || "").trim() !== "") ffTab.error = editErr.text.trim().split("\n").pop();
            ffTab.refresh();
        }
    }

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
                    rootObj: ffTab.rootObj
                    settingId: "theme_fastfetch"
                    icon: "󰍹"
                    title: "Fastfetchlings"
                    description: "Looks for fastfetch, the system summary your terminal shows. Click one to use it. "
                        + "New and Edit open the preset in a terminal editor: save and close it to see the result. Presets follow your theme colours"
                    searchKeywords: "fastfetch neofetch terminal system info presets preset logo fetch fastfetchlings"

                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "New preset"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        onClicked: ffTab.run(["new"], name => { if (name) ffTab.edit(name); })
                    }
                    ClickButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        horizontalPadding: rootObj.s(14)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: "Open folder"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        onClicked: if (ffTab.presetsDir) Quickshell.execDetached(["xdg-open", ffTab.presetsDir])
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    Layout.rightMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(10)
                    visible: ffTab.error !== "" || !ffTab.haveFastfetch
                    wrapMode: Text.WordWrap
                    text: "󰀦  " + (ffTab.error !== "" ? ffTab.error : "fastfetch isn't installed, so there are no previews (install the fastfetch package)")
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((width + columnSpacing) / (rootObj.s(320) + columnSpacing)))
                columnSpacing: rootObj.s(8)
                rowSpacing: rootObj.s(8)

                Repeater {
                    model: ffTab.presets

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property string name: modelData.name
                        readonly property bool chosen: name === ffTab.active
                        readonly property bool working: ffTab.busy === name
                        readonly property bool hovered: cardHover.hovered

                        Layout.fillWidth: true
                        Layout.preferredHeight: rootObj.s(236)
                        radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                        color: cardGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, card.hovered ? 0.7 : 0.45)
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

                        HoverHandler { id: cardHover }

                        // a click anywhere but the buttons uses the preset
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!card.chosen && ffTab.renaming !== card.name) ffTab.run(["apply", card.name])
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: rootObj.s(10)
                            spacing: rootObj.s(8)

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: rootObj.s(24)
                                spacing: rootObj.s(6)

                                Text {
                                    Layout.fillWidth: true
                                    visible: ffTab.renaming !== card.name
                                    text: card.name
                                    elide: Text.ElideRight
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(13)
                                    font.bold: true
                                }

                                // rename: type the new name, Enter keeps it, Esc or clicking away drops it
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: rootObj.s(24)
                                    visible: ffTab.renaming === card.name
                                    radius: ThemeBackend.rad(rootObj.s(6))
                                    color: ThemeBackend.surface1
                                    border.width: 1
                                    border.color: ThemeBackend.mauve

                                    TextInput {
                                        id: renameInput
                                        anchors.fill: parent
                                        anchors.leftMargin: rootObj.s(7)
                                        anchors.rightMargin: rootObj.s(7)
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                        selectByMouse: true
                                        maximumLength: 60
                                        clip: true
                                        onVisibleChanged: if (visible) { text = card.name; selectAll(); forceActiveFocus(); }
                                        onAccepted: {
                                            const n = text.trim();
                                            ffTab.renaming = "";
                                            if (n !== "" && n !== card.name) ffTab.run(["rename", card.name, n]);
                                        }
                                        onActiveFocusChanged: if (!activeFocus && ffTab.renaming === card.name) ffTab.renaming = ""
                                        Keys.onEscapePressed: ffTab.renaming = ""
                                    }
                                }

                                Text {
                                    visible: card.chosen || card.working
                                    text: card.working ? "working..." : "in use"
                                    color: card.chosen ? ThemeBackend.mauve : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                }
                            }

                            // what fastfetch prints with this preset, scaled down to fit
                            Rectangle {
                                id: screen
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: ThemeBackend.rad(rootObj.s(6))
                                color: Qt.alpha(ThemeBackend.crust, 0.85)
                                clip: true

                                Text {
                                    id: preview
                                    anchors.centerIn: parent
                                    readonly property real fit: Math.min(1, (screen.width - rootObj.s(16)) / Math.max(1, implicitWidth), (screen.height - rootObj.s(16)) / Math.max(1, implicitHeight))
                                    scale: fit
                                    textFormat: Text.RichText
                                    text: card.modelData.preview || ""
                                    color: ThemeBackend.text
                                    font.family: "Iosevka Nerd Font"   // the installer puts it in, with every Nerd Font icon
                                    font.pixelSize: rootObj.s(11)
                                    lineHeight: 1.0
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: (card.modelData.preview || "") === ""
                                    text: ffTab.haveFastfetch ? "no preview" : "install fastfetch for a preview"
                                    color: ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: rootObj.s(4)

                                Repeater {
                                    model: [
                                        { id: "edit", icon: "󰏫", label: "Edit" },
                                        { id: "duplicate", icon: "󰆏", label: "Duplicate" },
                                        { id: "rename", icon: "󰑕", label: "Rename" },
                                        { id: "delete", icon: "󰆴", label: "Delete" }
                                    ]

                                    Rectangle {
                                        id: act
                                        required property var modelData
                                        readonly property bool danger: modelData.id === "delete"
                                        readonly property bool armed: danger && ffTab.confirmDelete === card.name
                                        visible: !(danger && ffTab.presets.length <= 1)
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: rootObj.s(26)
                                        radius: ThemeBackend.rad(rootObj.s(6))
                                        color: armed ? ThemeBackend.red
                                            : Qt.alpha(actMouse.containsMouse ? (danger ? ThemeBackend.red : ThemeBackend.surface2) : ThemeBackend.surface1, actMouse.containsMouse && danger ? 0.35 : 0.8)
                                        Behavior on color { ColorAnimation { duration: 120 * ThemeBackend.animScale } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: rootObj.s(5)
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: act.modelData.icon
                                                color: act.armed ? ThemeBackend.crust : ThemeBackend.text
                                                font.family: ThemeBackend.iconFont
                                                font.pixelSize: rootObj.s(13)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                // "Sure?" here, not in the model: changing the model rebuilds the buttons,
                                                // and the old Delete's exit handler disarmed it before the second click
                                                text: act.armed ? "Sure?" : act.modelData.label
                                                color: act.armed ? ThemeBackend.crust : ThemeBackend.text
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(11)
                                            }
                                        }

                                        MouseArea {
                                            id: actMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const id = act.modelData.id;
                                                if (id !== "delete") ffTab.confirmDelete = "";
                                                if (id === "edit") ffTab.edit(card.name);
                                                else if (id === "duplicate") ffTab.run(["duplicate", card.name]);
                                                else if (id === "rename") ffTab.renaming = card.name;
                                                else if (act.armed) { ffTab.confirmDelete = ""; ffTab.run(["delete", card.name]); }
                                                else ffTab.confirmDelete = card.name;
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

        WheelScroll {}
    }
}
