import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"
import "../ui"
import "../hub/settings"

// The welcome: shown the first time Monolith starts (and with `monolith welcome`, or Settings →
// About). Over your wallpaper, blurred, a short tour that makes the desktop yours as you go:
// hello, a look (theme style, dark or light, a wallpaper), the bar's style, the dock, and how to
// get around (your own keybinds, read from niri's config). Every choice applies straight away.
// Enter / → next, ← back, Esc skips.
PanelWindow {
    id: wel
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.welcomeOpen && !HubState.wallOpen
        && (HubState.welcomeScreen === "" ? modelData === Quickshell.screens[0] : HubState.welcomeScreen === modelData.name)
    visible: shown || fade.running || t > 0.01
    WlrLayershell.namespace: "monolith-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown && !HubState.authOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // 0 → 1 as it comes in
    property real t: 0
    NumberAnimation on t { id: fade; running: false }
    onShownChanged: {
        fade.stop(); fade.from = t; fade.to = shown ? 1 : 0; fade.duration = shown ? 700 : 340; fade.easing.type = Easing.OutCubic; fade.start();
        if (shown) { keys.forceActiveFocus(); if (!played) startIntro(); }
    }

    property int step: 0
    readonly property var steps: [["hello", "Hello"], ["look", "Your look"], ["bar", "Your bar"], ["dock", "The dock"], ["keys", "Getting around"], ["done", "All set"]]
    function go(d) { step = Math.max(0, Math.min(steps.length - 1, step + d)); }
    function finish() { skipIntro(); Store.set("welcome.done", true); HubState.welcomeOpen = false; step = 0; }
    // a page turning has its sound; the last page its own
    onStepChanged: if (shown && !intro) playWel(step === steps.length - 1 ? "done" : "step")

    // ── the intro ──
    // One clock, in milliseconds, that everything in the intro reads, so it all keeps time with
    // its sound (sounds/welcome/intro.wav, made by tools/make_welcome_sounds.py on the same
    // timings): a line of light draws across and the slab rises out of it (0-1.25 s), glowing a
    // little brighter as it settles; the card unfolds quietly out of the slab
    // (1.25-2.05) and the slab floats up into its place on it (1.65-2.35); the title comes in
    // letter by letter (2.05-3.3) and a shine runs across it (2.9-3.6); then the rest. A click or
    // a key skips it; with animations off (Settings) there is none.
    readonly property int introLen: 3800
    readonly property int hit: 1250
    property real clock: introLen
    readonly property bool intro: clock < introLen
    // played once each time the welcome opens (coming back from the wallpaper picker doesn't replay it)
    property bool played: false
    Connections { target: HubState; function onWelcomeOpenChanged() { if (!HubState.welcomeOpen) wel.played = false; } }
    NumberAnimation { id: introRun; target: wel; property: "clock"; from: 0; to: wel.introLen; duration: wel.introLen }
    function startIntro() {
        played = true; step = 0;
        if (!Theme.animOn) { clock = introLen; return; }
        clock = 0; introRun.restart();
        introSound.running = false;
        if (vol > 0) introSound.running = true;
    }
    function skipIntro() { if (!intro) return; introRun.stop(); clock = introLen; introSound.running = false; }
    // how far along [a, b] ms the clock is (0 … 1), and the curves the intro moves on
    function seg(a, b) { return Math.max(0, Math.min(1, (clock - a) / (b - a))); }
    function outCubic(x) { return 1 - Math.pow(1 - x, 3); }
    function inCubic(x) { return x * x * x; }
    function outExpo(x) { return x >= 1 ? 1 : 1 - Math.pow(2, -10 * x); }
    function outBack(x) { const c = 1.70158; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); }
    // a steady "random" number (0 … 1) for particle i, so every frame agrees where it is
    function rnd(i, k) { const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453; return x - Math.floor(x); }
    readonly property color glint: Qt.lighter(Theme.accent, 1.45)
    readonly property color tertiary: Theme.m("tertiary", Theme.accent)

    // where the card ends up, and where the slab sits on it (the hello page's mark)
    readonly property real cardW: Math.min(width - 80, 980)
    readonly property real cardH: Math.min(height - 80, 660)
    readonly property real markY: height / 2 - cardH / 2 + 36 + 0.08 * (cardH - 36 - 96) + 84

    // the shine across the title: in the intro, then now and then while the first page shows
    property real idleShine: 0
    SequentialAnimation {
        running: wel.visible && !wel.intro && wel.step === 0 && Theme.animOn
        loops: Animation.Infinite
        PauseAnimation { duration: 6000 }
        NumberAnimation { target: wel; property: "idleShine"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine }
        PropertyAction { target: wel; property: "idleShine"; value: 0 }
    }
    readonly property real shineAt: intro ? seg(2900, 3600) : idleShine

    // the sounds: played even when interface sounds are off (it's the first thing you see), at
    // their volume when they're on
    readonly property real vol: Sounds.on ? Sounds.volume : 0.6
    function playWel(name) { if (vol > 0) Sounds.playFile(Sounds.base + "/welcome/" + name + ".wav", vol); }
    // (a process of its own, so skipping the intro stops its sound too)
    Process {
        id: introSound
        command: ["pw-play", "--media-role", "Notification", "--volume", String(wel.vol),
            "-P", "{ \"application.name\": \"Monolith sounds\", \"media.role\": \"event\" }", Sounds.base + "/welcome/intro.wav"]
    }

    // a soft glow round a rounded rectangle (drawn by a shader; none on a Qt without it)
    component Glow: Loader {
        id: gl
        property real r: 0
        property real blurPx: 40
        property real spreadPx: 0
        property color tint: Theme.accent
        active: Theme.rectShadows
        source: "../ui/RectShadow.qml"
        onLoaded: {
            item.anchors.fill = gl;
            item.radius = Qt.binding(() => gl.r);
            item.blur = Qt.binding(() => gl.blurPx);
            item.spread = Qt.binding(() => gl.spreadPx);
            item.color = Qt.binding(() => gl.tint);
        }
    }

    readonly property string who: {
        const u = Quickshell.env("USER") || "";
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }

    // your keybinds: the Monolith ones, read from niri's config
    FileView { id: kb; path: Quickshell.env("HOME") + "/.config/niri/config/keybinds.kdl" }
    // on Hyprland: Monolith's keys file there (monolith.lua, or monolith.conf), written by
    // `monolith hyprland on` / the installer
    // (Monolith's folder: its keybinds and your my-keys; an older setup's monolith.lua/.conf too)
    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    FileView { id: hkLua; path: Niri.hyprland ? wel.hyprDir + "/monolith/keybinds.lua" : ""; printErrors: false }
    FileView { id: hkConf; path: Niri.hyprland ? wel.hyprDir + "/monolith/keybinds.conf" : ""; printErrors: false }
    FileView { id: hkMyLua; path: Niri.hyprland ? wel.hyprDir + "/monolith/my-keys.lua" : ""; printErrors: false }
    FileView { id: hkMyConf; path: Niri.hyprland ? wel.hyprDir + "/monolith/my-keys.conf" : ""; printErrors: false }
    FileView { id: hkOldLua; path: Niri.hyprland ? wel.hyprDir + "/monolith.lua" : ""; printErrors: false }
    FileView { id: hkOldConf; path: Niri.hyprland ? wel.hyprDir + "/monolith.conf" : ""; printErrors: false }
    function hyprKeyFor(pattern) {
        const word = pattern.replace(/"/g, "");
        let best = "";
        // hl.bind("SUPER + D", hl.dsp.exec_cmd(".../monolith msg toggle launcher"))
        for (const l of ((hkMyLua.text() || "") + "\n" + (hkLua.text() || "") + "\n" + (hkOldLua.text() || "")).split("\n")) {
            const m = l.match(/hl\.bind\("([^"]+)",\s*hl\.dsp\.exec_cmd\("([^"]*)"\)/);
            if (m && m[2].indexOf("monolith") !== -1 && m[2].trim().endsWith(" " + word)
                && (best === "" || m[1].split("+").length <= best.split("+").length)) best = m[1].replace(/\s*\+\s*/g, " + ");
        }
        // bind = SUPER SHIFT, S, exec, .../monolith screenshot
        for (const l of ((hkMyConf.text() || "") + "\n" + (hkConf.text() || "") + "\n" + (hkOldConf.text() || "")).split("\n")) {
            const m = l.match(/^\s*bindl?\s*=\s*([^,]*),\s*([^,]+),\s*exec,\s*(.*)$/);
            if (!m || m[3].indexOf("monolith") === -1 || !m[3].trim().endsWith(" " + word)) continue;
            const k = (m[1].trim() ? m[1].trim().split(/\s+/).join(" + ") + " + " : "") + m[2].trim();
            if (best === "" || k.split("+").length <= best.split("+").length) best = k;
        }
        return best.replace(/SUPER/g, "Super").replace(/SHIFT/g, "Shift").replace(/CTRL/g, "Ctrl").replace(/ALT/g, "Alt");
    }
    // the simplest binding for a command (fewest modifiers; the later one on a tie)
    function keyFor(pattern) {
        if (Niri.hyprland) return hyprKeyFor(pattern);
        let best = "";
        for (const l of (kb.text() || "").split("\n")) {
            const m = l.match(/^\s*([A-Za-z0-9_+]+)\s[^{]*\{\s*spawn\b(.*);\s*\}/);
            if (!m || m[2].indexOf("monolith") === -1 || !m[2].trim().endsWith(pattern)) continue;
            if (best === "" || m[1].split("+").length <= best.split("+").length) best = m[1];
        }
        return best.replace(/Mod\+/g, "Super+").replace(/\+/g, " + ");
    }
    readonly property var shortcuts: [
        ["search", "The launcher", '"launcher"', "Apps, files (/), commands (>), emoji (:)"],
        ["page_info", "Control center", '"system"', "Wi-Fi, sound, Bluetooth, night light, power"],
        ["settings", "Settings", '"settings"', "Everything that can change"],
        ["wallpaper", "Wallpapers", '"wallpaper"', "Your wallpapers; the colours follow"],
        ["music_note", "Music", '"music"', "What's playing, the equaliser, lyrics"],
        ["content_paste", "Clipboard", '"clipboard"', "What you copied"],
        ["screenshot_region", "Screenshot", '"screenshot"', "Draw a box, or the whole screen"],
        ["deployed_code", "AppImages", '"appimages"', "Drop one and it's an app"],
        ["lock", "Lock", '"lock"', "The lock screen"],
        ["keyboard_command_key", "Every keybind", '"cheatsheet"', "All of them, searchable"]
    ].map(s => s.concat([keyFor(s[2])])).filter(s => s[4] !== "")

    // ── your wallpaper, blurred and dimmed ──
    Item {
        anchors.fill: parent
        opacity: wel.t
        // (an opaque floor under it, and the picture reaching past the screen's edges: a blur
        // fades out towards the edges of what it blurs, and the desktop showed through all round)
        Rectangle { anchors.fill: parent; color: Theme.m("surface", "#111") }
        Image {
            id: wp
            anchors.fill: parent
            anchors.margins: -120
            source: Wall.still(Wall.pathFor(wel.modelData.name))
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(wel.width / 3, wel.height / 3)
            visible: false
        }
        MultiEffect { anchors.fill: wp; source: wp; blurEnabled: true; blur: 1; blurMax: 64; saturation: 0.15; brightness: -0.12 }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.m("surface", "#111"), 0.35) }
                GradientStop { position: 1; color: Qt.alpha(Theme.m("surface", "#111"), 0.75) }
            }
        }
        // slow drifting light, in the accent colour
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: wel.width * (0.5 + 0.15 * index); height: width; radius: Theme.chamfer ? 0 : width / 2
                color: index === 1 ? wel.tertiary : Theme.accent
                opacity: 0.07
                property real a: index * 2.1
                NumberAnimation on a { from: index * 2.1; to: index * 2.1 + Math.PI * 2; duration: 40000 + index * 9000; loops: Animation.Infinite; running: wel.visible }
                x: wel.width * (0.5 + 0.3 * Math.cos(a)) - width / 2
                y: wel.height * (0.5 + 0.25 * Math.sin(a * 1.3)) - height / 2
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
            }
        }
        // motes of light drifting up, once the intro is over
        Item {
            anchors.fill: parent
            opacity: wel.intro ? wel.seg(2400, 3800) : 1
            Repeater {
                model: Theme.animOn ? 28 : 0
                Rectangle {
                    required property int index
                    readonly property real r0: wel.rnd(index, 4)
                    property real p: 0
                    NumberAnimation on p { from: 0; to: 1; duration: 16000 + 12000 * wel.rnd(index, 5); loops: Animation.Infinite; running: wel.visible }
                    readonly property real q: (p + r0) % 1
                    width: 2 + 3 * wel.rnd(index, 6); height: width; radius: Theme.chamfer ? 0 : width / 2
                    color: index % 3 === 0 ? wel.tertiary : wel.glint
                    x: wel.width * wel.rnd(index, 7) + 40 * Math.sin((q * 3 + r0) * Math.PI * 2)
                    y: wel.height * (1.05 - 1.1 * q)
                    // (in and out at the ends, twinkling a little on the way)
                    opacity: (0.18 + 0.22 * wel.rnd(index, 8)) * Math.sin(Math.PI * q) * (0.75 + 0.25 * Math.sin(q * 40 + index))
                }
            }
        }
        // a click skips the intro
        MouseArea { anchors.fill: parent; onClicked: wel.skipIntro() }
    }

    // the way through comes in piece by piece at the end of the intro
    function navIn(k) { return outBack(seg(2950 + k * 110, 3450 + k * 110)); }

    // ── the intro's line of light, behind the card ──
    Item {
        id: fxBack
        anchors.fill: parent
        visible: fx.visible
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // the line of light it rises out of
        Item {
            readonly property real w: 560 * wel.outExpo(wel.seg(150, 800))
            x: fxBack.cx - w / 2; y: fxBack.cy + 84 - 1
            width: w; height: 2
            opacity: wel.seg(150, 350) * (1 - wel.seg(wel.hit, wel.hit + 300))
            Glow { anchors.fill: parent; r: 1; blurPx: 22; tint: Qt.alpha(Theme.accent, 0.8) }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: "white" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }

    }

    // ── the card ──
    // In the intro it unfolds out of the slab: it grows from the slab's size to its own, with
    // what's on it (laid out at its full size all along, so nothing reflows) cut to it
    Rectangle {
        id: card
        readonly property real unfold: wel.outExpo(wel.seg(wel.hit, 2050))
        readonly property real fullR: Math.max(Theme.islandRadius, Theme.square ? 0 : 28)
        width: 84 + (wel.cardW - 84) * unfold
        height: 168 + (wel.cardH - 168) * unfold
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 30 * (1 - wel.t)
        opacity: Math.min(wel.t, wel.clock >= wel.hit ? 1 : 0)
        scale: 0.92 + 0.08 * wel.t
        radius: (Theme.square ? 0 : 18) + (fullR - (Theme.square ? 0 : 18)) * unfold
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        CardShadow {}

        Item {
            anchors.fill: parent
            clip: card.unfold < 1
            Item {
                id: inner
                width: wel.cardW; height: wel.cardH
                anchors.centerIn: parent
                opacity: wel.intro ? wel.seg(1700, 2000) : 1
                enabled: !wel.intro

                // the steps, sliding sideways
                Item {
                    id: pages
                    anchors.fill: parent
                    anchors.margins: 36
                    anchors.bottomMargin: 96
                    clip: true
                    Repeater {
                        model: wel.steps.length
                        Item {
                            id: pg
                            required property int index
                            width: pages.width; height: pages.height
                            readonly property int off: index - wel.step
                            x: off * 90
                            scale: off === 0 ? 1 : 0.96
                            opacity: off === 0 ? 1 : 0
                            visible: opacity > 0.01
                            enabled: off === 0
                            Behavior on x { NumberAnimation { duration: Theme.ms(560); easing.type: Easing.OutExpo } }
                            Behavior on scale { NumberAnimation { duration: Theme.ms(560); easing.type: Easing.OutExpo } }
                            Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Easing.OutCubic } }
                            // (scrolls when a page is taller than the card: on a short screen the bar
                            // styles were cut off under the preview)
                            Flickable {
                                id: pageFlick
                                anchors.fill: parent
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                contentWidth: width
                                contentHeight: Math.max(height, pageLoader.item ? pageLoader.item.implicitHeight : 0)
                                interactive: contentHeight > height + 1
                                SmoothWheel {}
                                Loader {
                                    id: pageLoader
                                    width: pageFlick.width
                                    height: pageFlick.contentHeight
                                    active: Math.abs(pg.off) <= 1
                                    sourceComponent: [hello, look, bar, dock, getAround, done][pg.index]
                                }
                            }
                        }
                    }
                }

                // ── the way through: skip · the steps · back / next ──
                Item {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 28
                    height: 48
                    Button {
                        visible: wel.step < wel.steps.length - 1
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        opacity: Math.min(1, wel.navIn(0)); transform: Translate { y: 26 * (1 - wel.navIn(0)) }
                        text: "Skip"
                        onClicked: wel.finish()
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: Math.min(1, wel.navIn(1)); transform: Translate { y: 26 * (1 - wel.navIn(1)) }
                        Repeater {
                            model: wel.steps.length
                            Rectangle {
                                required property int index
                                width: index === wel.step ? 28 : 9; height: 9; radius: Theme.chamfer ? 0 : 4.5
                                color: index <= wel.step ? Theme.accent : Qt.alpha(Theme.text, 0.2)
                                Behavior on width { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: wel.step = parent.index }
                            }
                        }
                    }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        opacity: Math.min(1, wel.navIn(2)); transform: Translate { y: 26 * (1 - wel.navIn(2)) }
                        Button { visible: wel.step > 0 && wel.step < wel.steps.length - 1; text: "Back"; icon: "arrow_back"; onClicked: wel.go(-1) }
                        Button {
                            visible: wel.step < wel.steps.length - 1
                            text: wel.step === 0 ? "Let's go" : "Next"; icon: "arrow_forward"; primary: true
                            onClicked: wel.go(1)
                        }
                    }
                }
            }
        }
    }

    // ── the intro's light: over everything, only while it plays ──
    Item {
        id: fx
        anchors.fill: parent
        visible: wel.intro && wel.shown
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // the slab rising (0.3-1.2 s), popping at the hit, then floating up to its place
        readonly property real rise: wel.outCubic(wel.seg(300, 1200))
        readonly property real pop: Math.sin(Math.PI * wel.seg(wel.hit - 150, wel.hit + 450))
        readonly property real travel: wel.outCubic(wel.seg(1650, 2350))
        readonly property bool after: wel.clock >= wel.hit

        // the slab: cut off at the line of light while it rises, then free
        Item {
            x: fx.cx - 60
            y: fx.cy - 84 - 40 + (wel.markY - fx.cy) * fx.travel
            width: 120; height: 168 + 40
            clip: !fx.after
            visible: wel.clock < 2350
            Item {
                id: riser
                x: 18; y: 40 + 168 * (1 - fx.rise)
                width: 84; height: 168
                scale: 1 + 0.03 * fx.pop
                Glow { anchors.fill: parent; r: Theme.square ? 0 : 18; blurPx: 30 + 14 * fx.pop; tint: Qt.alpha(Theme.accent, 0.5 + 0.2 * fx.pop) }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.square ? 0 : 18
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.25) }
                        GradientStop { position: 1; color: Theme.m("primary_container", Theme.accentContainer) }
                    }
                }
                // a sheen on it while it rises
                Rectangle { anchors.fill: parent; radius: Theme.square ? 0 : 18; color: "white"; opacity: 0.25 * fx.rise * (1 - wel.seg(wel.hit, 1900)) }
            }
        }
    }

    Item {
        id: keys
        focus: wel.shown
        // any key skips the intro (and only that)
        Keys.onPressed: event => { if (wel.intro) { wel.skipIntro(); event.accepted = true; } }
        Keys.onEscapePressed: wel.finish()
        Keys.onRightPressed: wel.go(1)
        Keys.onLeftPressed: wel.go(-1)
        Keys.onReturnPressed: wel.step === wel.steps.length - 1 ? wel.finish() : wel.go(1)
        Keys.onEnterPressed: wel.step === wel.steps.length - 1 ? wel.finish() : wel.go(1)
    }

    // a step's title and line under it
    component Head: Column {
        property string title
        property string line
        width: parent ? parent.width : 400
        spacing: 6
        Text { text: parent.title; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 32; font.weight: Font.Black }
        Text { width: parent.width; text: parent.line; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 15; wrapMode: Text.Wrap }
    }

    // ── 1: hello ──
    Component {
        id: hello
        Item {
            // the mark: a tall slab, glowing, floating gently (the intro's slab lands here)
            Item {
                id: mark
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                width: 120; height: 190
                visible: wel.clock >= 2350
                property real bob: 0
                SequentialAnimation on bob {
                    running: !wel.intro && wel.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: 0; duration: 2600; easing.type: Easing.InOutSine }
                }
                // its shadow on the ground
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 182; width: 96 - 16 * mark.bob; height: 10; radius: Theme.chamfer ? 0 : 5; color: "black"; opacity: 0.25 - 0.08 * mark.bob }
                Item {
                    id: slab
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -10 * mark.bob
                    width: 84; height: 168
                    // (a glow drawn by a shader round it: the old blurred-layer glow left a dark
                    // box round the slab)
                    Glow { anchors.fill: parent; r: Theme.square ? 0 : 18; blurPx: 34; tint: Qt.alpha(Theme.accent, 0.45 + 0.25 * mark.bob) }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.square ? 0 : 18
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.25) }
                            GradientStop { position: 1; color: Theme.m("primary_container", Theme.accentContainer) }
                        }
                        // a sheen running down it
                        Rectangle {
                            width: parent.width; height: 34
                            y: (parent.height + 40) * mark.bob - 40
                            opacity: 0.18
                            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.5; color: "white" } GradientStop { position: 1; color: "transparent" } }
                        }
                    }
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: mark.bottom; anchors.topMargin: 34
                width: parent.width
                spacing: 10
                // the title, letter by letter: each rises in after the one before, and a shine
                // runs across them now and then
                Row {
                    id: title
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property string s: "Welcome to Monolith" + (wel.who ? ", " + wel.who : "")
                    Repeater {
                        model: title.s.length
                        Text {
                            required property int index
                            readonly property real p: wel.outCubic(wel.seg(2050 + index * 32, 2550 + index * 32))
                            readonly property real g: Math.max(0, 1 - Math.abs(index - wel.shineAt * (title.s.length + 8) + 4) / 3.5)
                            text: title.s.charAt(index)
                            opacity: p
                            transform: Translate { y: 28 * (1 - wel.outBack(p)) }
                            color: Qt.tint(Theme.text, Qt.alpha(wel.glint, 0.9 * g))
                            font.family: Theme.fontFamily; font.pixelSize: 40; font.weight: Font.Black
                        }
                    }
                }
                Text {
                    id: sub
                    readonly property real p: wel.outCubic(wel.seg(2650, 3200))
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 620)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    opacity: p
                    transform: Translate { y: 16 * (1 - sub.p) }
                    text: "Your desktop, in one piece. A minute to make it yours: a look, a bar, a dock, and the few keys worth knowing. You can change all of it later in Settings."
                    Balance {}   // balanced lines (ui/Balance)
                    color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 16
                }
            }
        }
    }

    // ── 2: your look ──
    Component {
        id: look
        ColumnLayout {
            spacing: 14
            Head { Layout.fillWidth: true; title: "Your look"; line: "Pick a style: it changes everything at once, right behind this card. The colours come from your wallpaper." }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Segmented {
                    Layout.preferredWidth: 220; Layout.preferredHeight: 40
                    opts: [["dark", "Dark"], ["light", "Light"]]
                    value: Theme.modeName
                    onPicked: v => Store.set("theme.mode", v)
                }
                Item { Layout.fillWidth: true }
                Button { text: "Choose a wallpaper"; icon: "wallpaper"; onClicked: HubState.showWall(wel.modelData.name) }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: styleFlow.implicitHeight
                clip: true
                SmoothWheel {}
                Flow {
                    id: styleFlow
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: Look.styles
                        Pressable {
                            required property var modelData
                            readonly property bool on: Look.styleId === modelData.id
                            width: (styleFlow.width - 3 * 8) / 4; height: 72
                            color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.container)
                            border.width: on ? 2 : 0; border.color: Theme.accent
                            onClicked: { Look.followStyle(modelData.id); Store.set("theme.style", modelData.id); }
                            Column {
                                x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28
                                spacing: 3
                                Text { text: parent.parent.modelData.name; color: parent.parent.on ? Theme.onAccentContainer : Theme.text; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold }
                                Text { width: parent.width; text: parent.parent.modelData.desc || ""; elide: Text.ElideRight; color: parent.parent.on ? Theme.onAccentContainer : Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
                            }
                            Icon { visible: parent.on; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; name: "check_circle"; filled: true; size: 18; color: Theme.accent }
                        }
                    }
                }
            }
        }
    }

    // ── 3: your bar ──
    Component {
        id: bar
        ColumnLayout {
            spacing: 14
            Head { id: barHead; Layout.fillWidth: true; title: "Your bar"; line: "Five ways to wear it. This is your real bar, as it looks now:" }
            // (the monitor gets the room that's left, so the styles below always fit: at its full
            // 250 px they were cut off under it)
            BarPreview {
                id: barPv
                Layout.fillWidth: true
                monitorH: Math.max(80, Math.min(250, pages.height - barHead.implicitHeight - barStyles.implicitHeight - barPv.chromeH - 2 * 14 - 4))
            }
            BarStyles { id: barStyles; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
        }
    }

    // ── 4: the dock ──
    Component {
        id: dock
        ColumnLayout {
            spacing: 14
            Head { Layout.fillWidth: true; title: "The dock"; line: "Your apps along the bottom. Hold an app (or the dock) for a moment to rearrange it, add or remove apps." }
            RowLayout {
                spacing: 10
                Toggle { checked: Store.get("dock.enabled", true) !== false; onToggled: on => Store.set("dock.enabled", on) }
                Label { text: "Use the dock"; strong: true }
            }
            Label { text: "When it shows"; muted: true; font.pixelSize: Theme.sizeSmall }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10; rowSpacing: 10
                opacity: Store.get("dock.enabled", true) !== false ? 1 : 0.4
                Repeater {
                    model: [["dodge", "Dodge windows", "Up, and steps aside when a window is under it", "swap_vert"],
                            ["always", "Always", "Always there", "dock_to_bottom"],
                            ["empty", "On empty workspaces", "When there's nothing open", "crop_square"],
                            ["edge", "Only at the edge", "Touch the bottom of the screen", "south"]]
                    Pressable {
                        required property var modelData
                        readonly property bool on: Store.get("dock.show", "empty") === modelData[0]
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.container)
                        border.width: on ? 2 : 0; border.color: Theme.accent
                        onClicked: Store.set("dock.show", modelData[0])
                        Row {
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Bubble { size: 42; icon: parent.parent.modelData[3]; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: parent.parent.parent.modelData[1]; color: parent.parent.parent.on ? Theme.onAccentContainer : Theme.text; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold }
                                Text { text: parent.parent.parent.modelData[2]; color: parent.parent.parent.on ? Theme.onAccentContainer : Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── 5: getting around ──
    Component {
        id: getAround
        ColumnLayout {
            spacing: 14
            Head { Layout.fillWidth: true; title: "Getting around"; line: "The keys worth knowing (yours, from " + (Niri.hyprland ? "Hyprland" : "niri") + "'s config), and a few things to try." }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10; rowSpacing: 8
                Repeater {
                    model: wel.shortcuts
                    SmoothRect {
                        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: Theme.corner(50, 6)
                        color: Theme.container
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Icon { name: parent.parent.modelData[0]; size: 20; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: parent.parent.parent.modelData[1]; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold }
                                Text { text: parent.parent.parent.modelData[3]; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
                            }
                        }
                        // the keys, as keycaps
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Repeater {
                                model: parent.parent.modelData[4].split(" + ")
                                Rectangle {
                                    required property string modelData
                                    height: 26; width: Math.max(26, kt.implicitWidth + 14); radius: Theme.square ? 0 : 7
                                    color: Theme.control
                                    border.width: 1; border.color: Qt.alpha(Theme.text, 0.15)
                                    SmoothRect { smoothing: 0; anchors.bottom: parent.bottom; width: parent.width; height: 3; radius: parent.radius; color: Qt.alpha("black", 0.25) }
                                    Text { id: kt; anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: parent.modelData; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
                                }
                            }
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [["right_click", "Right-click the desktop: wallpaper, widgets, theme"], ["dashboard_customize", "Widgets: right-click → Edit widgets"],
                            ["touch_app", "Hold a dock app to edit the dock"], ["view_carousel", "Every bar module opens its menu"]]
                    SmoothRect {
                        smoothing: 0
                        required property var modelData
                        height: 34; width: tr.implicitWidth + 24; radius: 17
                        color: Qt.alpha(Theme.accent, 0.12)
                        Row { id: tr; anchors.centerIn: parent; spacing: 8
                            Icon { name: parent.parent.modelData[0]; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: parent.parent.modelData[1]; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ── 6: all set ──
    Component {
        id: done
        Item {
            id: fin
            // the moment this page is reached: the check spins in fast, then zooms in and back out
            // (its sound, sounds/welcome/done.wav, rises with the spin and rings at the zoom)
            readonly property bool here: wel.step === wel.steps.length - 1
            property real c: 1
            NumberAnimation on c { id: burst; running: false; from: 0; to: 1; duration: 1300 }
            onHereChanged: if (here && Theme.animOn) burst.restart()
            Component.onCompleted: if (here && Theme.animOn) burst.restart()
            function sg(a, b) { return Math.max(0, Math.min(1, (c - a) / (b - a))); }
            function inOutCubic(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 18
                SmoothRect {
                    smoothing: 0
                    id: check
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96; height: 96; radius: 48
                    color: Theme.accent
                    // in (0-0.26 s), then a quick zoom in (0.78-0.94 s) and out (0.94-1.24 s)
                    scale: 0.6 + 0.4 * wel.outCubic(fin.sg(0, 0.2))
                        + 0.28 * wel.outCubic(fin.sg(0.6, 0.72)) - 0.28 * fin.inOutCubic(fin.sg(0.72, 0.95))
                    Glow { anchors.fill: parent; z: -1; r: 48; blurPx: 40 + 30 * (wel.outCubic(fin.sg(0.6, 0.72)) - fin.inOutCubic(fin.sg(0.72, 0.95))); tint: Qt.alpha(Theme.accent, 0.6) }
                    Icon {
                        anchors.centerIn: parent; name: "check"; size: 54; color: Theme.onAccent
                        // three fast turns, slowing to a stop
                        rotation: -1080 * (1 - wel.outCubic(fin.sg(0, 0.6)))
                        scale: 0.4 + 0.6 * wel.outCubic(fin.sg(0, 0.3))
                    }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all set"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 38; font.weight: Font.Black }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 560); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    text: "Enjoy Monolith. Settings has everything else: themes, fonts, widgets, the lock screen, displays, keyboard and more. This tour is in Settings → General → Updates & about whenever you want it again."
                    Balance {}   // balanced lines (ui/Balance)
                    color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 15
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Button { text: "Open Settings"; icon: "settings"; onClicked: { wel.finish(); HubState.openSettings("", wel.modelData.name); } }
                    Button { text: "Start using Monolith"; icon: "rocket_launch"; primary: true; onClicked: wel.finish() }
                }
            }
        }
    }
}
