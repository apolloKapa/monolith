pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"

Item {
    id: root

    property string fontFamily: "Google Sans Flex"
    property int _borderRadius: 10
    readonly property int borderRadius: square ? 0 : Math.round(_borderRadius * radiusScale)
    property int clampedBorderRadius: {
        const r = borderRadius;
        return Math.floor(
            r <= 24
                ? r
                : 24 + Math.pow(r - 24, 0.55)
        );
    }

    property real elementOpacity: 1.0
    // the Settings app draws glass too (on niri, where it can find its own position)
    property bool standaloneGlass: false
    property bool blurBackground: false
    property string blurStyle: "material"
    readonly property real liquidGlassOpacity: 0.1
    readonly property bool minimalist: blurStyle === "minimalist"

    // Styles (Settings -> Theme -> Style). Blur and Liquid glass are see-through; every other
    // style is a whole look: opaque surfaces, its own corners/outlines, and a palette + font
    // that load when it's picked (both can be changed afterwards). Components ask for tokens
    // (square, rad(), outlined, outline*, hardShadow) instead of checking a style by name.
    readonly property var styles: ({
        "material":   { "name": "Material", "opaque": true, "radiusScale": 1.8, "font": "Google Sans Flex", "matugen": true, "pill": true,
                        "desc": "Soft, round, your wallpaper's colours" },
        "blur":       { "name": "Blur",         "opaque": false },
        "liquid":     { "name": "Liquid glass", "opaque": false },
        "minimalist": { "name": "Minimalist", "opaque": true, "square": true, "outline": [2, 1], "font": "JetBrains Mono",
                        "desc": "Flat, square, grey outlines" },
        "terminal":   { "name": "Terminal", "opaque": true, "square": true, "outline": [1, 1], "outlineRole": "accent", "font": "JetBrains Mono",
                        "desc": "Phosphor on black, thin accent frames",
                        "colors": { "base": "#0b0d0b", "mantle": "#070907", "crust": "#000000", "surface0": "#141914", "surface1": "#1c241c", "surface2": "#2a362a",
                                    "overlay0": "#3d4d3d", "overlay1": "#557055", "overlay2": "#6f906f", "text": "#c9f5c4", "subtext0": "#86b383", "subtext1": "#a6d4a2",
                                    "blue": "#7cf29a", "sapphire": "#7cf29a", "teal": "#7cf2d6", "mauve": "#7cf29a", "pink": "#f2c97c", "green": "#7cf29a",
                                    "yellow": "#f2e27c", "peach": "#f2b27c", "red": "#f27c7c", "maroon": "#d46a6a" } },
        "brutal":     { "name": "Brutal", "opaque": true, "square": false, "radiusScale": 0.5, "outline": [3, 2], "outlineRole": "ink", "hardShadow": 5, "font": "Space Grotesk",
                        "desc": "Cream, thick ink lines, hard shadows",
                        "colors": { "base": "#fff4dc", "mantle": "#f7e9c6", "crust": "#141414", "surface0": "#ffe08a", "surface1": "#ffd25c", "surface2": "#141414",
                                    "overlay0": "#5a5246", "overlay1": "#3d372e", "overlay2": "#2a261f", "text": "#141414", "subtext0": "#3d372e", "subtext1": "#2a261f",
                                    "blue": "#3a7bff", "sapphire": "#3a7bff", "teal": "#1fb8a6", "mauve": "#ff5c3a", "pink": "#ff7eb6", "green": "#2bb24c",
                                    "yellow": "#ffd23f", "peach": "#ff8a3a", "red": "#e5262b", "maroon": "#b3191e" } },
        "luxe":       { "name": "Luxe", "opaque": true, "radiusScale": 0.6, "outline": [1, 1], "outlineRole": "accentSoft", "font": "SF Pro Display",
                        "desc": "Black chassis, ivory ink, gold detail",
                        "colors": { "base": "#0e0d0c", "mantle": "#090807", "crust": "#050404", "surface0": "#191715", "surface1": "#24211d", "surface2": "#3a342c",
                                    "overlay0": "#5b5246", "overlay1": "#7a6f60", "overlay2": "#9b8e7c", "text": "#efe6d4", "subtext0": "#b3a892", "subtext1": "#d0c5ae",
                                    "blue": "#c9a96e", "sapphire": "#c9a96e", "teal": "#a8b89a", "mauve": "#c9a96e", "pink": "#c98a7a", "green": "#a8b89a",
                                    "yellow": "#d9c08a", "peach": "#d4a373", "red": "#8e2f2a", "maroon": "#6e2420" } },
        "poster":     { "name": "Poster", "opaque": true, "square": true, "outline": [3, 2], "outlineRole": "text", "font": "SF Pro Display",
                        "desc": "Carbon plates, signal yellow, bold frames",
                        "colors": { "base": "#111111", "mantle": "#0a0a0a", "crust": "#000000", "surface0": "#1d1d1d", "surface1": "#2a2a2a", "surface2": "#3b3b3b",
                                    "overlay0": "#5c5c5c", "overlay1": "#7a7a7a", "overlay2": "#9a9a9a", "text": "#f5f5f0", "subtext0": "#b0b0a8", "subtext1": "#d6d6ce",
                                    "blue": "#ffd400", "sapphire": "#ffd400", "teal": "#00e0c6", "mauve": "#ffd400", "pink": "#ff4f8b", "green": "#3ddc84",
                                    "yellow": "#ffd400", "peach": "#ff8a00", "red": "#ff3b30", "maroon": "#c42b22" } },
        "bubbly":     { "name": "Bubbly", "opaque": false, "radiusScale": 2.2,
                        "desc": "Extra round, keeps your colours" },
        "paper":      { "name": "Paper", "opaque": true, "radiusScale": 0.35, "outline": [1, 1], "outlineRole": "rule", "font": "Lora",
                        "desc": "Ink on paper, serif type, fine rules",
                        "colors": { "base": "#f5f2eb", "mantle": "#ece7dc", "crust": "#f9f7f2", "surface0": "#e8e2d4", "surface1": "#ddd5c4", "surface2": "#c9bfab",
                                    "overlay0": "#a39a88", "overlay1": "#857c6b", "overlay2": "#6b6355", "text": "#242321", "subtext0": "#5e584e", "subtext1": "#45403a",
                                    "blue": "#2f5d8a", "sapphire": "#2f5d8a", "teal": "#3d7a6e", "mauve": "#8a3b2e", "pink": "#a85a6e", "green": "#4a7a3d",
                                    "yellow": "#b08a2e", "peach": "#b8662e", "red": "#a8322e", "maroon": "#7a2420" } },
        "arcade":     { "name": "Arcade", "opaque": true, "square": true, "outline": [2, 1], "outlineRole": "accent", "hardShadow": 4, "font": "Bitcount Prop Single",
                        "desc": "Pixel type, neon on night blue, glowing drop shadows",
                        "colors": { "base": "#110f2b", "mantle": "#0b0a20", "crust": "#060514", "surface0": "#1c1a42", "surface1": "#29265a", "surface2": "#3a3678",
                                    "overlay0": "#55509a", "overlay1": "#726db5", "overlay2": "#938fcf", "text": "#f4f1ff", "subtext0": "#b3aee0", "subtext1": "#d3cff2",
                                    "blue": "#3ad8ff", "sapphire": "#3ad8ff", "teal": "#3dffd0", "mauve": "#ff3df2", "pink": "#ff6ec7", "green": "#5cff8a",
                                    "yellow": "#ffe14d", "peach": "#ff9e3d", "red": "#ff4d6d", "maroon": "#d63a57" } }
    })
    readonly property var styleOrder: ["material", "blur", "liquid", "minimalist", "terminal", "brutal", "luxe", "poster", "bubbly", "paper", "arcade"]
    readonly property var style: styles[blurStyle] || styles["material"]
    // Material: Google-style tonal surfaces, pill controls and filled containers instead of outlines
    readonly property bool material: blurStyle === "material"
    // controls are full pills (buttons, chips, segmented switches) unless the style is square
    readonly property bool pill: style.pill === true
    // type weights: Material sets lighter type than the shell's heavy defaults
    readonly property int weightBlack: material ? Font.DemiBold : Font.Black
    readonly property int weightBold: material ? Font.Medium : Font.Bold
    readonly property bool opaqueStyle: style.opaque === true
    readonly property bool square: style.square === true
    readonly property real radiusScale: style.radiusScale !== undefined ? style.radiusScale : 1.0
    // a corner radius in this style: rad(r) for any rounded thing (0 when square)
    function rad(r) { return square ? 0 : r * radiusScale; }
    readonly property bool outlined: style.outline !== undefined
    readonly property int outlineOuter: outlined ? style.outline[0] : 0
    readonly property int outlineInner: outlined ? style.outline[1] : 0
    readonly property color outlineColor: {
        switch (style.outlineRole) {
            case "accent": return Qt.alpha(mauve, 0.55);
            case "accentSoft": return Qt.alpha(mauve, 0.35);
            case "ink": return crust;
            case "text": return text;
            case "rule": return surface2;
            default: return surface2;
        }
    }
    readonly property int hardShadow: style.hardShadow !== undefined ? style.hardShadow : 0

    // Animations (Settings -> Theme -> Animations). Every animation duration in the shell is
    // multiplied by animScale: 0 = off (instant), <1 faster, >1 slower. Looping/ambient
    // animations (spinners, waves) keep their own speed.
    property bool animationsEnabled: true
    property real animationSpeed: 1.0
    readonly property real animScale: (animationsEnabled && !gameModeActive) ? 1.0 / Math.max(0.25, animationSpeed) : 0

    // GameMode (Theme -> Animations): while a fullscreen window has focus (games, videos),
    // animations, blur and liquid glass are off so the shell costs the GPU nothing.
    property bool gameModeEnabled: true

    // Monolith's surface effects (Theme -> Effects), all on by default; GameMode turns them off.
    //   grain:  faint film grain on panels      edge:   a light along each panel's top
    //   unfold: panels open by unfolding from a line
    property var effects: ({})
    // Material keeps its surfaces clean: grain and edge light are opt-in there
    readonly property bool fxGrain: (material ? effects.grain === true : effects.grain !== false) && !gameModeActive
    readonly property bool fxEdge: (material ? effects.edge === true : effects.edge !== false) && !gameModeActive
    // corner marks inside panel corners: "off" (default), "square" brackets or "round" arcs
    readonly property string fxMarks: gameModeActive ? "off" : ((effects.marks === "square" || effects.marks === "round") ? effects.marks : "off")
    readonly property bool fxUnfold: effects.unfold !== false
    // activeToplevel is undefined (not null) with nothing focused: comparing with null let the
    // binding throw, and a failed binding keeps its old value, so GameMode could stay on (no
    // glass anywhere in the shell) long after the fullscreen game was gone
    readonly property bool gameModeActive: gameModeEnabled && !!ToplevelManager.activeToplevel
        && ToplevelManager.activeToplevel.fullscreen === true
    readonly property bool glassActive: blurBackground && !opaqueStyle && elementOpacity < 0.999 && !gameModeActive
    readonly property bool liquidGlass: blurBackground && blurStyle === "liquid" && !gameModeActive
    // a see-through look is on (Blur or Liquid glass): the Frame bar style turns to glass too
    readonly property bool seeThrough: glassActive || liquidGlass
    // the Frame's colour: solid, or the panels' see-through tint
    readonly property color frameColor: seeThrough ? Qt.alpha(base, Math.max(0.35, elementOpacity)) : base

    // Minimalist: flat, opaque, square, outlined. Outer surfaces get the thick line, nested ones the thin one.
    readonly property int minimalistOuterBorder: outlineOuter
    readonly property int minimalistInnerBorder: outlineInner
    readonly property color minimalistBorderColor: outlineColor
    readonly property string minimalistFont: "JetBrains Mono"
    readonly property var minimalistColors: ({
        "base": "#1a1a1a", "mantle": "#111111", "crust": "#000000",
        "surface0": "#2a2a2a", "surface1": "#333333", "surface2": "#555555",
        "overlay0": "#6a6a6a", "overlay1": "#858585", "overlay2": "#a0a0a0",
        "text": "#ffffff", "subtext0": "#a0a0a0", "subtext1": "#c8c8c8",
        "blue": "#ffffff", "sapphire": "#ffffff", "teal": "#ffffff", "mauve": "#ffffff",
        "pink": "#ffffff", "green": "#ffffff", "yellow": "#e0e0e0", "peach": "#e0e0e0",
        "red": "#9b0000", "maroon": "#9b0000"
    })

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color _text: "#cdd6f4"
    property color _subtext0: "#a6adc8"
    property color _subtext1: "#bac2de"
    readonly property color text: liquidGlass ? "#ffffff" : _text
    readonly property color subtext0: liquidGlass ? "#ffffff" : _subtext0
    readonly property color subtext1: liquidGlass ? "#ffffff" : _subtext1
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    readonly property color primary: blue
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    // Material 3 roles. With wallpaper colours (Matugen) the palette slots already hold them
    // (see the matugen template: sapphire = primary container, yellow = secondary container);
    // with a fixed palette they're mixed from it.
    property bool matugenPalette: true
    function _lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    readonly property bool darkMode: _lum(base) < 0.5
    readonly property color surfaceContainerLow: mantle
    readonly property color surfaceContainer: surface0
    readonly property color surfaceContainerHigh: surface1
    readonly property color surfaceContainerHighest: surface2
    readonly property color onPrimary: _lum(mauve) > 0.5 ? Qt.darker(mauve, 3.2) : "#ffffff"
    readonly property color primaryContainer: matugenPalette ? sapphire : Qt.tint(surface0, Qt.alpha(mauve, 0.32))
    readonly property color onPrimaryContainer: darkMode ? Qt.tint(text, Qt.alpha(mauve, 0.35)) : Qt.darker(mauve, 2.4)
    readonly property color secondaryContainer: matugenPalette ? yellow : Qt.tint(surface1, Qt.alpha(mauve, 0.16))
    readonly property color onSecondaryContainer: darkMode ? Qt.tint(text, Qt.alpha(green, 0.25)) : Qt.darker(mauve, 2.6)
    readonly property color outlineVariant: surface2

    property string configPath: Quickshell.env("QS_COLORS_JSON") ?? "~/.local/state/monolith/qs_colors.json"
    property string matugenConfigPath: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") ?? "") + "/.local/state/monolith")) + "/qs_matugen_colors.json"

    property bool _readInProgress: false
    property var matugenColors: null
    property var _colorQueue: []
    property int colorsPerFrame: 3

    property var availableFontPaths: ({})
    property var bundledNames: []
    property string activeFontPath: ""

    FontLoader {
        id: iconFontLoader
        source: (typeof Caching !== "undefined" && Caching.monolithDir && Caching.monolithDir !== "")
            ? ("file://" + Caching.monolithDir + "/assets/fonts/SymbolsNerdFontMono-Regular.ttf")
            : ""
    }

    readonly property string iconFont: (iconFontLoader.status === FontLoader.Ready && iconFontLoader.name !== "")
        ? iconFontLoader.name
        : (root.fontFamily !== "" ? root.fontFamily : "sans-serif")
    readonly property bool iconFontReady: iconFontLoader.status === FontLoader.Ready

    onFontFamilyChanged: {
        root.updateActiveFontLoader();
    }

    function isMatugenTheme() {
        if (typeof Matugen !== "undefined" && typeof Matugen.isMatugenTheme === "function") {
            return Matugen.isMatugenTheme();
        }
        let themeConfig = Config.getSetting("theme", { "matugen": true, "activePreset": "Matugen" });
        if (themeConfig.matugen !== undefined) {
            return themeConfig.matugen === true;
        }
        return themeConfig.theme === "matugen"
            || themeConfig.name === "matugen"
            || themeConfig.currentTheme === "matugen"
            || themeConfig.current === "matugen"
            || themeConfig.activePreset === "Matugen"
            || themeConfig.activePreset === undefined;
    }

    function updateActiveFontLoader() {
        if (!root.fontFamily || root.fontFamily === "") return;
        let key = root.fontFamily.toLowerCase();
        let path = root.availableFontPaths ? root.availableFontPaths[key] : "";

        if (path && root.activeFontPath !== path) {
            root.activeFontPath = path;
        }
    }

    FontLoader {
        id: staticFontLoader
        source: (root.activeFontPath && root.activeFontPath !== "") ? ("file://" + root.activeFontPath) : ""
        onStatusChanged: {
            if (status === FontLoader.Ready) {
                let cur = root.fontFamily;
                root.fontFamily = "";
                root.fontFamily = cur;
            }
        }
    }

    Process {
        id: fontFetcher
        property bool forceRescan: false

        command: {
            let sys = Caching.monolithDir ? (Caching.monolithDir + "/assets/fonts") : "";
            let usr = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/monolith/fonts");
            let cacheFile = Caching.stateDir ? (Caching.stateDir + "/fonts_cache.txt") : (Caching.home + "/.local/state/monolith/fonts_cache.txt");
            let force = forceRescan ? "true" : "false";

            let cmd = "CACHE=\"" + cacheFile + "\"; ";
            cmd += "if [ \"" + force + "\" = \"true\" ] || [ ! -f \"$CACHE\" ]; then ";
            cmd += "mkdir -p \"$(dirname \"$CACHE\")\"; ";
            cmd += "find ";
            if (sys !== "") cmd += "\"" + sys + "\" ";
            cmd += "\"" + usr + "\" -type f \\( -iname \"*.ttf\" -o -iname \"*.otf\" -o -iname \"*.ttc\" \\) -print0 2>/dev/null | sort -z | ";
            cmd += "xargs -0 -r fc-scan -f '%{family[0]}\\t%{style[0]}\\t%{file}\\n' 2>/dev/null | ";
            cmd += "awk -F'\\t' '{ fam=$1; stl=$2; f=$3; if (fam==\"\") { n=split(f,a,\"/\"); fam=a[n]; sub(/\\.[^.]*$/,\"\",fam) } if (stl!=\"\" && stl!=\"Regular\") print fam \" \" stl \"|\" f; else print fam \"|\" f }' ";
            cmd += "> \"$CACHE.tmp\" || true; mv \"$CACHE.tmp\" \"$CACHE\"; ";
            cmd += "fi; ";
            cmd += "cat \"$CACHE\" || true";

            return ["bash", "-c", cmd];
        }
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                fontFetcher.forceRescan = false;

                let lines = this.text.trim().split('\n');
                let newPaths = {};
                let names = [];
                let seen = new Set();

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line === "") continue;

                    let idx = line.indexOf('|');
                    if (idx !== -1) {
                        let fName = line.substring(0, idx).trim();
                        if (fName.toLowerCase().indexOf("symbols nerd font") !== -1) continue;

                        let fPath = line.substring(idx + 1).trim();
                        let key = fName.toLowerCase();

                        newPaths[key] = fPath;

                        if (!seen.has(key)) {
                            seen.add(key);
                            names.push(fName);
                        }
                    }
                }

                root.availableFontPaths = newPaths;
                root.bundledNames = names;
                root.updateActiveFontLoader();
                if (staticFontLoader.status === FontLoader.Ready) {
                    let cur = root.fontFamily;
                    root.fontFamily = "";
                    root.fontFamily = cur;
                }
            }
        }
    }

    function scanFonts() {
        fontFetcher.running = false;
        fontFetcher.forceRescan = true;
        fontFetcher.running = true;
    }

    function reloadColors() {
        if (root._readInProgress) return;
        root._readInProgress = true;
        root.updateColors();
    }

    IpcHandler {
        target: "theme"

        function reloadColors() {
            root.reloadColors();
        }

        // for scripts and debugging: the current style and whether GameMode is holding effects off
        function state(): string {
            return JSON.stringify({ "style": root.blurStyle, "gameMode": root.gameModeActive, "animScale": root.animScale, "glass": root.glassActive || root.liquidGlass });
        }
    }

    IpcHandler {
        target: "fonts"
        function rescan() {
            root.scanFonts();
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.updateColors();
        }
        function onRawSettingsChanged() {
            root.syncElementOpacity();
        }
    }

    Connections {
        target: typeof Matugen !== "undefined" ? Matugen : null
        function onGenerationFinished(success) {
            root._readInProgress = false;
            if (success) {
                themeWatcher.reload();
                matugenColorsWatcher.reload();
            }
        }
    }

    function applyMatugenColors(): bool {
        if (root.matugenColors) {
            root.applyColorObject(root.matugenColors);
            return true;
        }
        return false;
    }

    function faded(c) {
        return Qt.alpha(c, root.elementOpacity);
    }

    function syncElementOpacity() {
        const themeConfig = Config.getSetting("theme", {});
        const pct = themeConfig.elementOpacity !== undefined ? Number(themeConfig.elementOpacity) : 100;
        // the Settings app (standalone) is a normal window; on niri it knows where it is on screen
        // (NiriState), so it draws the same glass as the panels
        root.standaloneGlass = Caching.isStandalone && NiriState.isNiri;
        root.blurBackground = (!Caching.isStandalone || root.standaloneGlass) && (themeConfig.blurBackground !== undefined ? Boolean(themeConfig.blurBackground) : false);
        root.blurStyle = root.styles[themeConfig.blurStyle] ? themeConfig.blurStyle : "material";
        const anim = themeConfig.animations || {};
        root.animationsEnabled = anim.enabled !== false;
        root.gameModeEnabled = themeConfig.gameMode !== false;
        root.effects = themeConfig.effects || {};
        const speed = Number(anim.speed);
        root.animationSpeed = isNaN(speed) ? 1.0 : Math.max(0.25, Math.min(3.0, speed));
        root.elementOpacity = (root.opaqueStyle || (Caching.isStandalone && !root.standaloneGlass)) ? 1.0 : root.liquidGlass ? root.liquidGlassOpacity : (isNaN(pct) ? 1.0 : Math.max(0, Math.min(1.0, pct / 100.0)));
    }

    function updateColors() {
        let themeConfig = Config.getSetting("theme", {});

        if (themeConfig.fontFamily !== undefined) {
            root.fontFamily = themeConfig.fontFamily;
        }
        if (themeConfig.borderRadius !== undefined) {
            root._borderRadius = themeConfig.borderRadius;
        }
        root.syncElementOpacity();

        let customColors = themeConfig.colors || themeConfig.palette || (themeConfig.base !== undefined ? themeConfig : null);

        root.matugenPalette = root.isMatugenTheme();
        if (root.matugenPalette) {
            root.applyMatugenColors();
            let wp = themeConfig.wallpaper || Config.getSetting("wallpaper", "");
            if (!Caching.isStandalone && typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                Matugen.generate(wp, themeConfig.mode, themeConfig.schemeType);
            }
            root._readInProgress = false;
        } else {
            root._readInProgress = false;
            if (customColors) {
                root.applyColorObject(customColors);
                if (!Caching.isStandalone && typeof Matugen !== "undefined" && typeof Matugen.generateFromStatic === "function") {
                    Matugen.generateFromStatic(customColors, themeConfig.mode);
                }
            } else {
                themeWatcher.reload();
            }
        }
    }

    function applyColorObject(c) {
        if (!c) return;

        let resolveHex = function(val) {
            if (!val) return "";
            if (typeof val === "string") return val;
            if (typeof val === "object") {
                if (val.hex) return val.hex;
                if (val.color) return val.color;
                if (val.default && val.default.hex) return val.default.hex;
            }
            return val.toString();
        };

        let names = ["base", "mantle", "crust", "surface0", "surface1", "surface2",
                     "overlay0", "overlay1", "overlay2", "text", "subtext0", "subtext1",
                     "blue", "sapphire", "peach", "green", "red", "mauve", "pink",
                     "yellow", "maroon", "teal"];

        let queue = [];
        for (let i = 0; i < names.length; i++) {
            let hexColor = resolveHex(c[names[i]]);
            if (!hexColor) continue;
            let nextColor = Qt.color(hexColor);
            let slot = (names[i] === "text" || names[i] === "subtext0" || names[i] === "subtext1") ? "_" + names[i] : names[i];
            if (root[slot].toString() !== nextColor.toString()) {
                queue.push({ name: slot, value: nextColor });
            }
        }

        root._colorQueue = queue;
        if (queue.length > 0) {
            root._flushColorQueue();
            if (root._colorQueue.length > 0) colorStepTimer.restart();
        }
    }

    function _flushColorQueue() {
        let n = Math.min(root.colorsPerFrame, root._colorQueue.length);
        for (let i = 0; i < n; i++) {
            let item = root._colorQueue[i];
            root[item.name] = item.value;
        }
        root._colorQueue = root._colorQueue.slice(n);
    }

    FrameAnimation {
        id: colorStepTimer
        onTriggered: {
            root._flushColorQueue();
            if (root._colorQueue.length === 0) stop();
        }
    }

    // Window borders (Settings -> Theme -> Windows) with "follow theme" on: repaint niri's
    // borders from the theme whenever its colours change.
    function hexColor(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    function themeBorderColors() {
        return { "active": root.hexColor(root.mauve), "inactive": root.hexColor(root.surface2), "urgent": root.hexColor(root.red) };
    }

    function applyThemeBorders() {
        const b = (Config.getSetting("windows", {}).borders) || {};
        if (b.followTheme !== true || !Caching.monolithDir || !Quickshell.env("NIRI_SOCKET")) return;
        const c = root.themeBorderColors();
        Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/niri_borders.sh", "set",
            "active=" + c.active, "inactive=" + c.inactive, "urgent=" + c.urgent]);
    }

    Timer {
        id: themeBordersDebounce
        interval: 600
        onTriggered: root.applyThemeBorders()
    }
    onMauveChanged: themeBordersDebounce.restart()
    onSurface2Changed: themeBordersDebounce.restart()
    onRedChanged: themeBordersDebounce.restart()

    FileView {
        id: matugenColorsWatcher
        path: root.matugenConfigPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text().trim();
            if (txt !== "") {
                try {
                    let c = JSON.parse(txt);
                    let target = c && c.colors ? c.colors : c;
                    if (target) {
                        root.matugenColors = target;
                        if (root.isMatugenTheme()) {
                            root.applyColorObject(target);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    FileView {
        id: themeWatcher
        path: root.configPath.startsWith("~") ? (Quickshell.env("HOME") ?? "") + root.configPath.slice(1) : root.configPath
        watchChanges: false

        onLoaded: {
            root._readInProgress = false;
            let txt = text().trim();
            if (txt !== "") {
                try {
                    let c = JSON.parse(txt);
                    let target = c && c.colors ? c.colors : c;
                    if (target) {
                        if (root.isMatugenTheme()) {
                            root.matugenColors = target;
                        }
                        root.applyColorObject(target);
                    }
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: {
        root._readInProgress = true;
        root.updateColors();
        root.updateActiveFontLoader();
    }
}
