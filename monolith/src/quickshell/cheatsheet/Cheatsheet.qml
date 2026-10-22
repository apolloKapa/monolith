import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Keybind cheatsheet (monolith msg toggle cheatsheet): every niri keybind, read from your
// config each time it opens (scripts/niri_keybinds.py), grouped and searchable.
PopupShell {
    id: root

    property var binds: []
    property string query: ""
    readonly property var groups: {
        let q = root.query.trim().toLowerCase();
        let out = [];
        let byName = {};
        for (let b of root.binds) {
            if (q !== "" && (b.desc + " " + b.keys.join("+") + " " + b.group).toLowerCase().indexOf(q) === -1) continue;
            if (!byName[b.group]) {
                byName[b.group] = { name: b.group, items: [] };
                out.push(byName[b.group]);
            }
            byName[b.group].items.push(b);
        }
        return out;
    }

    onOpened: {
        search.clear();
        search.focusField();
        loader.running = true;
    }

    Process {
        id: loader
        command: ["python3", Caching.monolithDir + "/scripts/niri_keybinds.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.binds = JSON.parse(this.text); } catch (e) { root.binds = []; }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(14)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(14)

            Text {
                text: I18n.t("cheatsheet.title", "Keybinds")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(22)
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: I18n.t("cheatsheet.source", "from ~/.config/niri/config/keybinds.kdl")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                elide: Text.ElideRight
            }
            SearchBox {
                id: search
                Layout.preferredWidth: root.s(320)
                placeholderText: I18n.t("cheatsheet.search", "Search keys or actions…")
                onTextChanged: root.query = text
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: flow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // groups shared out over columns by height (each next group goes to the shortest
            // column), like a printed cheatsheet
            readonly property int nCols: Math.max(1, Math.floor((width + root.s(12)) / (root.s(360) + root.s(12))))
            readonly property var columns: {
                let cols = [], heights = [];
                for (let i = 0; i < nCols; i++) { cols.push([]); heights.push(0); }
                for (let g of root.groups) {
                    let k = heights.indexOf(Math.min.apply(null, heights));
                    cols[k].push(g);
                    heights[k] += g.items.length + 2;
                }
                return cols;
            }

            Row {
                id: flow
                width: flick.width
                spacing: root.s(12)
                readonly property real colWidth: (width - (flick.nCols - 1) * spacing) / flick.nCols

                Repeater {
                    model: flick.columns

                    Column {
                        id: column
                        required property var modelData
                        width: flow.colWidth
                        spacing: root.s(12)

                        Repeater {
                            model: column.modelData

                            Rectangle {
                                id: card
                                required property var modelData
                                width: column.width
                                height: cardCol.implicitHeight + root.s(24)
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface0, Math.max(0.45, ThemeBackend.elementOpacity * 0.6))
                                border.width: ThemeBackend.outlined ? ThemeBackend.outlineInner : 0
                                border.color: ThemeBackend.outlineColor

                                ColumnLayout {
                                    id: cardCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.s(12)
                                    spacing: root.s(6)

                                    Text {
                                        text: card.modelData.name
                                        color: ThemeBackend.mauve
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: root.s(13)
                                        font.weight: Font.Bold
                                        Layout.bottomMargin: root.s(2)
                                    }

                                    Repeater {
                                        model: card.modelData.items

                                        RowLayout {
                                            id: row
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: root.s(4)

                                            Repeater {
                                                model: row.modelData.keys
                                                Rectangle {
                                                    required property string modelData
                                                    Layout.preferredHeight: root.s(22)
                                                    Layout.preferredWidth: Math.max(root.s(22), keyText.implicitWidth + root.s(12))
                                                    radius: ThemeBackend.rad(root.s(5))
                                                    color: ThemeBackend.surface1
                                                    border.width: 1
                                                    border.color: Qt.alpha(ThemeBackend.text, 0.12)
                                                    Text {
                                                        id: keyText
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        color: ThemeBackend.text
                                                        font.family: ThemeBackend.fontFamily
                                                        font.pixelSize: root.s(11)
                                                        font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: root.s(6)
                                                text: row.modelData.desc
                                                color: ThemeBackend.subtext1
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: root.s(12)
                                                elide: Text.ElideRight
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.groups.length === 0 && root.binds.length > 0
            text: I18n.t("cheatsheet.none", "No keybind matches")
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13)
        }
    }
}
