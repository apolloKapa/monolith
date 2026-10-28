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
GuideTab {
    id: iconsTab

    property var themes: []
    property string current: ""
    property string applying: ""
    property string error: ""

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
        }
    }
}
