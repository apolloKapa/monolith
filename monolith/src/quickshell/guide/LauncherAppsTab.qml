import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Launcher -> Apps: every installed app with a switch to show or hide it in the
// launcher, the dock's app list and every other app menu (scripts/app_visibility.py: the
// standard NoDisplay, undone exactly when it's shown again).
GuideTab {
    id: appsTab

    property var apps: []
    property string query: ""
    property string mode: "all"    // all | shown | hidden
    property string busy: ""
    property string error: ""

    readonly property int hiddenCount: apps.filter(a => a.hidden).length
    readonly property var shownApps: {
        const q = query.trim().toLowerCase();
        return apps.filter(a => (mode === "all" || a.hidden === (mode === "hidden"))
            && (q === "" || String(a.name).toLowerCase().indexOf(q) >= 0 || String(a.id).toLowerCase().indexOf(q) >= 0));
    }

    function script() { return Caching.monolithDir + "/scripts/app_visibility.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    function setHidden(app, hide) {
        if (setter.running) return;
        busy = app.id;
        error = "";
        // shown at once; the list is read again when it's done
        apps = apps.map(a => a.id === app.id ? Object.assign({}, a, { hidden: hide }) : a);
        setter.command = ["python3", script(), hide ? "hide" : "show", app.id];
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
        command: ["python3", appsTab.script(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { appsTab.apps = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: setter
        stderr: StdioCollector { id: setterErr }
        onExited: function(code) {
            if (code !== 0) appsTab.error = setterErr.text.trim() || "Couldn't change it";
            appsTab.busy = "";
            appsTab.refresh();
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
                    rootObj: appsTab.rootObj
                    settingId: "launcher_apps"
                    icon: "󰀻"
                    title: "Apps"
                    description: appsTab.apps.length === 0 ? "Looking for installed apps..."
                        : appsTab.apps.length + " apps, " + appsTab.hiddenCount + " hidden. Hidden apps leave the launcher, the dock's app list and other app menus; they stay installed"
                    searchKeywords: "apps hide show hidden launcher menu entries visible applications"

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: rootObj.s(200)
                        Layout.preferredHeight: rootObj.s(32)
                        text: appsTab.query
                        placeholderText: "Search apps"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onTextEdited: newText => appsTab.query = newText
                    }
                }

                // All / Shown / Hidden
                RowLayout {
                    Layout.leftMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(4)
                    spacing: rootObj.s(6)
                    Repeater {
                        model: [{ k: "all", t: "All" }, { k: "shown", t: "Shown" }, { k: "hidden", t: "Hidden" }]
                        ClickButton {
                            required property var modelData
                            implicitHeight: rootObj.s(28)
                            horizontalPadding: rootObj.s(14)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: modelData.t + (modelData.k === "hidden" ? " (" + appsTab.hiddenCount + ")" : "")
                            textFontSize: rootObj.s(11)
                            accentColor: appsTab.mode === modelData.k ? ThemeBackend.mauve : ThemeBackend.surface1
                            textColor: appsTab.mode === modelData.k ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: appsTab.mode = modelData.k
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    visible: appsTab.error !== ""
                    text: appsTab.error
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    wrapMode: Text.WordWrap
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                Repeater {
                    model: appsTab.shownApps

                    RowLayout {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(12)
                        Layout.rightMargin: rootObj.s(12)
                        Layout.topMargin: rootObj.s(2)
                        Layout.bottomMargin: rootObj.s(2)
                        spacing: rootObj.s(12)
                        opacity: row.modelData.hidden ? 0.55 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 150 * ThemeBackend.animScale } }

                        Image {
                            Layout.preferredWidth: rootObj.s(30)
                            Layout.preferredHeight: rootObj.s(30)
                            sourceSize: Qt.size(rootObj.s(60), rootObj.s(60))
                            source: appsTab.iconUrl(row.modelData.icon)
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
                                text: row.modelData.name + (row.modelData.hidden ? "  ·  hidden" : "")
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
                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: !row.modelData.hidden
                            enabled: appsTab.busy === "" || appsTab.busy === row.modelData.id
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) { appsTab.setHidden(row.modelData, !c); }
                        }
                    }
                }

                Text {
                    Layout.leftMargin: rootObj.s(12)
                    visible: appsTab.shownApps.length === 0 && appsTab.apps.length > 0
                    text: appsTab.mode === "hidden" ? "No hidden apps" : "No apps match"
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                }
            }
        }

        WheelScroll {}
    }
}
