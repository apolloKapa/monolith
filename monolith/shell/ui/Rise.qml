import QtQuick
import "../core"

// Put one inside anything on a page: it comes up and fades in when it's made, the lower (and
// the further right) it sits, the later, so a page's parts arrive one after another. (Kept
// quick: up to a third of a second of waiting made menus feel late.)
Item {
    id: rise
    property Item target: parent
    property real delay: -1            // ms; -1: from where it sits
    property bool on: true
    property real t: on ? 0 : 1
    visible: false
    width: 0; height: 0
    Translate { id: lift; y: (1 - rise.t) * 16 }
    Binding { target: rise.target; property: "opacity"; value: rise.t; when: rise.on && rise.t < 1 }
    SequentialAnimation {
        id: go
        PauseAnimation { id: wait }
        NumberAnimation { target: rise; property: "t"; to: 1; duration: Theme.ms(280); easing.type: Easing.OutCubic }
    }
    // shown again (a tab switched back, a section appearing): it comes up again
    Connections {
        target: rise.target
        enabled: rise.on && !!rise.target
        function onVisibleChanged() {
            if (!rise.target.visible || go.running) return;
            go.stop(); rise.t = 0;
            wait.duration = Theme.ms(rise.delay >= 0 ? rise.delay : Math.min(120, Math.max(0, rise.target.y) * 0.15));
            go.start();
        }
    }
    Timer {
        interval: 1; running: rise.on
        onTriggered: {
            const it = rise.target;
            if (!it) { rise.t = 1; return; }
            it.transform = [lift];
            wait.duration = Theme.ms(rise.delay >= 0 ? rise.delay : Math.min(150, Math.max(0, it.y) * 0.18 + Math.max(0, it.x) * 0.05));
            go.start();
        }
    }
}
