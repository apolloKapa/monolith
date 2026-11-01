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
        value: (isNaN(SysData.cpu) ? 0 : SysData.cpu) / 100
        valueText: (isNaN(SysData.cpu) ? 0 : SysData.cpu) + "%"
        label: I18n.t("quickactions.systemusage.cpu")
        icon: String.fromCodePoint(0xF035B)
    }
}
