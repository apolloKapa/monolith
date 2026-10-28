import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    required property var panel
    property alias nightLight: nightLightBtn
    property alias coffee: coffeeBtn

    // A quick-settings tile: icon, name and state on a pill. On = filled with the accent.
    component QuickActionBtn : Rectangle {
        id: qaBtn
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        radius: ThemeBackend.pill ? height / 2 : ThemeBackend.rad(view.panel.cardRadius)

        property bool isActive: false
        property string iconText: ""
        property string label: ""
        property string stateText: isActive ? I18n.t("syspanel.tiles.on", "On") : I18n.t("syspanel.tiles.off", "Off")
        property color activeColor: ThemeBackend.blue
        readonly property bool isHovered: qaMa.containsMouse
        // Material fills an on tile with the primary colour; the other styles tint it
        readonly property color onFill: ThemeBackend.material ? ThemeBackend.mauve : Qt.alpha(activeColor, 0.3)
        readonly property color onInk: ThemeBackend.material ? ThemeBackend.onPrimary : activeColor

        property real togglePulse: 0.0

        onIsActiveChanged: {
            if (qaGlass.active) togglePulseAnim.restart();
        }

        SequentialAnimation {
            id: togglePulseAnim
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 1.0; duration: (90) * ThemeBackend.animScale; easing.type: Easing.OutQuad }
            NumberAnimation { target: qaBtn; property: "togglePulse"; to: 0.0; duration: (560) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
        }

        signal leftClicked()
        signal rightClicked()

        color: qaGlass.active ? "transparent" : (isActive ? onFill : ThemeBackend.faded(qaMa.containsMouse ? ThemeBackend.surfaceContainerHighest : ThemeBackend.surfaceContainerHigh))

        GlassFill {
            id: qaGlass
            anchors.fill: parent
            radius: ThemeBackend.rad(parent.radius)
            tintColor: qaBtn.isActive ? qaBtn.activeColor : (qaMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
            tintAmount: qaBtn.isActive ? 0.35 : 0.3
            shadow: 1
            press: qaMa.pressed ? 1 : (qaMa.containsMouse ? 0.25 : 0)
            pulse: qaBtn.togglePulse
            Behavior on press { NumberAnimation { duration: (200) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
            Behavior on tintAmount { NumberAnimation { duration: (180) * ThemeBackend.animScale } }
        }
        Behavior on color {
            enabled: view.panel.visible
            ColorAnimation { duration: (180) * ThemeBackend.animScale }
        }

        scale: qaMa.pressed ? 0.96 : 1.0
        Behavior on scale {
            enabled: view.panel.visible
            NumberAnimation { duration: (200) * ThemeBackend.animScale; easing.type: Easing.OutQuart }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: view.panel.s(16)
            anchors.rightMargin: view.panel.s(12)
            spacing: view.panel.s(12)

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: ThemeBackend.iconFont
                font.pixelSize: view.panel.s(20)
                color: qaBtn.isActive ? qaBtn.onInk : ThemeBackend.text
                text: qaBtn.iconText
                Behavior on color { enabled: view.panel.visible; ColorAnimation { duration: (180) * ThemeBackend.animScale } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: qaBtn.label
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: view.panel.s(13)
                    color: qaBtn.isActive ? qaBtn.onInk : ThemeBackend.text
                }
                Text {
                    Layout.fillWidth: true
                    text: qaBtn.stateText
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: view.panel.s(11)
                    color: qaBtn.isActive ? Qt.alpha(qaBtn.onInk, 0.8) : ThemeBackend.subtext0
                }
            }
        }

        MouseArea {
            id: qaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) qaBtn.rightClicked();
                else qaBtn.leftClicked();
            }
        }
    }

    id: view
    z: 5
    Layout.fillWidth: true
    Layout.preferredHeight: view.panel.s(56) * 3 + view.panel.s(8) * 2
    Layout.maximumHeight: Layout.preferredHeight
    opacity: view.panel.introQuickActions
    transform: Translate { x: (view.panel.isLeftAnchored ? -view.panel.rowSlideDistance : view.panel.rowSlideDistance) * (1.0 - view.panel.introQuickActions) }

    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: view.panel.s(8)
        columnSpacing: view.panel.s(8)

        QuickActionBtn {
            id: nightLightBtn
            iconText: "󰖔"
            label: I18n.t("syspanel.tiles.night_light", "Night light")
            activeColor: ThemeBackend.peach

            function updateState() {
                let anyEnabled = false;
                if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
                    anyEnabled = BlueLight.isAnyEnabled();
                } else if (typeof Config !== "undefined") {
                    let ds = Config.getSetting("display", {"monitors": {}});
                    let mons = (ds && ds.monitors) ? ds.monitors : {};
                    for (let mName in mons) {
                        if (mons[mName] && mons[mName].enabled) {
                            anyEnabled = true;
                            break;
                        }
                    }
                }
                isActive = anyEnabled;
            }

            Component.onCompleted: updateState()

            Connections {
                target: typeof Config !== "undefined" ? Config : null
                enabled: view.panel.visible
                ignoreUnknownSignals: true
                function onSettingsLoaded() {
                    nightLightBtn.updateState();
                }
            }

            Connections {
                target: typeof BlueLight !== "undefined" ? BlueLight : null
                enabled: view.panel.visible
                ignoreUnknownSignals: true
                function onSettingsChanged() {
                    nightLightBtn.updateState();
                }
            }

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let target = !nightLightBtn.isActive;
                nightLightBtn.isActive = target;

                let monNames = [];
                let ds = typeof Config !== "undefined" ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
                let mons = (ds && ds.monitors) ? ds.monitors : {};
                for (let m in mons) {
                    if (monNames.indexOf(m) === -1) {
                        monNames.push(m);
                    }
                }
                if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        let scr = Quickshell.screens[i];
                        if (scr && scr.name && monNames.indexOf(scr.name) === -1) {
                            monNames.push(scr.name);
                        }
                    }
                }

                if (monNames.length > 0) {
                    for (let i = 0; i < monNames.length; i++) {
                        BlueLight.setEnabled(monNames[i], target);
                    }
                } else {
                    BlueLight.setEnabled("", target);
                }
                nightLightBtn.updateState();
            }

            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "open", "settings", "display"]);
            }
        }

        QuickActionBtn {
            id: coffeeBtn
            activeColor: Qt.tint(ThemeBackend.peach, "#5c3016")

            property double coffeeStartTime: 0
            property double coffeeEndTime: 0
            property int remainingSeconds: 0

            readonly property string remainingTimeString: {
                if (isActive && coffeeEndTime <= 0) return "∞";
                let secs = remainingSeconds;
                if (secs <= 0) return "< 1m";
                let h = Math.floor(secs / 3600);
                let m = Math.floor((secs % 3600) / 60);
                if (h > 0) {
                    return h + "h " + (m < 10 ? "0" + m : m) + "m";
                }
                return Math.max(1, m) + "m";
            }

            iconText: "󰅶"
            label: I18n.t("syspanel.tiles.caffeine", "Stay awake")
            stateText: isActive ? remainingTimeString : I18n.t("syspanel.tiles.off", "Off")

            function updateRemaining() {
                if (!isActive || coffeeEndTime <= 0) {
                    remainingSeconds = 0;
                    return;
                }
                let now = Date.now();
                let diff = Math.round((coffeeEndTime - now) / 1000);
                if (diff <= 0) {
                    remainingSeconds = 0;
                    disableCaffeine();
                } else {
                    remainingSeconds = diff;
                }
            }

            function syncConfig(enabled) {
                if (typeof Config === "undefined") return;
                let idleObj = Object.assign({}, Config.getSetting("idle", {}));
                idleObj.manualInhibit = enabled;
                idleObj.caffeineStartTime = enabled ? coffeeStartTime : 0;
                idleObj.caffeineEndTime = enabled ? coffeeEndTime : 0;
                Config.setSetting("idle", idleObj);
            }

            function enableCaffeine(durationMs) {
                let now = Date.now();
                coffeeStartTime = now;
                coffeeEndTime = now + durationMs;
                isActive = true;
                updateRemaining();
                syncConfig(true);
            }

            function increaseCaffeine(addMs) {
                let now = Date.now();
                if (!isActive || coffeeEndTime <= now) {
                    enableCaffeine(addMs);
                } else {
                    coffeeEndTime += addMs;
                    updateRemaining();
                    syncConfig(true);
                }
            }

            function disableCaffeine() {
                isActive = false;
                coffeeStartTime = 0;
                coffeeEndTime = 0;
                remainingSeconds = 0;
                syncConfig(false);
            }

            function updateState() {
                if (typeof Config === "undefined") return;
                let idleObj = Config.getSetting("idle", {}) || {};
                let endTime = Number(idleObj.caffeineEndTime) || 0;

                if (!idleObj.manualInhibit) {
                    isActive = false;
                    coffeeStartTime = 0;
                    coffeeEndTime = 0;
                    remainingSeconds = 0;
                } else if (endTime > 0 && endTime <= Date.now()) {
                    disableCaffeine();
                } else {
                    coffeeStartTime = Number(idleObj.caffeineStartTime) || 0;
                    coffeeEndTime = endTime;
                    isActive = true;
                    updateRemaining();
                }
            }

            Timer {
                id: coffeeTicker
                interval: view.panel.visible ? 1000 : 15000
                repeat: true
                running: coffeeBtn.isActive
                triggeredOnStart: true
                onTriggered: {
                    coffeeBtn.updateRemaining();
                }
            }

            Component.onCompleted: updateState()

            Connections {
                target: typeof Config !== "undefined" ? Config : null
                enabled: true
                ignoreUnknownSignals: true
                function onSettingsLoaded() {
                    coffeeBtn.updateState();
                }
            }

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (isActive) {
                    disableCaffeine();
                } else {
                    enableCaffeine(3600 * 1000);
                }
            }

            onRightClicked: {
                Sounds.playSfx("system/quick_click.wav");
                increaseCaffeine(3600 * 1000);
            }
        }

        QuickActionBtn {
            iconText: isActive ? "󰤨" : "󰤮"
            label: I18n.t("syspanel.tiles.wifi", "Wi-Fi")
            activeColor: ThemeBackend.blue
            isActive: view.panel.wifiRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Networking.wifiEnabled = !Networking.wifiEnabled;
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "toggle", "network", "wifi"]);
            }
        }

        QuickActionBtn {
            iconText: isActive ? "󰂯" : "󰂲"
            label: I18n.t("syspanel.tiles.bluetooth", "Bluetooth")
            activeColor: ThemeBackend.mauve
            isActive: view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (Bluetooth.defaultAdapter) {
                    BtPower.toggle();
                }
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "toggle", "network", "bt"]);
            }
        }

        QuickActionBtn {
            iconText: "󰀝"
            label: I18n.t("syspanel.tiles.airplane", "Airplane mode")
            activeColor: ThemeBackend.red
            isActive: !view.panel.wifiRadioEnabled && !view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let enableAirplane = !isActive;
                if (enableAirplane) {
                    view.panel.btStateBeforeAirplane = view.panel.btRadioEnabled;
                    view.panel.wifiStateBeforeAirplane = view.panel.wifiRadioEnabled;
                    Networking.wifiEnabled = false;
                    BtPower.setEnabled(false);
                } else {
                    let restoreWifi = view.panel.wifiStateBeforeAirplane;
                    let restoreBt = view.panel.btStateBeforeAirplane;
                    if (!restoreWifi && !restoreBt) {
                        restoreWifi = true;
                    }
                    Networking.wifiEnabled = restoreWifi;
                    BtPower.setEnabled(restoreBt);
                }
            }
        }

        // Game mode by hand: no animations or panel effects, quick actions panel off
        QuickActionBtn {
            iconText: "󰊴"
            label: I18n.t("syspanel.tiles.gamemode", "Game mode")
            activeColor: ThemeBackend.green
            isActive: ThemeBackend.gameModeForced
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let t = Object.assign({}, Config.getSetting("theme", {}));
                t.gameModeOn = !ThemeBackend.gameModeForced;
                Config.setSetting("theme", t);
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "open", "settings", "theme", "theme_animations"]);
            }
        }

        QuickActionBtn {
            id: dndBtn
            iconText: isActive ? "󰂛" : "󰂚"
            label: I18n.t("syspanel.tiles.dnd", "Do not disturb")
            activeColor: ThemeBackend.blue
            isActive: Boolean(Config.rawSettings && Config.rawSettings.notifications && Config.rawSettings.notifications.dnd)
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let n = Object.assign({}, Config.getSetting("notifications", { "dnd": false }));
                n.dnd = !dndBtn.isActive;
                Config.setSetting("notifications", n);
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/qs_manager.sh", "open", "settings", "notifications"]);
            }
        }
    }
}
