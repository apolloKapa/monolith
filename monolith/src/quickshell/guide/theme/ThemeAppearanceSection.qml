import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property alias fontDropdown: fontDropdown

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "font"
        icon: "󰛖"
        title: I18n.t("guide.theme.font.title")
        description: I18n.t("guide.theme.font.desc")
        searchKeywords: "font typeface family typography text"

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: ThemeBackend.rad(rootObj.s(6))
            buttonIcon: "󰉋"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: {
                let userFontsPath = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/monolith/fonts");
                let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(userFontsPath) + "\" && xdg-open \"" + escapeBash(userFontsPath) + "\""]);
            }
        }

        IconButton {
            Layout.preferredWidth: rootObj.s(32)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            cornerRadius: ThemeBackend.rad(rootObj.s(6))
            buttonIcon: "󰐕"
            iconFontSize: rootObj.s(14)
            accentColor: ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
            onClicked: section.tab.fontPickerPopup.openPicker()
        }

        Dropdown {
            id: fontDropdown
            Layout.preferredWidth: rootObj.s(220)
            Layout.preferredHeight: rootObj.s(32)
            Layout.alignment: Qt.AlignVCenter
            options: section.tab.availableFonts
            currentIndex: options.indexOf(section.tab.currentFontFamily) >= 0 ? options.indexOf(section.tab.currentFontFamily) : 0
            placeholderText: I18n.t("guide.theme.font.select")
            fontFamily: ThemeBackend.fontFamily
            useOptionAsFontFamily: true
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            hoverColor: ThemeBackend.surface1
            dropdownColor: ThemeBackend.surface0
            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: rootObj.s(11)
            onValueChanged: function(index, value) {
                section.tab.currentFontFamily = value;
                section.tab.updateFontSetting();
            }
            onClicked: {
                section.tab.loadAvailableFonts();
            }
        }
    }

    SettingsRow {
        id: radiusRow
        rootObj: section.tab.rootObj
        settingId: "border_radius"
        visible: !ThemeBackend.styles[section.tab.currentBlurStyle].square
        icon: "󰞁"
        title: I18n.t("guide.theme.radius.title")
        description: I18n.t("guide.theme.radius.desc")
        searchKeywords: "border radius corner round curvature rounding px"

        controlSpacing: rootObj.s(10)

        // what the current style actually draws: every style scales the radius (Shadow x1.6, ...)
        readonly property real radiusScale: {
            let st = ThemeBackend.styles[section.tab.currentBlurStyle];
            return st && st.radiusScale !== undefined ? st.radiusScale : 1.0;
        }
        function radiusLabel(v) { return Math.round(Math.round(v) * radiusScale) + " px"; }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: rootObj.s(44)
            horizontalAlignment: Text.AlignRight
            text: radiusRow.radiusLabel(radiusSlider.effectiveValue)
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
        }

        Draggable {
            id: radiusSlider
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 0
            to: 48
            stepSize: 1
            defaultValue: 10
            showValueBubble: true
            valueFormatter: function(v) { return radiusRow.radiusLabel(v); }
            value: section.tab.currentBorderRadius
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            // live while dragging (debounced), saved for good on release
            onMoved: function(val) {
                let r = Math.round(val);
                if (section.tab.currentBorderRadius !== r) {
                    section.tab.currentBorderRadius = r;
                    section.tab.borderRadiusDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.borderRadiusDebounceTimer.stop();
                section.tab.currentBorderRadius = Math.round(radiusSlider.value);
                section.tab.updateBorderRadiusSetting();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "element_opacity"
        visible: !(section.tab.currentBlurBackground && section.tab.currentBlurStyle === "liquid") && ThemeBackend.styles[section.tab.currentBlurStyle].opaque !== true
        icon: "󰃟"
        title: I18n.t("guide.theme.element_opacity.title", "Element opacity")
        description: I18n.t("guide.theme.element_opacity.desc", "Opacity of the bar, dock, widgets and every other shell element")
        searchKeywords: "element opacity transparency transparent translucent alpha bar dock widgets"

        Draggable {
            id: elementOpacitySlider
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.rightMargin: rootObj.s(8)
            implicitWidth: rootObj.s(220)
            implicitHeight: rootObj.s(18)
            from: 0
            to: 100
            stepSize: 1
            defaultValue: 100
            showValueBubble: true
            valueFormatter: function(v) { return Math.round(v) + "%" }
            value: section.tab.currentElementOpacity
            backgroundColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            handleColor: ThemeBackend.text
            handleBorderColor: ThemeBackend.mantle
            onMoved: function(val) {
                let rounded = Math.round(val);
                if (section.tab.currentElementOpacity !== rounded) {
                    section.tab.currentElementOpacity = rounded;
                    section.tab.elementOpacityDebounceTimer.restart();
                }
            }
            onDragFinished: {
                section.tab.elementOpacityDebounceTimer.stop();
                section.tab.updateElementOpacitySetting();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "blur_background"
        visible: ThemeBackend.styles[section.tab.currentBlurStyle].opaque !== true
        icon: "󰂵"
        title: I18n.t("guide.theme.blur_background.title", "Add a blurred wallpaper background")
        description: I18n.t("guide.theme.blur_background.desc", "Blur the wallpaper behind every element that uses transparency")
        searchKeywords: "blur blurred wallpaper background frosted glass liquid glass apple transparency opacity"

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.tab.currentBlurBackground
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(val) {
                section.tab.updateBlurBackgroundSetting(val);
            }
        }
    }

}
