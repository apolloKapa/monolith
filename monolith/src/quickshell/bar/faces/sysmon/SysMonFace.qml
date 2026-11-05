import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string circleStyle: {
        if (widget && widget !== root && widget.sysmonStyle !== undefined) return widget.sysmonStyle;
        if (module && module.sysmonStyle !== undefined) return module.sysmonStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (bs.sysmonStyle) return bs.sysmonStyle;
            if (bs.sysmon && bs.sysmon.style) return bs.sysmon.style;
        }
        return "wave";
    }

    // wave and circle are the shader rings, square traces a rounded square, minimal is plain "RAM | 45%" text
    readonly property bool useSineWave: circleStyle !== "circle"
    readonly property bool isMinimal: circleStyle === "minimal"
    readonly property bool isSquare: circleStyle === "square"

    property var activeStats: {
        if (widget && widget !== root && widget.sysmonStats !== undefined) return widget.sysmonStats;
        if (module && module.sysmonStats !== undefined) return module.sysmonStats;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            let bs = Config.rawSettings.bar;
            if (Array.isArray(bs.sysmonStats)) return bs.sysmonStats;
            if (bs.sysmon && Array.isArray(bs.sysmon.stats)) return bs.sysmon.stats;
            if (bs.sysmonShowCpu !== undefined || bs.sysmonShowRam !== undefined || bs.sysmonShowTemp !== undefined || bs.sysmonShowDisk !== undefined) {
                let stats = [];
                if (bs.sysmonShowCpu !== false) stats.push("cpu");
                if (bs.sysmonShowRam !== false) stats.push("ram");
                if (bs.sysmonShowTemp !== false) stats.push("temp");
                if (bs.sysmonShowDisk === true) stats.push("disk");
                return stats;
            }
        }
        return ["cpu", "ram", "temp"];
    }

    property bool showLayout: (!barWindow || (root.activeTarget && root.activeTarget.isPreview)) ? true : false
    property int circleSize: barWindow ? barWindow.cs(isCompact ? 22 : 28) : (isCompact ? 22 : 28)

    property bool isSysVisible: (!activeTarget || activeTarget.moduleActive) && showLayout
    property color basePrimary: (ThemeBackend.primary !== undefined && ThemeBackend.primary !== "") ? ThemeBackend.primary : ThemeBackend.mauve

    property bool isSubscribed: false

    function updateSubscription() {
        if (isSysVisible && !isSubscribed) {
            isSubscribed = true;
            SysData.subscribe();
        } else if (!isSysVisible && isSubscribed) {
            isSubscribed = false;
            SysData.unsubscribe();
        }
    }

    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            SysData.unsubscribe();
        }
    }
    onIsSysVisibleChanged: updateSubscription()

    readonly property real layoutLength: isVertical ? sysLayout.implicitHeight : sysLayout.implicitWidth
    property real targetLength: ((!activeTarget || activeTarget.moduleActive) && layoutLength > 0) ? (layoutLength + (barWindow ? barWindow.cs(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    property bool isFaceVisible: showLayout && targetLength > 0

    function syncImplicitSize() {
        let cross = module ? module.thickness : (parent ? (isVertical ? parent.width : parent.height) : 0);
        implicitWidth = isVertical ? cross : targetLength;
        implicitHeight = isVertical ? targetLength : cross;
    }

    onTargetLengthChanged: syncImplicitSize()
    onIsVerticalChanged: syncImplicitSize()
    onModuleChanged: syncImplicitSize()
    onParentChanged: syncImplicitSize()

    Timer {
        running: true
        interval: 0
        onTriggered: root.syncImplicitSize()
    }

    Timer {
        running: (!activeTarget || activeTarget.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady && !root.showLayout
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: (root.isVertical || root.showLayout) ? 0 : (barWindow ? barWindow.cs(60) : 60)
        y: (!root.isVertical || root.showLayout) ? 0 : (barWindow ? barWindow.cs(60) : 60)
        Behavior on x { NumberAnimation { duration: (800) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: (800) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
    }

    // a rounded square that starts at the top middle and runs clockwise, like the rings
    component SquareRingPath: ShapePath {
        property var gauge: null
        readonly property real i: (gauge ? gauge.inset : 0)
        readonly property real w: (gauge ? gauge.width : 0)
        readonly property real h: (gauge ? gauge.height : 0)
        readonly property real r: (gauge ? gauge.r : 0)
        strokeWidth: (gauge ? gauge.sw : 0)
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.RoundJoin
        startX: w / 2; startY: i
        PathLine { x: w - i - r; y: i }
        PathArc { x: w - i; y: i + r; radiusX: r; radiusY: r; direction: PathArc.Clockwise }
        PathLine { x: w - i; y: h - i - r }
        PathArc { x: w - i - r; y: h - i; radiusX: r; radiusY: r; direction: PathArc.Clockwise }
        PathLine { x: i + r; y: h - i }
        PathArc { x: i; y: h - i - r; radiusX: r; radiusY: r; direction: PathArc.Clockwise }
        PathLine { x: i; y: i + r }
        PathArc { x: i + r; y: i; radiusX: r; radiusY: r; direction: PathArc.Clockwise }
        PathLine { x: w / 2; y: i }
    }

    component SysMonCircle: Rectangle {
        id: circleRoot
        property real value: 0
        property string textVal: ""
        property string icon: ""
        property color accentColor: root.basePrimary
        property bool showText: textVal !== ""
        property bool useSineWave: root.useSineWave
        property bool squareShape: root.isSquare
        property bool initAnimTrigger: (!barWindow || !!(root.activeTarget && root.activeTarget.isPreview))

        property real animValue: initAnimTrigger ? value : 0
        Behavior on animValue { NumberAnimation { duration: (600) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }

        property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))

        implicitWidth: root.circleSize
        implicitHeight: root.circleSize
        width: implicitWidth
        height: implicitHeight
        radius: squareShape ? 0 : ThemeBackend.rad(width / 2)
        color: "transparent"
        border.width: 0

        Timer {
            running: (!activeTarget || activeTarget.moduleActive) && root.showLayout && !initAnimTrigger
            interval: 150
            onTriggered: initAnimTrigger = true
        }

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            x: (!root.isVertical || initAnimTrigger) ? 0 : (barWindow ? barWindow.cs(15) : 15)
            y: (root.isVertical || initAnimTrigger) ? 0 : (barWindow ? barWindow.cs(15) : 15)
            Behavior on x { NumberAnimation { duration: (620) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
            Behavior on y { NumberAnimation { duration: (620) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: (450) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

        ShaderEffect {
            id: circleGauge
            anchors.fill: parent
            visible: !circleRoot.squareShape

            property vector2d itemSize: Qt.vector2d(width, height)
            property real fillRatio: circleRoot.fillRatio
            property real strokeWidth: barWindow ? barWindow.cs(2.2) : 2.2
            property real useSineWave: circleRoot.useSineWave ? 1.0 : 0.0
            property color accentColor: circleRoot.accentColor
            property vector4d params: Qt.vector4d(barWindow ? barWindow.cs(0.9) : 0.9, 0.0, 0.0, 0.0)

            fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/gauges/circular_wave_gauge.frag.qsb"
        }

        Shape {
            id: squareGauge
            anchors.fill: parent
            visible: circleRoot.squareShape
            preferredRendererType: Shape.CurveRenderer

            readonly property real sw: barWindow ? barWindow.cs(2.2) : 2.2
            readonly property real inset: sw / 2
            readonly property real side: width - 2 * inset
            readonly property real r: ThemeBackend.square ? 0 : Math.min(side / 2, side * 0.3)
            readonly property real perimeter: 4 * (side - 2 * r) + 2 * Math.PI * r

            SquareRingPath {
                gauge: squareGauge
                strokeColor: Qt.alpha(circleRoot.accentColor, 0.25)
            }
            SquareRingPath {
                gauge: squareGauge
                strokeColor: circleRoot.fillRatio > 0.005 ? circleRoot.accentColor : "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [circleRoot.fillRatio * squareGauge.perimeter / squareGauge.sw,
                              2 * squareGauge.perimeter / squareGauge.sw]
            }
        }

        Text {
            anchors.centerIn: parent
            text: circleRoot.showText ? circleRoot.textVal : circleRoot.icon
            font.pixelSize: Math.round(circleRoot.showText
                ? (barWindow ? barWindow.cs(root.isCompact ? 7.5 : 9) : (root.isCompact ? 7.5 : 9))
                : (barWindow ? barWindow.cs(root.isCompact ? 9 : 11) : (root.isCompact ? 9 : 11)))
            font.bold: circleRoot.showText
            font.family: circleRoot.showText
                ? ((ThemeBackend.fontFamily !== undefined && ThemeBackend.fontFamily !== "") ? ThemeBackend.fontFamily : "sans-serif")
                : ThemeBackend.iconFont
            color: (ThemeBackend.text !== undefined && ThemeBackend.text !== "") ? ThemeBackend.text : "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component SysMonText: Item {
        id: textRoot
        property string label: ""
        property string valueText: ""
        property bool initAnimTrigger: (!barWindow || !!(root.activeTarget && root.activeTarget.isPreview))

        readonly property real fontSize: Math.round(barWindow ? barWindow.cs(root.isCompact ? 10 : 11) : (root.isCompact ? 10 : 11))
        readonly property string fontFamily: (ThemeBackend.fontFamily !== undefined && ThemeBackend.fontFamily !== "") ? ThemeBackend.fontFamily : "sans-serif"
        readonly property color valueColor: (ThemeBackend.text !== undefined && ThemeBackend.text !== "") ? ThemeBackend.text : "#ffffff"

        // Orbit: each stat is a small tonal chip, an accent glyph and the value (no "CPU |" text)
        readonly property bool orbitChip: ThemeBackend.orbit && !root.isVertical
        readonly property string glyph: ({ "CPU": "󰍛", "RAM": "󰘚", "TEMP": "󰔏", "GPU": "󰢮", "DISK": "󰋊", "SWAP": "󰾴", "VRAM": "󰾲" })[String(textRoot.label).toUpperCase()] || ""
        implicitWidth: root.isVertical ? Math.max(labelText.implicitWidth, valueLabel.implicitWidth) : (orbitChip ? orbitRow.implicitWidth + (barWindow ? barWindow.cs(16) : 16) : textRow.implicitWidth)
        implicitHeight: root.isVertical ? (labelText.implicitHeight + valueLabel.implicitHeight) : root.circleSize
        width: implicitWidth
        height: implicitHeight

        Timer {
            running: (!activeTarget || activeTarget.moduleActive) && root.showLayout && !textRoot.initAnimTrigger
            interval: 150
            onTriggered: textRoot.initAnimTrigger = true
        }
        opacity: initAnimTrigger ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: (450) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

        Text {
            id: labelText
            text: textRoot.label
            font.pixelSize: textRoot.fontSize
            font.family: textRoot.fontFamily
            font.bold: true
            color: ThemeBackend.subtext0
            visible: root.isVertical
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }
        Text {
            id: valueLabel
            text: textRoot.valueText
            font.pixelSize: textRoot.fontSize
            font.family: textRoot.fontFamily
            color: textRoot.valueColor
            visible: root.isVertical
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: labelText.bottom
        }

        Rectangle {
            visible: textRoot.orbitChip
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.round(root.circleSize * 0.82)
            radius: Math.min(height / 2, ThemeBackend.borderRadius)
            color: ThemeBackend.surfaceContainerHighest
            Row {
                id: orbitRow
                anchors.centerIn: parent
                spacing: barWindow ? barWindow.cs(6) : 6
                Text {
                    text: textRoot.glyph !== "" ? textRoot.glyph : textRoot.label
                    font.pixelSize: textRoot.glyph !== "" ? Math.round(textRoot.fontSize * 1.25) : textRoot.fontSize
                    font.family: textRoot.glyph !== "" ? ThemeBackend.iconFont : textRoot.fontFamily
                    color: ThemeBackend.mauve
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: textRoot.valueText
                    font.pixelSize: textRoot.fontSize
                    font.family: textRoot.fontFamily
                    font.weight: Font.Medium
                    color: textRoot.valueColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Row {
            id: textRow
            visible: !root.isVertical && !textRoot.orbitChip
            anchors.verticalCenter: parent.verticalCenter
            spacing: barWindow ? barWindow.cs(5) : 5
            Text {
                text: textRoot.label
                font.pixelSize: textRoot.fontSize
                font.family: textRoot.fontFamily
                font.bold: true
                color: ThemeBackend.subtext0
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "|"
                font.pixelSize: textRoot.fontSize
                font.family: textRoot.fontFamily
                color: ThemeBackend.overlay0
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: textRoot.valueText
                font.pixelSize: textRoot.fontSize
                font.family: textRoot.fontFamily
                color: textRoot.valueColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    AxisFlow {
        id: sysLayout
        vertical: root.isVertical
        anchors.centerIn: parent
        spacing: (ThemeBackend.orbit && root.isMinimal && !root.isVertical) ? (barWindow ? barWindow.cs(4) : 4) : root.isMinimal
            ? (barWindow ? barWindow.cs(root.isCompact ? 10 : 12) : (root.isCompact ? 10 : 12))
            : (barWindow ? barWindow.cs(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6))
        property int circleSize: root.circleSize

        Repeater {
            model: root.activeStats

            Item {
                id: stat
                readonly property string statType: modelData
                property real value: {
                    if (statType === "cpu") return isNaN(SysData.cpu) ? 0 : SysData.cpu / 100.0;
                    if (statType === "ram") return isNaN(SysData.ramPercent) ? 0 : SysData.ramPercent / 100.0;
                    if (statType === "temp") return isNaN(SysData.temp) ? 0 : Math.max(0, Math.min(1, SysData.temp / 100.0));
                    if (statType === "disk") return isNaN(SysData.diskPercent) ? 0 : SysData.diskPercent / 100.0;
                    return 0;
                }
                property string textVal: {
                    if (statType === "temp") return isNaN(SysData.temp) ? "0" : Math.round(SysData.temp).toString();
                    return "";
                }
                property string icon: {
                    if (statType === "cpu") return String.fromCodePoint(0xF035B);
                    if (statType === "ram") return String.fromCodePoint(0xF035C);
                    if (statType === "temp") return String.fromCodePoint(0xF050F);
                    if (statType === "disk") return String.fromCodePoint(0xF0A0);
                    return "";
                }
                property color accentColor: {
                    if (statType === "cpu") return Qt.tint(root.basePrimary, Qt.rgba(1.0, 0.22, 0.22, 0.25));
                    if (statType === "ram") return Qt.lighter(root.basePrimary, 1.15);
                    if (statType === "temp") return Qt.darker(root.basePrimary, 1.15);
                    if (statType === "disk") return Qt.darker(root.basePrimary, 1.35);
                    return root.basePrimary;
                }
                readonly property string label: {
                    if (statType === "cpu") return "CPU";
                    if (statType === "ram") return "RAM";
                    if (statType === "temp") return "TEMP";
                    if (statType === "disk") return "DISK";
                    return statType.toUpperCase();
                }
                readonly property string valueText: {
                    if (statType === "temp") return (isNaN(SysData.temp) ? 0 : Math.round(SysData.temp)) + "°";
                    return Math.round(Math.max(0, Math.min(1, value)) * 100) + "%";
                }

                implicitWidth: statLoader.item ? statLoader.item.implicitWidth : 0
                implicitHeight: statLoader.item ? statLoader.item.implicitHeight : 0
                width: implicitWidth
                height: implicitHeight

                Loader {
                    id: statLoader
                    anchors.centerIn: parent
                    sourceComponent: root.isMinimal ? textComp : ringComp
                }
                Component {
                    id: ringComp
                    SysMonCircle {
                        value: stat.value
                        textVal: stat.textVal
                        icon: stat.icon
                        accentColor: stat.accentColor
                    }
                }
                Component {
                    id: textComp
                    SysMonText {
                        label: stat.label
                        valueText: stat.valueText
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: !(root.activeTarget && root.activeTarget.isPreview)
        onClicked: {
            FloatingController.showSystemUsage(root.barWindow ? root.barWindow.screen : null);
        }
    }
}
