import QtQuick
import "../../../reusables"
import "../../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 100
    property real minHeight: 90
    property real maxWidth: 400
    property real maxHeight: 400
    property real minAspect: 0.6
    property real maxAspect: 2.0
    property bool isRound: false

    property bool isSubscribed: false
    function updateSubscription() {
        if (root.visible && !root.isSubscribed) { SysData.subscribe(); root.isSubscribed = true; }
        else if (!root.visible && root.isSubscribed) { SysData.unsubscribe(); root.isSubscribed = false; }
    }
    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: if (root.isSubscribed) { SysData.unsubscribe(); root.isSubscribed = false; }

    UsageRingCard {
        value: Math.min(1, (isNaN(SysData.temp) ? 0 : SysData.temp) / 100)
        valueText: (isNaN(SysData.temp) ? 0 : SysData.temp) + "°"
        label: I18n.t("quickactions.systemusage.temp")
        icon: String.fromCodePoint(0xF050F)
    }
}
