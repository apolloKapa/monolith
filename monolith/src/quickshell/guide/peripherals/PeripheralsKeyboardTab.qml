import QtQuick
import QtQuick.Layouts
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Peripherals -> Keyboard: niri's input { keyboard { } }: layouts (xkb), the
// shortcut that switches between them, key repeat and Num Lock, through PeripheralsConfig.
GuideTab {
    id: kbTab

    readonly property var st: cfg.state
    readonly property var kb: st ? st.keyboard : ({ layouts: ["us"], shortcut: "none", delay: 600, rate: 25, numlock: false })
    readonly property var keyboards: st ? st.devices.keyboards : []
    readonly property var shortcuts: st ? st.shortcuts : []
    readonly property var layoutNames: {
        let m = {};
        for (const l of (st ? st.allLayouts : [])) m[l.id] = l.name;
        return m;
    }
    // the ones you can still add
    readonly property var addable: (st ? st.allLayouts : []).filter(l => kb.layouts.indexOf(l.id) < 0)

    PeripheralsConfig { id: cfg }

    onIsCurrentChanged: if (isCurrent) cfg.refresh()

    function setLayouts(list) { cfg.set("keyboard", "layouts", list.join(",")); }

    component OnOff: Toggle {
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
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
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_connected"
                    icon: "󰌌"
                    title: kbTab.keyboards.length === 1 ? "Your keyboard" : "Your keyboards"
                    description: !kbTab.st ? "Looking for keyboards..."
                        : kbTab.keyboards.length > 0 ? kbTab.keyboards.join(", ")
                        : "No keyboard found. These settings still apply to any you plug in"
                    searchKeywords: "keyboard keyboards connected device wooting"
                }

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_layouts"
                    icon: "󰗊"
                    title: "Layouts"
                    description: "The languages you type in. The first one is used when you log in"
                    searchKeywords: "keyboard layout layouts language input xkb greek us english qwerty azerty add"

                    Dropdown {
                        id: addLayout
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(200)
                        implicitHeight: rootObj.s(32)
                        options: kbTab.addable.map(l => l.name)
                        currentIndex: -1
                        placeholderText: "Add a layout..."
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        onValueChanged: function(index, value) {
                            const l = kbTab.addable[index];
                            if (l) kbTab.setLayouts(kbTab.kb.layouts.concat([l.id]));
                            Qt.callLater(function() { addLayout.currentIndex = -1; });
                        }
                    }
                }

                // the layouts in use, in order; click one to make it the first
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    Layout.rightMargin: rootObj.s(12)
                    Layout.bottomMargin: rootObj.s(6)
                    spacing: rootObj.s(6)

                    Repeater {
                        model: kbTab.kb.layouts

                        Rectangle {
                            id: chip
                            required property string modelData
                            required property int index
                            readonly property bool first: index === 0

                            height: rootObj.s(30)
                            width: chipRow.implicitWidth + rootObj.s(20)
                            radius: ThemeBackend.rad(ThemeBackend.borderRadius)
                            color: Qt.alpha(first ? ThemeBackend.mauve : ThemeBackend.surface0, first ? 0.18 : (chipMouse.containsMouse ? 0.75 : 0.5))
                            border.width: 1
                            border.color: first ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface1, 0.6)

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: chip.first ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (chip.first) return;
                                    let l = kbTab.kb.layouts.slice();
                                    l.splice(chip.index, 1);
                                    kbTab.setLayouts([chip.modelData].concat(l));
                                }
                            }

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: rootObj.s(8)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (kbTab.layoutNames[chip.modelData] || chip.modelData) + (chip.first ? "  ·  first" : "")
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(12)
                                }
                                // the last one stays: niri needs a layout
                                Text {
                                    visible: kbTab.kb.layouts.length > 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    color: removeMouse.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)

                                    MouseArea {
                                        id: removeMouse
                                        anchors.fill: parent
                                        anchors.margins: -rootObj.s(5)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let l = kbTab.kb.layouts.slice();
                                            l.splice(chip.index, 1);
                                            kbTab.setLayouts(l);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_switch"
                    icon: "󰯍"
                    title: "Switch layouts with"
                    description: kbTab.kb.layouts.length > 1
                        ? "The keys that change to the next layout. The bar's keyboard button does it too"
                        : "Add a second layout to switch between them"
                    searchKeywords: "keyboard layout switch shortcut toggle alt shift super space caps lock language"

                    Dropdown {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(160)
                        implicitHeight: rootObj.s(32)
                        options: kbTab.shortcuts.map(s => s.name)
                        currentIndex: Math.max(0, kbTab.shortcuts.findIndex(s => s.id === kbTab.kb.shortcut))
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        onValueChanged: function(index, value) {
                            const s = kbTab.shortcuts[index];
                            if (s && s.id !== kbTab.kb.shortcut) cfg.set("keyboard", "shortcut", s.id);
                        }
                    }
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_delay"
                    icon: "󰔛"
                    title: "Repeat delay"
                    description: "How long to hold a key before it starts repeating"
                    searchKeywords: "keyboard key repeat delay hold wait"

                    PeripheralSlider {
                        rootObj: kbTab.rootObj
                        from: 150
                        to: 1000
                        stepSize: 25
                        defaultValue: 600
                        valueFormatter: function(v) { return Math.round(v) + " ms" }
                        current: kbTab.kb.delay
                        onCommit: function(v) { cfg.set("keyboard", "delay", Math.round(v)); }
                    }
                }

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_rate"
                    icon: "󰓅"
                    title: "Repeat speed"
                    description: "How many times a second a held key repeats"
                    searchKeywords: "keyboard key repeat rate speed fast"

                    PeripheralSlider {
                        rootObj: kbTab.rootObj
                        from: 10
                        to: 80
                        stepSize: 1
                        defaultValue: 25
                        valueFormatter: function(v) { return Math.round(v) + " per second" }
                        current: kbTab.kb.rate
                        onCommit: function(v) { cfg.set("keyboard", "rate", Math.round(v)); }
                    }
                }

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_try"
                    icon: "󰏪"
                    title: "Try it"
                    description: "Hold a key here to feel the repeat settings"
                    searchKeywords: "keyboard test try type repeat"

                    Input {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(220)
                        implicitHeight: rootObj.s(32)
                        placeholderText: "Type here..."
                        accentColor: ThemeBackend.mauve
                        cornerRadius: ThemeBackend.borderRadius
                    }
                }

                SettingsRow {
                    rootObj: kbTab.rootObj
                    settingId: "keyboard_numlock"
                    icon: "󰎠"
                    title: "Num Lock on at login"
                    description: "The number pad types numbers straight away"
                    searchKeywords: "keyboard num lock numlock numpad number pad"

                    OnOff {
                        checked: kbTab.kb.numlock
                        onToggled: function(c) { cfg.set("keyboard", "numlock", c ? "on" : "off"); }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: rootObj.s(12)
                    visible: cfg.error !== ""
                    text: cfg.error
                    color: ThemeBackend.red
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
