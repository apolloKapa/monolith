import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root
    implicitWidth: Math.max(120, (root.maxNeededWidth > 0 ? root.maxNeededWidth : 28) * (root.options ? root.options.length : 1))
    implicitHeight: 32

    property var options: ["x", "y"]
    property int currentIndex: 0

    property color accentColor: ThemeBackend.blue
    property color baseColor: "#1affffff"
    property color textColor: ThemeBackend.text
    property color activeTextColor: ThemeBackend.crust

    property int cornerRadius: 8
    property int smallRadius: 2
    // inner corners of the selection: square-ish segments normally, but liquid glass draws the
    // selection as a floating pill, where small inner corners looked square (and visibly
    // rounded up when picking an end option)
    // Material: the whole switch is a pill and the selection a smaller pill floating inside it
    // floating: the pill look in any (non-square) style, not only Material
    property bool floating: false
    readonly property bool pillMode: (ThemeBackend.pill || floating) && !ThemeBackend.square
    readonly property real pillInset: pillMode ? 3 : 0
    readonly property real outerRadius: pillMode ? height / 2 : cornerRadius
    readonly property real innerRadius: pillMode ? Math.max(0, height / 2 - pillInset) : (ThemeBackend.liquidGlass ? cornerRadius : smallRadius)
    readonly property real endRadius: pillMode ? innerRadius : cornerRadius
    property int fontPixelSize: 11
    property int minFontPixelSize: 7
    property bool enabled: true
    property string switchSound: "reusables/switch/sfx.wav"

    signal valueChanged(int index, string value)
    signal toggled(int index)
    signal clicked()

    property real flashOpacity: 0.0
    property real popScale: 1.0
    readonly property bool glassActive: baseGlass.active

    property int itemsRevision: 0
    property real maxNeededWidth: 0
    property real totalNeededWidth: 0
    property var allocatedWidths: []

    function recalculateLayout() {
        var count = root.options ? root.options.length : 0;
        if (count === 0) {
            root.allocatedWidths = [];
            return;
        }

        var needs = [];
        var totalNeeded = 0;
        var maxNeeded = 0;

        for (var i = 0; i < count; i++) {
            var it = tabsRepeater.itemAt(i);
            var req = it ? it.fitWidth : 28;
            needs.push(req);
            totalNeeded += req;
            if (req > maxNeeded) {
                maxNeeded = req;
            }
        }

        root.maxNeededWidth = maxNeeded;
        root.totalNeededWidth = totalNeeded;

        var availableW = root.width;
        if (availableW <= 0) {
            availableW = Math.max(120, maxNeeded * count);
        }

        var equalW = availableW / count;
        var widths = [];

        if (maxNeeded <= equalW) {
            for (var i = 0; i < count; i++) {
                widths.push(equalW);
            }
        } else if (availableW >= totalNeeded) {
            var totalDeficit = 0;
            var totalSurplus = 0;

            for (var i = 0; i < count; i++) {
                if (needs[i] > equalW) {
                    totalDeficit += (needs[i] - equalW);
                } else {
                    totalSurplus += (equalW - needs[i]);
                }
            }

            var f = totalSurplus > 0 ? (totalDeficit / totalSurplus) : 0;
            if (f > 1.0) f = 1.0;

            for (var i = 0; i < count; i++) {
                if (needs[i] > equalW) {
                    widths.push(needs[i]);
                } else {
                    widths.push(equalW - f * (equalW - needs[i]));
                }
            }
        } else {
            for (var i = 0; i < count; i++) {
                widths.push(totalNeeded > 0 ? (availableW * (needs[i] / totalNeeded)) : equalW);
            }
        }

        root.allocatedWidths = widths;
    }

    onWidthChanged: recalculateLayout()
    onOptionsChanged: recalculateLayout()
    onFontPixelSizeChanged: recalculateLayout()

    property real bgOpacity: 1.0
    function withBgOpacity(c) { return Qt.rgba(c.r, c.g, c.b, c.a * root.bgOpacity); }

    Rectangle {
        id: bgShape
        anchors.fill: parent
        radius: ThemeBackend.rad(root.outerRadius)
        color: ThemeBackend.liquidGlass ? "transparent" : root.withBgOpacity(root.baseColor)
        clip: !baseGlass.active
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: (180) * ThemeBackend.animScale } }
        Behavior on opacity { NumberAnimation { duration: (180) * ThemeBackend.animScale } }

        scale: root.popScale
        Behavior on scale { NumberAnimation { duration: (250) * ThemeBackend.animScale; easing.type: Easing.OutQuint } }

        GlassFill {
            id: baseGlass
            anchors.fill: parent
            radius: ThemeBackend.rad(root.outerRadius)
            tintColor: root.baseColor
            tintAmount: 0.22 * root.bgOpacity
        }

        Rectangle {
            id: activeTabHighlight
            property int prevIdx: 0
            property int curIdx: root.currentIndex

            onCurIdxChanged: {
                if (curIdx > prevIdx) { rightAnim.duration = (200) * ThemeBackend.animScale; leftAnim.duration = (350) * ThemeBackend.animScale; }
                else if (curIdx < prevIdx) { leftAnim.duration = (200) * ThemeBackend.animScale; rightAnim.duration = (350) * ThemeBackend.animScale; }
                prevIdx = curIdx;
            }

            readonly property Item currentItem: (root.itemsRevision >= 0 && tabsRepeater && root.options && root.currentIndex >= 0 && root.currentIndex < tabsRepeater.count)
                ? tabsRepeater.itemAt(root.currentIndex)
                : null

            property real targetLeft: currentItem ? currentItem.x : 0
            property real targetRight: currentItem ? (currentItem.x + currentItem.width) : 0

            readonly property bool isMoving: Math.abs(actualLeft - targetLeft) > 0.5 || Math.abs(actualRight - targetRight) > 0.5
            property real lift: (baseGlass.active && isMoving) ? 1.0 : 0.0
            Behavior on lift { NumberAnimation { duration: (240) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
            scale: 1.0 + 0.16 * lift
            transformOrigin: Item.Center

            property real actualLeft: targetLeft
            property real actualRight: targetRight

            Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: (250) * ThemeBackend.animScale; easing.type: Easing.OutExpo } }
            Behavior on actualRight { NumberAnimation { id: rightAnim; duration: (250) * ThemeBackend.animScale; easing.type: Easing.OutExpo } }

            y: root.pillInset
            height: bgShape.height - root.pillInset * 2
            x: actualLeft + root.pillInset
            width: Math.max(0, actualRight - actualLeft - root.pillInset * 2)
            z: highlightGlass.active ? 2 : 0

            topLeftRadius: ThemeBackend.rad((!I18n.rtl ? root.currentIndex === 0 : root.currentIndex === root.options.length - 1) ? root.endRadius : root.innerRadius)
            bottomLeftRadius: ThemeBackend.rad((!I18n.rtl ? root.currentIndex === 0 : root.currentIndex === root.options.length - 1) ? root.endRadius : root.innerRadius)
            topRightRadius: ThemeBackend.rad((!I18n.rtl ? root.currentIndex === root.options.length - 1 : root.currentIndex === 0) ? root.endRadius : root.innerRadius)
            bottomRightRadius: ThemeBackend.rad((!I18n.rtl ? root.currentIndex === root.options.length - 1 : root.currentIndex === 0) ? root.endRadius : root.innerRadius)

            Behavior on topLeftRadius { NumberAnimation { duration: (180) * ThemeBackend.animScale } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: (180) * ThemeBackend.animScale } }
            Behavior on topRightRadius { NumberAnimation { duration: (180) * ThemeBackend.animScale } }
            Behavior on bottomRightRadius { NumberAnimation { duration: (180) * ThemeBackend.animScale } }

            color: ThemeBackend.liquidGlass ? "transparent" : root.accentColor

            Behavior on color { ColorAnimation { duration: (180) * ThemeBackend.animScale } }

            GlassFill {
                id: highlightGlass
                anchors.fill: parent
                topLeftRadius: ThemeBackend.rad(activeTabHighlight.topLeftRadius)
                topRightRadius: ThemeBackend.rad(activeTabHighlight.topRightRadius)
                bottomLeftRadius: ThemeBackend.rad(activeTabHighlight.bottomLeftRadius)
                bottomRightRadius: ThemeBackend.rad(activeTabHighlight.bottomRightRadius)
                tintColor: root.accentColor
                tintAmount: 0.4
                shadow: 1
                press: 0.35 + 0.65 * activeTabHighlight.lift
                pulse: Math.min(1, root.flashOpacity * 2.5)
            }
        }

        Row {
            id: tabsRow
            layoutDirection: I18n.layoutDirection
            anchors.fill: parent
            spacing: 0
            z: highlightGlass.active ? 3 : 1

            Repeater {
                id: tabsRepeater
                model: root.options
                onCountChanged: root.recalculateLayout()
                onItemAdded: root.itemsRevision++
                onItemRemoved: root.itemsRevision++

                Item {
                    id: optionItem
                    required property string modelData
                    required property int index

                    readonly property real fitWidth: Math.max(28, Math.ceil(optMetrics.width) + 10)

                    width: (root.allocatedWidths && root.allocatedWidths.length > optionItem.index)
                        ? root.allocatedWidths[optionItem.index]
                        : (root.options && root.options.length > 0 ? (parent.width / root.options.length) : 0)
                    height: parent.height

                    Component.onCompleted: root.recalculateLayout()

                    TextMetrics {
                        id: optMetrics
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Normal
                        font.pixelSize: root.fontPixelSize
                        text: optionItem.modelData
                        onWidthChanged: root.recalculateLayout()
                    }

                    Rectangle {
                        anchors.fill: parent
                        topLeftRadius: ThemeBackend.rad(optionItem.index === 0 ? root.outerRadius : root.innerRadius)
                        bottomLeftRadius: ThemeBackend.rad(optionItem.index === 0 ? root.outerRadius : root.innerRadius)
                        topRightRadius: ThemeBackend.rad(optionItem.index === root.options.length - 1 ? root.outerRadius : root.innerRadius)
                        bottomRightRadius: ThemeBackend.rad(optionItem.index === root.options.length - 1 ? root.outerRadius : root.innerRadius)
                        color: (root.currentIndex === optionItem.index || optionGlass.active) ? "transparent" : (optionMa.containsMouse ? "#1affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: (200) * ThemeBackend.animScale } }

                        GlassFill {
                            id: optionGlass
                            anchors.fill: parent
                            topLeftRadius: ThemeBackend.rad(parent.topLeftRadius)
                            topRightRadius: ThemeBackend.rad(parent.topRightRadius)
                            bottomLeftRadius: ThemeBackend.rad(parent.bottomLeftRadius)
                            bottomRightRadius: ThemeBackend.rad(parent.bottomRightRadius)
                            allowed: !!root && optionMa.containsMouse && root.enabled && root.currentIndex !== optionItem.index
                            tintColor: root ? root.textColor : "transparent"
                            tintAmount: 0.12
                            tintStrength: 1.0
                            press: optionMa.pressed ? 0.8 : 0.25
                        }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: optionItem.modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: ThemeBackend.material ? Font.Medium : Font.Normal
                        font.pixelSize: root.fontPixelSize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: root.minFontPixelSize
                        color: (root.currentIndex === optionItem.index && !ThemeBackend.liquidGlass) ? root.activeTextColor : root.textColor
                        Behavior on color { ColorAnimation { duration: (200) * ThemeBackend.animScale } }
                    }

                    MouseArea {
                        id: optionMa
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (!root.enabled) return;
                            if (root.currentIndex !== optionItem.index) {
                                root.currentIndex = optionItem.index;
                                root.valueChanged(optionItem.index, optionItem.modelData);
                                root.toggled(optionItem.index);
                            }
                            btnPopAnim.start();
                            root.flashOpacity = 0.2;
                            btnFlashAnim.start();
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.switchSound);
                            }
                            root.clicked();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.rad(root.outerRadius)
            color: "#ffffff"
            opacity: root.flashOpacity
            visible: !baseGlass.active
            z: 2
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: (350) * ThemeBackend.animScale; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.04; duration: (100) * ThemeBackend.animScale; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: (350) * ThemeBackend.animScale; easing.type: Easing.OutQuint }
    }
}
