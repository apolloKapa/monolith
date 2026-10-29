import QtQuick
import QtQuick.Layouts
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Peripherals -> Mouse: niri's input { mouse { } } (and touchpad { } on PCs that
// have one) through PeripheralsConfig. niri applies every change straight away.
GuideTab {
    id: mouseTab

    readonly property var st: cfg.state
    readonly property var mouse: st ? st.mouse : ({ speed: 0, flat: true, natural: false, lefthanded: false, middle: false, scroll: 1 })
    readonly property var pad: st ? st.touchpad : ({ speed: 0, tap: false, natural: false, dwt: false })
    readonly property var mice: st ? st.devices.mice : []
    readonly property var touchpads: st ? st.devices.touchpads : []

    PeripheralsConfig { id: cfg }

    // the config may have been edited elsewhere since the page was last open
    onIsCurrentChanged: if (isCurrent) cfg.refresh()

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
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_connected"
                    icon: "󰍽"
                    title: mouseTab.mice.length === 1 ? "Your mouse" : "Your mice"
                    description: !mouseTab.st ? "Looking for mice..."
                        : mouseTab.mice.length > 0 ? mouseTab.mice.join(", ")
                        : "No mouse found. These settings still apply to any you plug in"
                    searchKeywords: "mouse mice connected device usb wireless"
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_speed"
                    icon: "󰓅"
                    title: "Pointer speed"
                    description: "How far the pointer moves for the same hand movement. Double-click the slider to reset"
                    searchKeywords: "mouse pointer speed sensitivity dpi fast slow accel-speed"

                    PeripheralSlider {
                        rootObj: mouseTab.rootObj
                        from: -100
                        to: 100
                        stepSize: 5
                        defaultValue: 0
                        valueFormatter: function(v) { return (v > 0 ? "+" : "") + Math.round(v) + "%" }
                        current: Math.round(mouseTab.mouse.speed * 100)
                        onCommit: function(v) { cfg.set("mouse", "speed", (v / 100).toFixed(2)); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_accel"
                    icon: "󰁜"
                    title: "Mouse acceleration"
                    description: "On: moving fast takes the pointer further. Off: the same hand movement always moves it the same distance (what most players want in games)"
                    searchKeywords: "mouse acceleration accel profile flat adaptive raw input gaming precision"

                    OnOff {
                        checked: !mouseTab.mouse.flat
                        onToggled: function(c) { cfg.set("mouse", "flat", c ? "off" : "on"); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_scroll"
                    icon: "󰡏"
                    title: "Scroll speed"
                    description: "How far one notch of the wheel scrolls"
                    searchKeywords: "mouse scroll wheel speed factor lines"

                    PeripheralSlider {
                        rootObj: mouseTab.rootObj
                        from: 0.25
                        to: 3
                        stepSize: 0.05
                        defaultValue: 1
                        valueFormatter: function(v) { return v.toFixed(2).replace(/0$/, "") + "×" }
                        current: mouseTab.mouse.scroll
                        onCommit: function(v) { cfg.set("mouse", "scroll", v.toFixed(2)); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_natural"
                    icon: "󰯎"
                    title: "Natural scrolling"
                    description: "Scrolling moves the page instead of the view, like on a phone"
                    searchKeywords: "mouse natural scrolling reverse invert direction"

                    OnOff {
                        checked: mouseTab.mouse.natural
                        onToggled: function(c) { cfg.set("mouse", "natural", c ? "on" : "off"); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_lefthanded"
                    icon: "󰳽"
                    title: "Left-handed"
                    description: "Swap the left and right buttons"
                    searchKeywords: "mouse left handed swap buttons primary right"

                    OnOff {
                        checked: mouseTab.mouse.lefthanded
                        onToggled: function(c) { cfg.set("mouse", "lefthanded", c ? "on" : "off"); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "mouse_middle"
                    icon: "󰍽"
                    title: "Middle click with both buttons"
                    description: "Pressing left and right together counts as a middle click, for mice without a wheel button"
                    searchKeywords: "mouse middle click emulation both buttons paste"

                    OnOff {
                        checked: mouseTab.mouse.middle
                        onToggled: function(c) { cfg.set("mouse", "middle", c ? "on" : "off"); }
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

            // only on PCs with a touchpad (laptops)
            SettingsBlob {
                Layout.fillWidth: true
                visible: mouseTab.touchpads.length > 0

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "touchpad_speed"
                    icon: "󰟸"
                    title: "Touchpad speed"
                    description: mouseTab.touchpads.join(", ")
                    searchKeywords: "touchpad trackpad speed sensitivity laptop"

                    PeripheralSlider {
                        rootObj: mouseTab.rootObj
                        from: -100
                        to: 100
                        stepSize: 5
                        defaultValue: 0
                        valueFormatter: function(v) { return (v > 0 ? "+" : "") + Math.round(v) + "%" }
                        current: Math.round(mouseTab.pad.speed * 100)
                        onCommit: function(v) { cfg.set("touchpad", "speed", (v / 100).toFixed(2)); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "touchpad_tap"
                    icon: "󰟸"
                    title: "Tap to click"
                    description: "A light tap on the touchpad clicks, without pressing it down"
                    searchKeywords: "touchpad trackpad tap to click laptop"

                    OnOff {
                        checked: mouseTab.pad.tap
                        onToggled: function(c) { cfg.set("touchpad", "tap", c ? "on" : "off"); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "touchpad_natural"
                    icon: "󰯎"
                    title: "Natural scrolling on the touchpad"
                    description: "Two fingers move the page, like on a phone"
                    searchKeywords: "touchpad trackpad natural scrolling reverse invert laptop"

                    OnOff {
                        checked: mouseTab.pad.natural
                        onToggled: function(c) { cfg.set("touchpad", "natural", c ? "on" : "off"); }
                    }
                }

                SettingsRow {
                    rootObj: mouseTab.rootObj
                    settingId: "touchpad_dwt"
                    icon: "󰌌"
                    title: "Ignore the touchpad while typing"
                    description: "So a palm brushing it doesn't move the pointer mid-sentence"
                    searchKeywords: "touchpad trackpad disable while typing palm dwt laptop"

                    OnOff {
                        checked: mouseTab.pad.dwt
                        onToggled: function(c) { cfg.set("touchpad", "dwt", c ? "on" : "off"); }
                    }
                }
            }
        }
    }
}
