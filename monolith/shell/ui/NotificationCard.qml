import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import "../core"

// One notification: the app's icon (or the notification's image) in a bubble, the summary
// and body, and its actions as chips. Click runs the default action; × dismisses.
Pressable {
    id: card
    required property var notif
    property bool popup: false
    signal closed()

    implicitHeight: body.implicitHeight + 24
    radius: Theme.corner(56, 6)
    color: popup ? Theme.card : Theme.containerHigh
    border.width: popup ? 1 : 0
    border.color: Theme.hairline

    readonly property string iconSrc: notif.image !== "" ? notif.image
        : (notif.appIcon !== "" ? (notif.appIcon.startsWith("/") || notif.appIcon.startsWith("file:") ? notif.appIcon : Quickshell.iconPath(notif.appIcon, true)) : "")
    readonly property bool urgent: notif.urgency === NotificationUrgency.Critical

    onClicked: {
        const def = notif.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        card.resetPress();
        card.closed();
    }

    // swipe it sideways to dismiss: past a third of its width (or flicked) it goes (slides off,
    // or falls down the screen: Settings → Notifications), otherwise it springs back. While it's
    // swiped, a copy in a full-screen layer (core/Throw, status/Thrown) follows the pointer, so
    // the edge of this card's own small window can't cut it off.
    property bool swipeable: true
    property real swipeX: 0
    property bool flying: false
    // where this card's window sits on its screen (a corner popup's window isn't at 0,0)
    property point windowOffset: Qt.point(0, 0)
    property string screenName: ""      // the screen it's on (in a menu: the menu's screen)
    property int throwId: -1            // its copy, while swiped
    property bool handed: false         // the copy is on screen: this one hides
    property var pending: null          // let go before the copy was ready: what to do then
    transform: Translate { x: card.swipeX }
    opacity: handed ? 0 : Math.max(0, 1 - Math.abs(swipeX) / (width * 1.1))
    Behavior on swipeX { enabled: !swipe.active && !card.resetting; NumberAnimation { duration: card.flying ? 180 : 260; easing.type: card.flying ? Easing.InCubic : Easing.OutBack } }

    // the swipe starts: photograph the card where it is, the copy takes over from there
    function startCopy() {
        if (!Throw.on || !card.Window.window || throwId >= 0) return;
        const p = card.mapToItem(null, -swipeX, 0);
        const scr = card.screenName || HubState.screenName || Niri.focusedOutput || "";
        const sx = swipeX;
        swipeX = 0;                       // photographed in place; the copy gets the offset
        const ok = card.grabToImage(r => {
            card.throwId = Throw.launch(scr, r.url, p.x + card.windowOffset.x, p.y + card.windowOffset.y, card.width, card.height);
            Throw.dragTo(card.throwId, card.swipeX);
            handoff.restart();
        });
        swipeX = sx;
        if (!ok) throwId = -1;
    }
    function handOver() {
        if (handed || throwId < 0) return;
        handed = true;
        if (pending) { const p = pending; pending = null; p(); }
    }
    Connections {
        target: Throw
        function onReady(id) { if (id === card.throwId) card.handOver(); }
        function onHome(id) { if (id === card.throwId) { card.throwId = -1; card.resetting = true; card.swipeX = 0; card.resetting = false; card.handed = false; } }
    }
    // never stuck if the copy doesn't show (a screen that went away)
    Timer { id: handoff; interval: 400; onTriggered: card.handOver() }

    DragHandler {
        id: swipe
        enabled: card.swipeable && !card.flying
        target: null
        yAxis.enabled: false
        dragThreshold: 8
        property real lastX: 0
        property real lastT: 0
        property real speed: 0
        onTranslationChanged: {
            const now = Date.now();
            if (now > lastT) speed = (translation.x - lastX) / (now - lastT);
            lastX = translation.x; lastT = now;
            card.swipeX = translation.x;
            if (card.throwId >= 0) Throw.dragTo(card.throwId, translation.x);
        }
        onActiveChanged: {
            if (active) { lastX = 0; lastT = Date.now(); speed = 0; card.startCopy(); return; }
            const go = Math.abs(card.swipeX) > card.width / 3 || Math.abs(speed) > 1.2;
            const dir = card.swipeX !== 0 ? Math.sign(card.swipeX) : (Math.sign(speed) || 1);
            card.release(go, dir, speed);
        }
    }
    function release(go, dir, speed) {
        card.resetPress();
        if (go) flying = true;
        if (throwId < 0) {
            // no copy (animations off, or it couldn't be made): as before, in its own window
            if (go) { swipeX = dir * (width + 40); gone.restart(); } else swipeX = 0;
            return;
        }
        const id = throwId;
        const act = () => {
            if (go) {
                const fast = Math.abs(speed) * 1000;
                const vx = dir * (Throw.mode === "fall" ? Math.max(380, Math.min(2600, fast)) : Math.max(1100, Math.min(3200, fast)));
                Throw.letGo(id, vx, -520, Throw.mode);
                card.closed();
            } else {
                // the real card goes back in place now, while it's still hidden (it would
                // otherwise show where it was let go and spring back a second time)
                card.resetting = true; card.swipeX = 0; card.resetting = false;
                Throw.springBack(id);
            }
        };
        if (handed) act(); else pending = act;
    }
    Timer { id: gone; interval: 190; onTriggered: card.closed() }
    // reused for the next notification (the island's): back in place at once
    property bool resetting: false
    onNotifChanged: { resetting = true; flying = false; handed = false; pending = null; throwId = -1; handoff.stop(); swipeX = 0; resetting = false; resetPress(); closeBtn.resetPress(); }

    RowLayout {
        id: body
        x: 12; y: 12
        width: parent.width - 24
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Theme.corner(40, 4)
            color: card.urgent ? Qt.alpha(Theme.danger, 0.3) : Theme.control
            clip: true
            Image {
                anchors.centerIn: parent
                width: card.notif.image !== "" ? parent.width : 24
                height: width
                source: card.iconSrc
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }
            Icon { anchors.centerIn: parent; name: card.urgent ? "priority_high" : "notifications"; size: 20; visible: card.iconSrc === "" }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Label { text: card.notif.appName || "Notification"; muted: true; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Pressable {
                    id: closeBtn
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    color: "transparent"
                    onClicked: { closeBtn.resetPress(); card.notif.dismiss(); card.closed(); }
                    Icon { anchors.centerIn: parent; name: "close"; size: 16; color: Theme.subtext }
                }
            }
            Label { Layout.fillWidth: true; text: card.notif.summary; strong: true; wrapMode: Text.Wrap; maximumLineCount: 2; Balance {} }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif.body
                textFormat: Text.StyledText
                muted: true
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 3 : 6
                font.pixelSize: Theme.sizeSmall + 1
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: card.notif.actions.filter(a => a.identifier !== "default").length > 0
                Repeater {
                    model: card.notif.actions.filter(a => a.identifier !== "default")
                    Pressable {
                        required property var modelData
                        height: 30
                        width: actLabel.implicitWidth + 24
                        color: Theme.selected
                        onClicked: { resetPress(); modelData.invoke(); card.closed(); }
                        Label { id: actLabel; anchors.centerIn: parent; width: Math.min(implicitWidth, 200); text: modelData.text; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
        }
    }
}
