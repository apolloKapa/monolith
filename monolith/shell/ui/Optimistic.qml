import QtQuick

// Optimistic state: a control shows what you asked for at once, while the system catches up.
// Bind `actual` to what the system reports and show `value`. set(v) when the user changes it:
// `value` is v straight away, and stays v (whatever stale reports come in, like a poll that ran
// before the change landed) until `actual` agrees. If it never does within `patience`, the
// control goes back to the real state and `failed()` fires (shake it, say so).
QtObject {
    id: o
    property var actual
    property var wanted: undefined
    property int patience: 6000
    readonly property bool pending: wanted !== undefined
    readonly property var value: pending ? wanted : actual
    signal failed()

    function set(v) {
        if (v === actual) { wanted = undefined; timer.stop(); return; }
        wanted = v;
        timer.restart();
    }
    onActualChanged: if (pending && actual === wanted) { wanted = undefined; timer.stop(); }

    property Timer timer: Timer {
        interval: o.patience
        onTriggered: if (o.pending) { o.wanted = undefined; o.failed(); }
    }
}
