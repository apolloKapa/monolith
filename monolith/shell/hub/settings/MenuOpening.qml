import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Animations → Menu opening: how fast Monolith's own windows (the launcher, Settings, the control
// centre and every other menu) come in and go, on their own, on top of the main speed in Speeds &
// windows. Theme.menuInSpeed / menuOutSpeed; the island and the pages read Theme.menuInMs,
// menuGoMs, menuIn(n) and menuOut(n).
ColumnLayout {
    id: sec
    spacing: 8

    function took(v, what) {
        return v === 1 ? "1 × is normal. Higher is faster, lower is slower"
            : what + " takes " + (Math.round(100 / v) / 100) + " × as long as normal (" + (v > 1 ? "faster" : "slower") + ")";
    }

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: Theme.animOn
            ? "How fast a Monolith menu (the launcher, Settings, the control centre…) opens and closes. Everything else keeps the speed in Speeds & windows. Opening never takes less than " + Theme.lowIn + " ms, closing " + Theme.lowOut + " ms: shorter than that it stops looking like movement. Point at the preview to play it."
            : "Animations are off (Speeds & windows), so menus appear at once."
    }

    // ── the preview: a little menu opening and closing at these speeds ──
    SmoothRect {
        id: stage
        smoothing: 0
        visible: Theme.animOn
        Layout.fillWidth: true
        Layout.preferredHeight: 170
        radius: Theme.corner(60, 10)
        color: Theme.m("surface_container_lowest", "#101014")
        border.width: 1; border.color: Qt.alpha(Theme.text, 0.06)
        clip: true
        HoverHandler { id: stageHover }
        // 0 closed … 1 open
        property real p: 0
        property bool opening: true
        // the bar the menu belongs to
        SmoothRect {
            id: bar
            width: 150; height: 12
            radius: Theme.rnd(6)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barBottom ? parent.height - height - 10 : 10
            color: Theme.control
        }
        SmoothRect {
            id: card
            width: 230; height: 108
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barBottom ? bar.y - height - 8 : bar.y + bar.height + 8
            radius: Theme.corner(60, 4)
            color: Theme.containerHigh
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            opacity: Math.min(1, stage.p * 1.6)
            scale: 0.9 + 0.1 * stage.p
            transformOrigin: Theme.barBottom ? Item.Bottom : Item.Top
            Column {
                x: 14; y: 14; spacing: 9
                width: parent.width - 28
                Rectangle { width: parent.width * 0.5; height: 9; radius: Theme.rnd(4); color: Theme.accent }
                Repeater {
                    model: [0.9, 0.7, 0.8, 0.55]
                    Rectangle { required property real modelData; width: parent.width * modelData; height: 7; radius: Theme.rnd(3); color: Theme.control }
                }
            }
        }
        Label {
            anchors.right: parent.right; anchors.rightMargin: 14
            y: Theme.barBottom ? 12 : parent.height - height - 12
            muted: true; font.pixelSize: Theme.sizeSmall
            text: (stage.opening ? "Opening: " + Theme.menuInMs : "Closing: " + Theme.menuGoMs) + " ms"
        }
        SequentialAnimation {
            id: play
            running: Theme.animOn && stage.visible && stageHover.hovered
            loops: Animation.Infinite
            onRunningChanged: if (!running) { stage.p = 0; stage.opening = true; }
            PropertyAction { target: stage; property: "opening"; value: true }
            NumberAnimation { target: stage; property: "p"; to: 1; duration: Theme.menuInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
            PauseAnimation { duration: 700 }
            PropertyAction { target: stage; property: "opening"; value: false }
            NumberAnimation { target: stage; property: "p"; to: 0; duration: Theme.menuGoMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
            PauseAnimation { duration: 500 }
        }
        // a new speed starts it over at once
        Connections {
            target: Theme
            function onMenuInMsChanged() { if (play.running) play.restart(); }
            function onMenuGoMsChanged() { if (play.running) play.restart(); }
        }
    }

    SettingRow {
        key: "theme.menuInSpeed"; def: 1
        visible: Theme.animOn
        icon: "open_in_full"; title: "Opening speed"
        desc: sec.took(Theme.menuInSpeed, "A menu opening")
        NumberBox { from: 0.25; to: 4; step: 0.05; decimals: 2; unit: "×"; value: Theme.menuInSpeed; onMoved: v => Store.set("theme.menuInSpeed", v) }
    }
    SettingRow {
        key: "theme.menuOutSpeed"; def: 1
        visible: Theme.animOn
        icon: "close_fullscreen"; title: "Closing speed"
        desc: sec.took(Theme.menuOutSpeed, "A menu closing")
        NumberBox { from: 0.25; to: 4; step: 0.05; decimals: 2; unit: "×"; value: Theme.menuOutSpeed; onMoved: v => Store.set("theme.menuOutSpeed", v) }
    }
    // how menus open, and close the same way back (Theme.menuAnim); a style with its own effect
    // (Style effect speed below) draws its menus its way instead
    readonly property var menuAnimInfo: ({
        zoom: ["zoom_out_map", "Zoom", "A menu fades in while growing a little, and shrinks away"],
        pop: ["bubble_chart", "Pop", "A menu springs up from smaller, overshooting a touch, and shrinks back down"],
        slide: ["north", "Slide up", "A menu rises into place, and sinks away"],
        drop: ["south", "Drop down", "A menu comes down into place, and lifts away"],
        fade: ["gradient", "Fade", "A menu just fades in, and out"],
        unfold: ["unfold_more", "Unfold", "A menu opens out of a thin bright line through its middle, and folds back into it"]
    })
    SettingRow {
        keys: ["theme.menuAnim", "theme.effects.unfold"]
        visible: Theme.animOn && !Theme.cyber
        icon: (sec.menuAnimInfo[Theme.menuAnim] || sec.menuAnimInfo.zoom)[0]; title: "How menus open"
        desc: (sec.menuAnimInfo[Theme.menuAnim] || sec.menuAnimInfo.zoom)[2]
        Dropdown {
            width: 220
            opts: Theme.menuAnims.map(k => [k, sec.menuAnimInfo[k][1]])
            value: Theme.menuAnim
            onPicked: v => { Store.set("theme.menuAnim", v); Store.unset("theme.effects.unfold"); }
        }
    }
    // the style's own effect (Cyberpunk's glitch, Doodle drawing menus in, Concrete crumbling…):
    // its speed on its own, on top of the speeds above and the main speed
    SettingRow {
        key: "theme.fxSpeed"; def: 1;
        visible: Theme.animOn && Theme.cyber
        icon: "auto_awesome"; title: "Style effect speed"
        desc: { const v = Theme.fxSpeed; const what = Look.style.name + "'s own effect (how its menus appear and go)"; return v === 1 ? what + ". 1 × is normal" : what + " takes " + (Math.round(100 / v) / 100) + " × as long" + (v > 1 ? " (faster)" : " (slower)"); }
        NumberBox { from: 0.25; to: 3; step: 0.05; decimals: 2; unit: "×"; value: Theme.fxSpeed; onMoved: v => Store.set("theme.fxSpeed", v) }
    }
}
