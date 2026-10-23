import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property real targetMasterHeight: window.s(510)
    property real targetMasterWidth: window.s(1360)
    implicitWidth: targetMasterWidth
    implicitHeight: targetMasterHeight
    width: targetMasterWidth
    height: targetMasterHeight

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color base: ThemeBackend.base
    readonly property color mantle: ThemeBackend.mantle
    readonly property color crust: ThemeBackend.crust
    readonly property color text: ThemeBackend.text
    readonly property color subtext1: ThemeBackend.subtext1
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color overlay2: ThemeBackend.overlay2
    readonly property color overlay1: ThemeBackend.overlay1
    readonly property color overlay0: ThemeBackend.overlay0
    readonly property color surface2: ThemeBackend.surface2
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface0: ThemeBackend.surface0

    readonly property color mauve: ThemeBackend.mauve
    readonly property color pink: ThemeBackend.pink
    readonly property color blue: ThemeBackend.blue
    readonly property color sapphire: ThemeBackend.sapphire
    readonly property color peach: ThemeBackend.peach
    readonly property color yellow: ThemeBackend.yellow
    readonly property color teal: ThemeBackend.teal
    readonly property color green: ThemeBackend.green
    readonly property color red: ThemeBackend.red

    readonly property string scriptsDir: Caching.qsDir + "/calendar"

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;
        if (h >= 12 && h < 17) return window.sapphire;
        if (h >= 17 && h < 21) return window.mauve;
        return window.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;
        if (h >= 12 && h < 17) return window.teal;
        if (h >= 17 && h < 21) return window.pink;
        return window.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        startupComplete = false;
        introMain = 0;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        transitionSpin = 0.0;
        transitionScale = 1.0;
        weatherContentOpacity = 1.0;
        weatherContentOffset = 0.0;
        calendarContentOpacity = 1.0;
        calendarContentOffset = 0.0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            window.gridDay = DateTime.now.getDate();
            updateCalendarGrid();
            Weather.refresh(false);
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.stop();
            weatherTransitionAnim.stop();
            calendarTransitionAnim.stop();
            startupComplete = false;
            introMain = 0;
            introAmbient = 0;
            introClock = 0;
            introCalendar = 0;
            introWeather = 0;
            transitionSpin = 0.0;
            transitionScale = 1.0;
            weatherContentOpacity = 1.0;
            weatherContentOffset = 0.0;
            calendarContentOpacity = 1.0;
            calendarContentOffset = 0.0;
        }
    }

    SequentialAnimation {
        id: introAnim
        running: false

        PauseAnimation { duration: (20) * ThemeBackend.animScale }

        ParallelAnimation {
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: (800) * ThemeBackend.animScale; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: (150) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: (1000) * ThemeBackend.animScale; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: (250) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: (900) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: (350) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: (850) * ThemeBackend.animScale; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: (400) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: (850) * ThemeBackend.animScale; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: window; property: "introWeather"; to: 0; duration: (150) * ThemeBackend.animScale; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: (150) * ThemeBackend.animScale; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: (30) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introClock"; to: 0; duration: (160) * ThemeBackend.animScale; easing.type: Easing.InBack }
                NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: (140) * ThemeBackend.animScale; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                PauseAnimation { duration: (50) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "introMain"; to: 0; duration: (180) * ThemeBackend.animScale; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    property real globalOrbitOffset: 0
    NumberAnimation on globalOrbitOffset {
        from: 0; to: -360; duration: (60000) * ThemeBackend.animScale; loops: Animation.Infinite; running: window.visible
    }

    property real globalOscPhase: 0
    NumberAnimation on globalOscPhase {
        from: 0; to: Math.PI * 2; duration: (9000) * ThemeBackend.animScale; loops: Animation.Infinite; running: window.visible
    }

    property var currentTime: DateTime.now
    property real currentEpoch: currentTime.getTime() / 1000

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: (600) * ThemeBackend.animScale; easing.type: Easing.OutQuint; running: false
    }

    property int gridDay: -1

    Connections {
        target: DateTime
        enabled: window.visible
        function onNowChanged() {
            window.secondPulse = 1.02;
            pulseReset.start();

            let day = DateTime.now.getDate();
            if (day !== window.gridDay) {
                window.gridDay = day;
                window.updateCalendarGrid();
            }
        }
    }

    property var weatherData: Weather.data
    property int weatherView: 0
    property color activeWeatherHex: {
        if (!window.weatherData) return window.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].hex;
        return window.mauve;
    }

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1

    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    property real targetTemp: {
        if (!window.weatherData || window.weatherData.offline) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.weatherData.forecast && window.weatherData.forecast[window.targetWeatherView]) {
            return Number(window.weatherData.forecast[window.targetWeatherView].max);
        }
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: (800) * ThemeBackend.animScale
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;
        if (window.targetTemp < window.displayedTemp) return window.blue;
        return window.text;
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: (250) * ThemeBackend.animScale; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: -window.s(40) * weatherAnimDirection; duration: (250) * ThemeBackend.animScale; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: (300) * ThemeBackend.animScale; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: (300) * ThemeBackend.animScale; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.weatherContentOffset = window.s(40) * weatherAnimDirection;
                window.transitionSpin = -180 * weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: (450) * ThemeBackend.animScale; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: (450) * ThemeBackend.animScale; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: (600) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: (500) * ThemeBackend.animScale; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
            window.transitionSpin = 0.0;
            window.transitionScale = 1.0;
            window.weatherContentOpacity = 1.0;
            window.weatherContentOffset = 0.0;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;

        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;

        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let parts = timeStr.trim().split(" ");
            let clockPart = parts.length > 1 && parts[0].includes("-") ? parts[1] : parts[0];
            let h = parseInt(clockPart.split(":")[0]);
            if (isNaN(h)) h = 0;
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    property real centerOffset: 0
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: (200) * ThemeBackend.animScale; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -window.s(20) * calendarAnimDirection; duration: (200) * ThemeBackend.animScale; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: (350) * ThemeBackend.animScale; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: (350) * ThemeBackend.animScale; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        let monthLoc = Qt.locale(I18n.qtLocaleName);
        // standalone month name, so Ukrainian reads "Жовтень 2026" and not "жовтня 2026"
        let monthName = monthLoc.standaloneMonthName(d.getMonth(), Locale.LongFormat);
        window.targetMonthName = monthName.charAt(0).toUpperCase() + monthName.slice(1) + " " + d.getFullYear();

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            Weather.refresh(false);
            resetAndPlayIntro();
        }
    }


    // ---- layout: three cards (Today, Month, Weather) ----
    readonly property real cardRadius: ThemeBackend.square ? 0 : Math.min(window.s(28), ThemeBackend.rad(window.s(16)))
    readonly property color cardColor: ThemeBackend.material ? ThemeBackend.surfaceContainer : Qt.alpha(window.surface0, 0.55)
    readonly property color accentFill: ThemeBackend.material ? ThemeBackend.mauve : window.textAccent
    readonly property color onAccentFill: ThemeBackend.material ? ThemeBackend.onPrimary : window.base

    // how far through the day / year we are, for the Today card
    readonly property real dayProgress: (currentTime.getHours() * 3600 + currentTime.getMinutes() * 60 + currentTime.getSeconds()) / 86400
    readonly property int dayOfYear: {
        let start = new Date(currentTime.getFullYear(), 0, 0);
        return Math.floor((currentTime - start) / 86400000);
    }
    readonly property int daysInYear: (new Date(currentTime.getFullYear(), 1, 29).getDate() === 29) ? 366 : 365
    readonly property int weekNumber: {
        let d = new Date(Date.UTC(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate()));
        let dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    component Card: Rectangle {
        radius: window.cardRadius
        color: cardGlass.active ? "transparent" : window.cardColor
        GlassFill {
            id: cardGlass
            anchors.fill: parent
            radius: ThemeBackend.rad(parent.radius)
            tintColor: window.surface0
            tintAmount: 0.25
        }
    }

    component RoundButton: IconButton {
        size: window.s(34)
        cornerRadius: size / 2
        iconFontSize: window.s(14)
        accentColor: ThemeBackend.material ? ThemeBackend.surfaceContainerHigh : window.surface1
        textColor: window.text
    }

    Item {
        anchors.fill: parent
        scale: 0.96 + (0.04 * introMain)
        opacity: introMain

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: ThemeBackend.rad(parent.topLeftRadius)
                topRightRadius: ThemeBackend.rad(parent.topRightRadius)
                bottomLeftRadius: ThemeBackend.rad(parent.bottomLeftRadius)
                bottomRightRadius: ThemeBackend.rad(parent.bottomRightRadius)
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: window.s(18)
                spacing: window.s(14)
                layoutDirection: I18n.layoutDirection

                // ---------- Today ----------
                Card {
                    Layout.preferredWidth: window.s(360)
                    Layout.fillHeight: true
                    opacity: introClock
                    transform: Translate { y: window.s(20) * (1.0 - introClock) }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(26)
                        spacing: window.s(4)

                        Text {
                            text: I18n.t("calendar.today", "Today")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: window.s(14)
                            color: window.subtext0
                        }

                        Row {
                            spacing: window.s(6)
                            Text {
                                text: DateTime.hour + ":" + DateTime.minute
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Normal
                                font.pixelSize: window.s(88)
                                color: window.text
                                scale: window.secondPulse
                            }
                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: window.s(18)
                                Text {
                                    visible: DateTime.amPm !== ""
                                    text: DateTime.amPm
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(16)
                                    color: window.subtext0
                                }
                                Text {
                                    text: Qt.formatDateTime(window.currentTime, "ss")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(20)
                                    color: window.accentFill
                                }
                            }
                        }

                        Text {
                            text: Qt.locale(I18n.qtLocaleName).toString(window.currentTime, "dddd, MMMM d")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: window.s(18)
                            color: window.text
                        }

                        Item { Layout.fillHeight: true }

                        // day and year progress
                        Repeater {
                            model: [
                                { label: I18n.t("calendar.progress.day", "Day"), value: window.dayProgress, note: Math.round(window.dayProgress * 100) + "%" },
                                { label: I18n.t("calendar.progress.year", "Year"), value: window.dayOfYear / window.daysInYear, note: window.dayOfYear + " / " + window.daysInYear }
                            ]
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: window.s(8)
                                spacing: window.s(6)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(12)
                                        color: window.subtext0
                                    }
                                    Text {
                                        text: modelData.note
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(12)
                                        color: window.subtext0
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: window.s(8)
                                    radius: height / 2
                                    color: ThemeBackend.material ? ThemeBackend.surfaceContainerHighest : window.surface1
                                    Rectangle {
                                        width: Math.max(height, parent.width * Math.min(1, modelData.value))
                                        height: parent.height
                                        radius: height / 2
                                        color: window.accentFill
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.topMargin: window.s(10)
                            text: I18n.t("calendar.week", "Week") + " " + window.weekNumber
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(12)
                            color: window.subtext0
                        }
                    }
                }

                // ---------- Month ----------
                Card {
                    Layout.preferredWidth: window.s(400)
                    Layout.fillHeight: true
                    opacity: introCalendar
                    transform: Translate { y: window.s(20) * (1.0 - introCalendar) }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(22)
                        spacing: window.s(8)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: window.s(6)
                            layoutDirection: I18n.layoutDirection

                            Text {
                                Layout.fillWidth: true
                                text: window.targetMonthName
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Medium
                                font.pixelSize: window.s(20)
                                elide: Text.ElideRight
                                color: window.text
                                opacity: window.calendarContentOpacity
                            }

                            // back to this month
                            ClickButton {
                                visible: window.targetMonthOffset !== 0
                                Layout.preferredHeight: window.s(34)
                                horizontalPadding: window.s(14)
                                cornerRadius: window.s(17)
                                buttonText: I18n.t("calendar.today", "Today")
                                textFontSize: window.s(12)
                                accentColor: ThemeBackend.material ? ThemeBackend.secondaryContainer : window.surface1
                                textColor: ThemeBackend.material ? ThemeBackend.onSecondaryContainer : window.text
                                onClicked: window.setMonthOffset(0)
                            }
                            RoundButton {
                                buttonIcon: I18n.rtl ? "󰅂" : "󰅁"
                                onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                            }
                            RoundButton {
                                buttonIcon: I18n.rtl ? "󰅁" : "󰅂"
                                onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: window.s(6)
                            columns: 7
                            rowSpacing: 0
                            columnSpacing: 0
                            layoutDirection: I18n.layoutDirection
                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }

                            Repeater {
                                model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: window.s(28)
                                    text: String(modelData).charAt(0)
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Medium
                                    font.pixelSize: window.s(12)
                                    color: index >= 5 ? window.accentFill : window.subtext0
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Repeater {
                                model: calendarModel
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 1
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - window.s(4)
                                        height: width
                                        radius: ThemeBackend.square ? 0 : width / 2
                                        color: isToday ? window.accentFill : (dayMa.containsMouse && isCurrentMonth ? Qt.alpha(window.text, 0.08) : "transparent")
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: dayNum
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: isToday ? Font.DemiBold : Font.Normal
                                        font.pixelSize: window.s(13)
                                        color: isToday ? window.onAccentFill : (isCurrentMonth ? window.text : Qt.alpha(window.subtext0, 0.45))
                                    }
                                    MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
                    }
                }

                // ---------- Weather ----------
                Card {
                    id: weatherCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: introWeather
                    transform: Translate { y: window.s(20) * (1.0 - introWeather) }

                    readonly property var day: window.weatherData && window.weatherData.forecast ? window.weatherData.forecast[window.weatherView] : null
                    readonly property var stats: window.weatherData && window.weatherData.forecast ? window.weatherData.forecast[window.targetWeatherView] : null

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(22)
                        spacing: window.s(12)

                        // the days, as chips
                        Row {
                            Layout.fillWidth: true
                            spacing: window.s(6)
                            Repeater {
                                model: (window.weatherData && window.weatherData.forecast) ? Math.min(5, window.weatherData.forecast.length) : 0
                                Rectangle {
                                    readonly property bool sel: index === window.targetWeatherView
                                    width: dayLabel.implicitWidth + window.s(26)
                                    height: window.s(32)
                                    radius: height / 2
                                    color: sel ? (ThemeBackend.material ? ThemeBackend.secondaryContainer : window.surface1)
                                               : (chipMa.containsMouse ? Qt.alpha(window.text, 0.06) : "transparent")
                                    border.width: sel ? 0 : 1
                                    border.color: Qt.alpha(window.text, 0.14)
                                    Text {
                                        id: dayLabel
                                        anchors.centerIn: parent
                                        text: index === 0 ? I18n.t("calendar.today", "Today")
                                            : String(window.weatherData.forecast[index].day_full || "").substring(0, 3)
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Medium
                                        font.pixelSize: window.s(12)
                                        color: parent.sel && ThemeBackend.material ? ThemeBackend.onSecondaryContainer : window.text
                                    }
                                    MouseArea {
                                        id: chipMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: window.setWeatherView(index)
                                    }
                                }
                            }
                        }

                        // now: icon, temperature, what it's like, where
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: window.s(18)
                            opacity: window.weatherContentOpacity
                            transform: Translate { x: window.weatherContentOffset }

                            Text {
                                text: {
                                    if (!window.weatherData) return "";
                                    if (window.weatherView === 0 && window.weatherData.current_icon) return window.weatherData.current_icon;
                                    return weatherCard.day ? weatherCard.day.icon : "";
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: window.s(58)
                                color: window.activeWeatherHex
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: (window.weatherData && window.weatherData.offline ? "--" : window.displayedTemp.toFixed(1)) + (Weather.unitSym || "°")
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Normal
                                    font.pixelSize: window.s(52)
                                    color: window.tempGlowColor
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        let d = weatherCard.day ? weatherCard.day.desc : "";
                                        let c = (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (window.weatherData && window.weatherData.city ? window.weatherData.city : "");
                                        return [d, c].filter(x => x && x !== "").join(" · ");
                                    }
                                    elide: Text.ElideRight
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: window.s(14)
                                    color: window.subtext0
                                }
                            }
                        }

                        // hourly, as a row of pills
                        Item { Layout.fillHeight: true }

                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: window.s(118)
                            spacing: window.s(6)
                            opacity: window.weatherContentOpacity
                            readonly property var hours: weatherCard.day && weatherCard.day.hourly ? weatherCard.day.hourly.slice(0, 8) : []
                            readonly property real pillW: Math.max(window.s(40), (width - spacing * Math.max(0, hours.length - 1)) / Math.max(1, hours.length))
                            Repeater {
                                model: parent.hours
                                Rectangle {
                                    readonly property bool now: window.weatherView === 0 && index === window.activeHourIndex
                                    width: parent.pillW
                                    height: parent.height
                                    radius: ThemeBackend.square ? 0 : width / 2
                                    color: now ? window.accentFill : (ThemeBackend.material ? ThemeBackend.surfaceContainerHigh : Qt.alpha(window.surface1, 0.6))
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: window.s(6)
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.temp + "°"
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: Font.Medium
                                            font.pixelSize: window.s(13)
                                            color: now ? window.onAccentFill : window.text
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.icon || (weatherCard.day ? weatherCard.day.icon : "")
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: window.s(18)
                                            color: now ? window.onAccentFill : (modelData.hex || window.text)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: String(modelData.time || "").split(" ").pop()
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: window.s(11)
                                            color: now ? window.onAccentFill : window.subtext0
                                        }
                                    }
                                }
                            }
                        }

                        // wind, humidity, rain, feels like
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: window.s(6)
                            Repeater {
                                model: 4
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: window.s(46)
                                    radius: height / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.alpha(window.text, 0.14)
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: window.s(8)
                                        Text {
                                            text: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: window.s(15)
                                            color: window.accentFill
                                        }
                                        Column {
                                            Text {
                                                text: window.weatherData && window.weatherData.offline ? "--" : weatherCard.stats ? (
                                                    index === 0 ? weatherCard.stats.wind + (Weather.unit === "imperial" ? " mph" : " m/s") :
                                                    index === 1 ? weatherCard.stats.humidity + "%" :
                                                    index === 2 ? weatherCard.stats.pop + "%" :
                                                    weatherCard.stats.feels_like + "°") : ""
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: Font.Medium
                                                font.pixelSize: window.s(12)
                                                color: window.text
                                            }
                                            Text {
                                                text: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: window.s(10)
                                                color: window.subtext0
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
    }
}
