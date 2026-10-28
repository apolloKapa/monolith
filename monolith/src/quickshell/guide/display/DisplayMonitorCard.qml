import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

Rectangle {
    id: monDelegate
    required property var tab
    required property var modelData
    required property int index
    readonly property var rootObj: tab.rootObj

    Layout.fillWidth: true
    clip: true
    radius: ThemeBackend.borderRadius

    property string monName: modelData.name
    property var monSettings: (monDelegate.tab && monDelegate.tab.displaySettings && monDelegate.tab.displaySettings.monitors && monDelegate.tab.displaySettings.monitors[monName]) ? monDelegate.tab.displaySettings.monitors[monName] : ({})

    property bool monitorPowered: monSettings && monSettings.powerEnabled !== undefined ? monSettings.powerEnabled : (modelData && modelData.active !== undefined ? modelData.active : true)
    property bool filterEnabled: monSettings && monSettings.enabled !== undefined ? monSettings.enabled : false
    property bool filterAuto: monSettings && monSettings.auto !== undefined ? monSettings.auto : false
    property real currentTemp: monSettings && monSettings.temperature !== undefined ? monSettings.temperature : 50
    property real currentScale: modelData.scale !== undefined ? modelData.scale : 1.0

    readonly property color cardTint: monitorPowered ? Qt.alpha(ThemeBackend.surface0, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface0, 0.4), 1.1)
    color: monDelegateGlass.active ? "transparent" : cardTint
    border.color: monitorPowered ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface1, 0.4), 1.1)
    border.width: ThemeBackend.liquidGlass ? 0 : 1

    GlassFill {
        id: monDelegateGlass
        anchors.fill: parent
        radius: ThemeBackend.rad(parent.radius)
        tintColor: monDelegate.cardTint
        tintAmount: 0.25
    }

    property real targetHeight: boxLayout.implicitHeight + rootObj.s(24)
    property bool appeared: false

    property real appearProgress: appeared ? 1 : 0
    implicitHeight: targetHeight * appearProgress
    opacity: appeared ? 1.0 : 0.0

    Behavior on appearProgress { NumberAnimation { duration: (300) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: (300) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: (250) * ThemeBackend.animScale } }
    Behavior on border.color { ColorAnimation { duration: (250) * ThemeBackend.animScale } }

    Component.onCompleted: {
        appeared = true;
    }

    property var resDims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
    property int monWidth: parseInt(resDims[0]) || 1920
    property int monHeight: parseInt(resDims[1]) || 1080
    property var validScales: monDelegate.tab.validScalesForResolution(monWidth, monHeight)
    readonly property int currentScaleIndex: {
        let i = validScales.indexOf(currentScale);
        if (i >= 0) return i;
        let nearest = monDelegate.tab.nearestValidScaleFromList(validScales, currentScale);
        let ni = validScales.indexOf(nearest);
        return ni >= 0 ? ni : 0;
    }

    // ---- Resolution, refresh rate, rotation (niri) ----
    readonly property bool canSetMode: monDelegate.tab.compositor === "niri" && monitorPowered
        && !!modelData.modes && modelData.modes.length > 0 && !!modelData.currentMode
    readonly property var curParts: (modelData.currentMode || "").match(/^(\d+)x(\d+)@([0-9.]+)$/)
    readonly property string curRes: curParts ? curParts[1] + "x" + curParts[2] : ""
    readonly property string curHz: curParts ? Number(curParts[3]).toFixed(3) : ""
    // sizes, biggest first
    readonly property var resolutions: {
        let seen = {}, out = [];
        for (const md of (modelData.modes || [])) {
            let r = md.width + "x" + md.height;
            if (!seen[r]) { seen[r] = true; out.push({ r: r, area: md.width * md.height, w: md.width }); }
        }
        out.sort((a, b) => b.area - a.area || b.w - a.w);
        return out.map(o => o.r);
    }
    function ratesFor(res) {
        let seen = {}, out = [];
        for (const md of (modelData.modes || [])) {
            if (md.width + "x" + md.height !== res) continue;
            let hz = md.hz.toFixed(3);
            if (!seen[hz]) { seen[hz] = true; out.push(hz); }
        }
        return out.sort((a, b) => Number(b) - Number(a));
    }
    readonly property var rates: ratesFor(curRes)
    function hzLabel(hz) { return Number(hz).toFixed(2).replace(/\.?0+$/, "") + " Hz"; }
    readonly property var rotations: [
        { id: "normal", label: "Normal" }, { id: "90", label: "90°" },
        { id: "180", label: "180°" }, { id: "270", label: "270°" },
        { id: "flipped", label: "Flipped" }, { id: "flipped-90", label: "Flipped 90°" },
        { id: "flipped-180", label: "Flipped 180°" }, { id: "flipped-270", label: "Flipped 270°" }
    ]
    readonly property bool confirming: !!monDelegate.tab.pendingOutput && monDelegate.tab.pendingOutput.name === monName

    onMonSettingsChanged: {
        if (!monSettings) return;
        if (monSettings.powerEnabled !== undefined) {
            monitorPowered = monSettings.powerEnabled;
        }
        filterEnabled = monSettings.enabled !== undefined ? monSettings.enabled : false;
        filterAuto = monSettings.auto !== undefined ? monSettings.auto : false;
        if (monDelegate.tab.pendingMonName !== monName && !temperatureSlider.pressed) {
            currentTemp = monSettings.temperature !== undefined ? monSettings.temperature : 50;
        }
    }

    onModelDataChanged: {
        if (monSettings.powerEnabled === undefined && modelData.active !== undefined) {
            monitorPowered = modelData.active;
        }
        if (monDelegate.tab.pendingMonScaleName !== monName) {
            currentScale = modelData.scale !== undefined ? modelData.scale : 1.0;
        }
    }

    ColumnLayout {
        id: boxLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: rootObj.s(12)
        spacing: rootObj.s(6)

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: rootObj.s(6)
            Layout.leftMargin: rootObj.s(4)
            Layout.rightMargin: rootObj.s(4)
            spacing: rootObj.s(8)

            Text {
                text: modelData.name
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(16)
                font.bold: true
                color: ThemeBackend.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: modelData.dimensions + " • " + modelData.framerate + "Hz"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                color: ThemeBackend.subtext0
            }
        }

        // applied right away; kept only once confirmed
        Rectangle {
            Layout.fillWidth: true
            visible: monDelegate.confirming
            implicitHeight: confirmRow.implicitHeight + rootObj.s(16)
            radius: ThemeBackend.rad(ThemeBackend.borderRadius)
            color: Qt.alpha(ThemeBackend.mauve, 0.16)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.mauve, 0.5)

            RowLayout {
                id: confirmRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: rootObj.s(12)
                anchors.rightMargin: rootObj.s(8)
                spacing: rootObj.s(8)

                Text {
                    Layout.fillWidth: true
                    text: "Keep these display settings? Going back in " + (monDelegate.confirming ? monDelegate.tab.pendingOutput.left : 0) + " s"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                    wrapMode: Text.WordWrap
                }
                ClickButton {
                    implicitHeight: rootObj.s(30)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Revert"
                    textFontSize: rootObj.s(11)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: monDelegate.tab.revertOutput()
                }
                ClickButton {
                    implicitHeight: rootObj.s(30)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: "Keep"
                    textFontSize: rootObj.s(11)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: monDelegate.tab.keepOutput()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: rootObj.s(4)
            visible: monDelegate.tab.outputError !== "" && monDelegate.tab.compositor === "niri"
            text: monDelegate.tab.outputError
            color: ThemeBackend.red
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(11)
            wrapMode: Text.WordWrap
        }

        SettingsRow {
            visible: monDelegate.canSetMode
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰹑"
            title: "Resolution"
            description: "How many pixels the screen shows"

            Dropdown {
                id: resDropdown
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(180)
                implicitHeight: rootObj.s(32)
                options: monDelegate.resolutions
                currentIndex: Math.max(0, monDelegate.resolutions.indexOf(monDelegate.curRes))
                // picking assigns currentIndex; follow the monitor again after a revert or a refusal
                Binding { target: resDropdown; property: "currentIndex"; value: Math.max(0, monDelegate.resolutions.indexOf(monDelegate.curRes)) }
                fuzzySearch: false
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.surface0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                fontPixelSize: rootObj.s(11)
                onValueChanged: function(index, value) {
                    if (!value || value === monDelegate.curRes) return;
                    // keep the refresh rate if the new size has it, else take its fastest
                    let r = monDelegate.ratesFor(value);
                    let hz = r.indexOf(monDelegate.curHz) >= 0 ? monDelegate.curHz : r[0];
                    monDelegate.tab.applyOutput(monDelegate.monName, value + "@" + hz, "", false);
                }
            }
        }

        SettingsRow {
            visible: monDelegate.canSetMode
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰔟"
            title: "Refresh rate"
            description: "How many times a second the screen redraws"

            Dropdown {
                id: rateDropdown
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(180)
                implicitHeight: rootObj.s(32)
                options: monDelegate.rates.map(h => monDelegate.hzLabel(h))
                currentIndex: Math.max(0, monDelegate.rates.indexOf(monDelegate.curHz))
                // picking assigns currentIndex; follow the monitor again after a revert or a refusal
                Binding { target: rateDropdown; property: "currentIndex"; value: Math.max(0, monDelegate.rates.indexOf(monDelegate.curHz)) }
                fuzzySearch: false
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.surface0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                fontPixelSize: rootObj.s(11)
                onValueChanged: function(index, value) {
                    let hz = monDelegate.rates[index];
                    if (!hz || hz === monDelegate.curHz) return;
                    monDelegate.tab.applyOutput(monDelegate.monName, monDelegate.curRes + "@" + hz, "", false);
                }
            }
        }

        SettingsRow {
            visible: monDelegate.canSetMode
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰑵"
            title: "Rotation"
            description: "Turn the picture for a monitor on its side or upside down"

            Dropdown {
                id: rotDropdown
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: rootObj.s(180)
                implicitHeight: rootObj.s(32)
                options: monDelegate.rotations.map(r => r.label)
                currentIndex: Math.max(0, monDelegate.rotations.findIndex(r => r.id === monDelegate.modelData.transform))
                // picking assigns currentIndex; follow the monitor again after a revert or a refusal
                Binding { target: rotDropdown; property: "currentIndex"; value: Math.max(0, monDelegate.rotations.findIndex(r => r.id === monDelegate.modelData.transform)) }
                fuzzySearch: false
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface0
                hoverColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.surface0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                fontPixelSize: rootObj.s(11)
                onValueChanged: function(index, value) {
                    let tf = monDelegate.rotations[index] ? monDelegate.rotations[index].id : "";
                    if (!tf || tf === monDelegate.modelData.transform) return;
                    monDelegate.tab.applyOutput(monDelegate.monName, "", tf, false);
                }
            }
        }

        SettingsRow {
            visible: monDelegate.tab.monitorsList.length > 1
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰐥"
            title: I18n.t("guide.display.enable.title", "Enable Monitor")
            description: I18n.t("guide.display.enable.desc", "Turn display output on or off")

            Toggle {
                id: powerToggle
                checked: monDelegate.monitorPowered
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    monDelegate.monitorPowered = c;
                    monDelegate.tab.updateMonitorSetting(monDelegate.monName, "powerEnabled", c);
                    monDelegate.tab.applyMonitorPower(monDelegate.monName, c);
                }

                Binding {
                    target: powerToggle
                    property: "checked"
                    value: monDelegate.monitorPowered
                }
            }
        }

        SettingsGroup {
            rootObj: monDelegate.rootObj
            icon: "󰖔"
            title: I18n.t("guide.display.bluelight.title")
            description: I18n.t("guide.display.bluelight.desc")
            expanded: monDelegate.filterEnabled

            Toggle {
                id: filterToggle
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                checked: monDelegate.filterEnabled
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    monDelegate.filterEnabled = c;
                    BlueLight.setEnabled(monDelegate.monName, c);
                    monDelegate.tab.refreshDisplaySettings();
                }

                Binding {
                    target: filterToggle
                    property: "checked"
                    value: monDelegate.filterEnabled
                }
            }

            subSettings: [
                SettingsRow {
                    rootObj: monDelegate.rootObj
                    baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                    icon: "󰥔"
                    title: I18n.t("guide.display.schedule.title")
                    description: I18n.t("guide.display.schedule.desc") + " " + monDelegate.tab.scheduleDescription

                    Toggle {
                        id: autoToggle
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: monDelegate.filterAuto
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            monDelegate.filterAuto = c;
                            BlueLight.setAuto(monDelegate.monName, c);
                            monDelegate.tab.refreshDisplaySettings();
                        }

                        Binding {
                            target: autoToggle
                            property: "checked"
                            value: monDelegate.filterAuto
                        }
                    }
                },

                Item {
                    id: tempSectionWrapper
                    Layout.fillWidth: true
                    property bool isOpen: !monDelegate.filterAuto
                    clip: true
                    visible: implicitHeight > 0
                    opacity: isOpen ? 1.0 : 0.0
                    property real openProgress: isOpen ? 1 : 0
                    implicitHeight: tempInnerBox.implicitHeight * openProgress

                    Behavior on opacity { NumberAnimation { duration: (300) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                    Behavior on openProgress { NumberAnimation { duration: (300) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

                    SettingsRow {
                        id: tempInnerBox
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        rootObj: monDelegate.rootObj
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰔏"
                        title: I18n.t("guide.display.temperature.title")
                        description: I18n.t("guide.display.temperature.desc")

                        Draggable {
                            id: temperatureSlider
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.rightMargin: rootObj.s(8)
                            implicitWidth: rootObj.s(220)
                            implicitHeight: rootObj.s(18)
                            from: 0
                            to: 100
                            stepSize: 1
                            defaultValue: 50
                            showValueBubble: true
                            valueFormatter: function(v) { return Math.round(v).toString() }
                            value: monDelegate.currentTemp
                            backgroundColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            handleColor: ThemeBackend.text
                            handleBorderColor: ThemeBackend.mantle
                            onMoved: function(val) {
                                let rounded = Math.round(val);
                                if (monDelegate.currentTemp !== rounded) {
                                    monDelegate.currentTemp = rounded;
                                    monDelegate.tab.updateMonitorSettingDebounced(monDelegate.monName, rounded);
                                }
                            }
                            onDragFinished: {
                                monDelegate.tab.flushMonitorSetting(monDelegate.monName);
                            }
                        }
                    }
                }
            ]
        }

        SettingsRow {
            visible: monDelegate.tab.compositor !== "mango"
            rootObj: monDelegate.rootObj
            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
            icon: "󰍍"
            title: I18n.t("guide.display.uiscale.title")
            description: I18n.t("guide.display.uiscale.desc")
            controlSpacing: rootObj.s(4)

            LoaderIcon {
                id: scaleLoader
                Layout.preferredWidth: rootObj.s(32)
                Layout.preferredHeight: rootObj.s(32)
                Layout.alignment: Qt.AlignVCenter
                running: monDelegate.tab.scaleDebounceTimer.running && monDelegate.tab.pendingMonScaleName === monDelegate.monName
                accentColor: ThemeBackend.mauve
            }

            Draggable {
                id: uiScaleSlider
                implicitWidth: rootObj.s(220)
                implicitHeight: rootObj.s(18)
                from: 0
                to: Math.max(0, monDelegate.validScales.length - 1)
                stepSize: 1
                defaultValue: monDelegate.validScales.indexOf(1.0) >= 0 ? monDelegate.validScales.indexOf(1.0) : 0
                showValueBubble: true
                showTooltip: true
                alwaysShowHandle: false
                valueFormatter: function(idx) {
                    let i = Math.round(idx);
                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                    return s.toFixed(3).replace(/0+$/,'').replace(/\.$/,'.0');
                }
                value: monDelegate.currentScaleIndex
                backgroundColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                handleColor: ThemeBackend.text
                handleBorderColor: ThemeBackend.mantle
                onMoved: function(idx) {
                    let i = Math.round(idx);
                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                    if (monDelegate.currentScale !== s) {
                        monDelegate.currentScale = s;
                        monDelegate.tab.pendingMonScaleName = monDelegate.monName;
                        monDelegate.tab.pendingMonScaleVal = s;
                        monDelegate.tab.scaleDebounceTimer.restart();
                    }
                }
                onDragFinished: {
                    monDelegate.tab.scaleDebounceTimer.stop();
                    if (monDelegate.tab.pendingMonScaleName !== "") {
                        monDelegate.tab.applyMonitorScale(monDelegate.tab.pendingMonScaleName, monDelegate.tab.pendingMonScaleVal);
                        monDelegate.tab.updateMonitorSetting(monDelegate.tab.pendingMonScaleName, "scale", monDelegate.tab.pendingMonScaleVal);
                        monDelegate.tab.pendingMonScaleName = "";
                    }
                }
            }
        }
    }
}
