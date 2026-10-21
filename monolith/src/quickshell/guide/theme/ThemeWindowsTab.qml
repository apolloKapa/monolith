import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Windows: niri window borders (on/off, width, colours or follow the theme).
// Stored as windows.borders = { enabled, width, active, inactive, urgent, followTheme } and
// written into niri's layout { border { } } by scripts/niri_borders.sh.
GuideTab {
    id: winTab

    readonly property bool niriSession: NiriState.isNiri

    property bool bordersOn: true
    property int borderWidth: 2
    property string activeColor: "#ffffff"
    property string inactiveColor: "#555555"
    property string urgentColor: "#9b0000"
    property bool followTheme: false

    // what the swatches offer: the theme's colours (no duplicates), topped up with a fixed
    // palette so a monochrome theme still offers some colour
    readonly property var swatches: {
        const theme = [ThemeBackend.text, ThemeBackend.mauve, ThemeBackend.blue, ThemeBackend.green,
                       ThemeBackend.peach, ThemeBackend.red, ThemeBackend.surface2].map(c => ThemeBackend.hexColor(c));
        const extra = ["#ffffff", "#555555", "#000000", "#89b4fa", "#a6e3a1", "#f9e2af", "#f38ba8", "#cba6f7", "#fab387"];
        let out = [];
        for (const c of theme.concat(extra)) {
            if (out.indexOf(c.toLowerCase()) === -1) out.push(c.toLowerCase());
            if (out.length === 10) break;
        }
        return out;
    }

    function shownColor(which) {
        if (followTheme) return ThemeBackend.themeBorderColors()[which];
        return which === "active" ? activeColor : (which === "inactive" ? inactiveColor : urgentColor);
    }

    function load() {
        const b = (Config.getSetting("windows", {}).borders);
        if (b) {
            bordersOn = b.enabled !== false;
            borderWidth = b.width !== undefined ? Number(b.width) : 2;
            activeColor = b.active || activeColor;
            inactiveColor = b.inactive || inactiveColor;
            urgentColor = b.urgent || urgentColor;
            followTheme = b.followTheme === true;
        } else if (niriSession && Caching.monolithDir) {
            // nothing saved yet: start from what niri is using now
            currentReader.running = true;
        }
    }

    function save() {
        Config.setSetting("windows", Object.assign({}, Config.getSetting("windows", {}), {
            "borders": {
                "enabled": bordersOn, "width": borderWidth, "active": activeColor,
                "inactive": inactiveColor, "urgent": urgentColor, "followTheme": followTheme
            }
        }));
        if (!niriSession || !Caching.monolithDir) return;
        Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/niri_borders.sh", "set",
            "enabled=" + (bordersOn ? 1 : 0), "width=" + borderWidth,
            "active=" + shownColor("active"), "inactive=" + shownColor("inactive"), "urgent=" + shownColor("urgent")]);
    }

    function validHex(t) { return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t); }

    function setColor(which, hex) {
        if (!validHex(hex)) return;
        if (which === "active") activeColor = hex;
        else if (which === "inactive") inactiveColor = hex;
        else urgentColor = hex;
        saveDebounce.restart();
    }

    Process {
        id: currentReader
        command: ["bash", Caching.monolithDir + "/scripts/niri_borders.sh", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(this.text);
                    winTab.bordersOn = c.enabled !== false;
                    winTab.borderWidth = Number(c.width) || 2;
                    winTab.activeColor = c.active;
                    winTab.inactiveColor = c.inactive;
                    winTab.urgentColor = c.urgent;
                } catch (e) {}
            }
        }
    }

    Timer {
        id: saveDebounce
        interval: 300
        onTriggered: winTab.save()
    }

    Component.onCompleted: load()
    Connections {
        target: Config
        function onSettingsLoaded() { winTab.load(); }
    }

    component ColorRow: SettingsRow {
        id: colorRow
        required property string which
        rootObj: winTab.rootObj
        hiddenByConfig: !winTab.niriSession || !winTab.bordersOn || winTab.followTheme

        Row {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: rootObj.s(5)

            Repeater {
                model: winTab.swatches
                Rectangle {
                    required property string modelData
                    width: rootObj.s(20)
                    height: rootObj.s(20)
                    anchors.verticalCenter: parent.verticalCenter
                    radius: ThemeBackend.minimalist ? 0 : width / 2
                    color: modelData
                    border.width: winTab.shownColor(colorRow.which).toLowerCase() === modelData.toLowerCase() ? 2 : 1
                    border.color: winTab.shownColor(colorRow.which).toLowerCase() === modelData.toLowerCase() ? ThemeBackend.text : Qt.alpha(ThemeBackend.surface2, 0.8)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: winTab.setColor(colorRow.which, modelData)
                    }
                }
            }
        }

        Input {
            id: hexInput
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: rootObj.s(96)
            Layout.preferredHeight: rootObj.s(30)
            text: winTab.shownColor(colorRow.which)
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: winTab.validHex(text) ? ThemeBackend.text : ThemeBackend.red
            subTextColor: ThemeBackend.subtext0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onTextEdited: newText => winTab.setColor(colorRow.which, newText.trim())
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

            // preview: an unfocused and a focused window with the current borders
            SettingsBlob {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rootObj.s(120)

                    Row {
                        anchors.centerIn: parent
                        spacing: rootObj.s(18)

                        Repeater {
                            model: ["inactive", "active"]
                            Rectangle {
                                required property string modelData
                                width: rootObj.s(170)
                                height: rootObj.s(90)
                                color: ThemeBackend.surface0
                                radius: ThemeBackend.minimalist ? 0 : rootObj.s(8)
                                border.width: winTab.bordersOn ? Math.max(1, winTab.borderWidth) : 0
                                border.color: winTab.shownColor(modelData)
                                Behavior on border.color { ColorAnimation { duration: 150 * ThemeBackend.animScale } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: rootObj.s(4)
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData === "active" ? "focused" : "unfocused"
                                        color: ThemeBackend.text
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(12)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: winTab.bordersOn ? winTab.shownColor(modelData) : "no border"
                                        color: ThemeBackend.subtext0
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: rootObj.s(10)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: winTab.rootObj
                    settingId: "window_borders"
                    icon: "󰹑"
                    title: "Window borders"
                    description: winTab.niriSession ? "Draw a border around every window" : "Only available on niri"
                    searchKeywords: "window border borders outline frame niri"

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: winTab.bordersOn
                        enabled: winTab.niriSession
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            winTab.bordersOn = val;
                            winTab.save();
                        }
                    }
                }

                SettingsRow {
                    rootObj: winTab.rootObj
                    settingId: "window_border_width"
                    icon: "󰡎"
                    title: "Border width"
                    description: "Thickness in pixels"
                    searchKeywords: "window border width thickness size pixels"
                    hiddenByConfig: !winTab.niriSession || !winTab.bordersOn

                    NumberSelector {
                        implicitWidth: rootObj.s(150)
                        implicitHeight: rootObj.s(32)
                        from: 1
                        to: 10
                        stepSize: 1
                        decimals: 0
                        suffix: "px"
                        value: winTab.borderWidth
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
                            const w = Math.round(val);
                            if (w >= 1 && w <= 10 && w !== winTab.borderWidth) {
                                winTab.borderWidth = w;
                                saveDebounce.restart();
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: winTab.rootObj
                    settingId: "window_border_follow_theme"
                    icon: "󰏘"
                    title: "Follow theme colours"
                    description: "Accent for the focused window, a surface tone for the rest. Updates with the theme"
                    searchKeywords: "window border colour color theme accent match"
                    hiddenByConfig: !winTab.niriSession || !winTab.bordersOn

                    Toggle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: winTab.followTheme
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(val) {
                            winTab.followTheme = val;
                            winTab.save();
                        }
                    }
                }
            }

            SettingsBlob {
                Layout.fillWidth: true
                visible: winTab.niriSession && winTab.bordersOn && !winTab.followTheme

                ColorRow {
                    which: "active"
                    settingId: "window_border_active"
                    icon: "󰋙"
                    title: "Focused window"
                    description: "Border of the window you're using"
                    searchKeywords: "window border colour color active focused"
                }

                ColorRow {
                    which: "inactive"
                    settingId: "window_border_inactive"
                    icon: "󰋘"
                    title: "Other windows"
                    description: "Border of every other window"
                    searchKeywords: "window border colour color inactive unfocused"
                }

                ColorRow {
                    which: "urgent"
                    settingId: "window_border_urgent"
                    icon: "󰀦"
                    title: "Needs attention"
                    description: "Windows asking for attention"
                    searchKeywords: "window border colour color urgent attention"
                }
            }
        }
    }
}
