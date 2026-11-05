import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Software -> Autostart: every installed app with a switch to start it when you log
// in. scripts/autostart.py keeps the choice in the standard ~/.config/autostart folder, and
// monolithd starts those apps once per login.
GuideTab {
    id: autostartTab

    property var apps: []
    property string query: ""
    property string mode: "all"    // all | on
    property string busy: ""
    property string error: ""

    readonly property int onCount: apps.filter(a => a.on).length
    readonly property var shownApps: {
        const q = query.trim().toLowerCase();
        return apps.filter(a => (mode === "all" || a.on)
            && (q === "" || String(a.name).toLowerCase().indexOf(q) >= 0 || String(a.id).toLowerCase().indexOf(q) >= 0));
    }

    function script() { return Caching.monolithDir + "/scripts/autostart.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    function setOn(app, on) {
        if (setter.running) return;
        busy = app.id;
        error = "";
        // shown at once; the list is read again when it's done
        apps = apps.map(a => a.id === app.id ? Object.assign({}, a, { on: on }) : a);
        setter.command = ["python3", script(), on ? "on" : "off", app.id];
        setter.running = true;
    }

    // start in the tray instead of a window (Steam's -silent, Discord's --start-minimized, ...)
    function setMinimized(app, on) {
        if (setter.running) return;
        busy = app.id;
        error = "";
        apps = apps.map(a => a.id === app.id ? Object.assign({}, a, { minimized: on, on: true }) : a);
        setter.command = ["python3", script(), "minimized", app.id, on ? "on" : "off"];
        setter.running = true;
    }

    function iconUrl(ic) {
        if (!ic) return "image://icon/application-x-executable";
        ic = String(ic);
        if (ic.startsWith("/")) return "file://" + ic;
        const p = Quickshell.iconPath(ic, true);
        return p ? (p.startsWith("/") ? "file://" + p : p) : "image://icon/" + ic;
    }

    Process {
        id: lister
        command: ["python3", autostartTab.script(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { autostartTab.apps = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: setter
        stderr: StdioCollector { id: setterErr }
        onExited: function(code) {
            if (code !== 0) autostartTab.error = setterErr.text.trim() || "Couldn't change it";
            autostartTab.busy = "";
            autostartTab.refresh();
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
                    rootObj: autostartTab.rootObj
                    settingId: "autostart_apps"
                    icon: "󰐥"
                    title: "Start at login"
                    description: autostartTab.apps.length === 0 ? "Looking for installed apps..."
                        : (autostartTab.onCount === 0 ? "No apps start when you log in. "
                            : (autostartTab.onCount === 1 ? "1 app starts" : autostartTab.onCount + " apps start") + " when you log in. ")
                          + "Turn an app on and it opens by itself next time. Steam, Discord and a few others can start minimized, in the tray"
                    searchKeywords: "autostart startup start login boot launch open automatically apps"

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: rootObj.s(200)
                        Layout.preferredHeight: rootObj.s(32)
                        text: autostartTab.query
                        placeholderText: "Search apps"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onTextEdited: newText => autostartTab.query = newText
                    }
                }

                // All / On
                RowLayout {
                    Layout.leftMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(4)
                    spacing: rootObj.s(6)
                    Repeater {
                        model: [{ k: "all", t: "All" }, { k: "on", t: "Starts at login" }]
                        ClickButton {
                            required property var modelData
                            implicitHeight: rootObj.s(28)
                            horizontalPadding: rootObj.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: modelData.t + (modelData.k === "on" ? " (" + autostartTab.onCount + ")" : "")
                            textFontSize: rootObj.s(11)
                            accentColor: autostartTab.mode === modelData.k ? ThemeBackend.mauve : ThemeBackend.surface1
                            textColor: autostartTab.mode === modelData.k ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: autostartTab.mode = modelData.k
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    visible: autostartTab.error !== ""
                    text: autostartTab.error
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    wrapMode: Text.WordWrap
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                Repeater {
                    model: autostartTab.shownApps

                    RowLayout {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(12)
                        Layout.rightMargin: rootObj.s(12)
                        Layout.topMargin: rootObj.s(2)
                        Layout.bottomMargin: rootObj.s(2)
                        spacing: rootObj.s(12)

                        Image {
                            Layout.preferredWidth: rootObj.s(30)
                            Layout.preferredHeight: rootObj.s(30)
                            sourceSize: Qt.size(rootObj.s(60), rootObj.s(60))
                            source: autostartTab.iconUrl(row.modelData.icon)
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
                                text: row.modelData.name + (row.modelData.on ? "  ·  starts at login" : "")
                                elide: Text.ElideRight
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.comment || ""
                                elide: Text.ElideRight
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                            }
                        }
                        // only for apps that have their own start-in-the-tray option
                        ClickButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            visible: row.modelData.canMinimize === true && row.modelData.on
                            enabled: autostartTab.busy === "" || autostartTab.busy === row.modelData.id
                            implicitHeight: rootObj.s(26)
                            horizontalPadding: rootObj.s(12)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: row.modelData.minimized ? "󰖰  Minimized" : "󰖯  Opens a window"
                            textFontSize: rootObj.s(10)
                            accentColor: row.modelData.minimized ? ThemeBackend.mauve : ThemeBackend.surface1
                            textColor: row.modelData.minimized ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: autostartTab.setMinimized(row.modelData, !row.modelData.minimized)
                        }
                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: row.modelData.on
                            enabled: autostartTab.busy === "" || autostartTab.busy === row.modelData.id
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) { autostartTab.setOn(row.modelData, c); }
                        }
                    }
                }

                Text {
                    Layout.leftMargin: rootObj.s(12)
                    visible: autostartTab.shownApps.length === 0 && autostartTab.apps.length > 0
                    text: autostartTab.mode === "on" ? "No apps start at login yet" : "No apps match"
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                }
            }
        }

        WheelScroll {}
    }
}
