import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Theme → Effects: see-through panels and the blur behind them, the material and finishes drawn
// over panels, and their shadows.
ColumnLayout {
    spacing: 8

    SectionHead { text: "See-through panels" }
    SettingRow {
        key: "theme.transparency"; def: true
        icon: "opacity"; title: "Transparency"
        desc: Theme.liquid ? "Liquid glass is glass: it's always see-through"
            : (Theme.transparent ? "The bar, menus, dock and pop-ups are see-through. Off: plain, solid panels" : "Off: the bar, menus, dock and pop-ups are plain and solid, with no blur")
        Toggle {
            enabled: !Theme.liquid
            opacity: enabled ? 1 : 0.4
            checked: Theme.transparent
            // (on: see-through enough to notice, if the opacity was at 100 %)
            onToggled: on => { Store.set("theme.transparency", on); if (on && Number(Store.get("theme.panelOpacity", 1)) > 0.95) Store.set("theme.panelOpacity", 0.75); }
        }
    }
    SettingRow {
        visible: Theme.transparent
        key: "theme.panelOpacity";
        icon: "opacity"; title: "Panel opacity"; desc: "How solid the bar, menus, dock and pop-ups are. Below 100 % you see through them"
        NumberBox { from: 0.2; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.panelOpacity; onMoved: v => Store.set("theme.panelOpacity", v) }
    }
    SettingRow {
        visible: Theme.transparent
        keys: ["theme.blur", "theme.panelOpacity"];
        icon: "blur_on"; title: "Blur behind panels"
        desc: Theme.liquid ? "Off with Liquid glass: it's glass already, and bends and frosts what's behind it by itself"
            : (Theme.panelOpacity > 0.95 ? "Blurs what's behind see-through panels, with any style. Turning it on also sets the opacity to 75 %, or there'd be nothing to see" : "Blurs what's behind the bar, menus, dock and pop-ups, so text on them stays readable")
        Toggle { enabled: !Theme.liquid; opacity: enabled ? 1 : 0.4; checked: Theme.blur; onToggled: on => { Store.set("theme.blur", on); if (on && Theme.panelOpacity > 0.95) Store.set("theme.panelOpacity", 0.75); } }
    }
    SettingRow {
        visible: Theme.blur
        key: "theme.blurOverFullscreen"; def: true
        icon: "fullscreen"; title: "Blur over fullscreen apps"
        desc: "Menus keep their blur over an app in fullscreen. Off: no blur there (lighter on a slow GPU). Never in Game mode"
        Toggle { checked: Store.get("theme.blurOverFullscreen", true) !== false; onToggled: on => Store.set("theme.blurOverFullscreen", on) }
    }
    SettingRow {
        key: "theme.blurStrength"; def: 3;
        visible: Theme.blur
        icon: "deblur"; title: "Blur strength"; desc: "1 is a light haze, 8 is very soft"
        NumberBox { from: 1; to: 8; value: Number(Store.get("theme.blurStrength", 3)); onMoved: v => Store.set("theme.blurStrength", v) }
    }

    SectionHead { text: "Finishes" }
    // what the panels are made of (ui/MaterialPane): the style's own, none, or any of them
    SettingRow {
        key: "theme.material"; def: ""
        icon: "texture"; title: "Material"
        desc: Theme.liquid ? "Liquid glass is a material of its own"
            : "What the bar, menus and dock are made of" + (Look.style.material ? " (" + Look.style.name + "'s own: " + ({ concrete: "concrete", paper: "paper", steel: "brushed steel" })[Look.style.material] + ")" : "")
        Dropdown {
            width: 220; height: 36
            enabled: !Theme.liquid
            opacity: enabled ? 1 : 0.4
            opts: [["", "The style's own"], ["none", "None (flat)"], ["concrete", "Concrete"], ["paper", "Paper"], ["steel", "Brushed steel"], ["lacquer", "Black lacquer"]]
            value: Store.get("theme.material", "") || ""
            onPicked: v => v === "" ? Store.unset("theme.material") : Store.set("theme.material", v)
        }
    }
    SettingRow {
        key: "theme.materialStrength"; def: 1
        visible: Theme.material !== ""
        icon: "grain"; title: "Texture"; desc: "How much of the material shows"
        NumberBox { from: 0.2; to: 1.5; step: 0.1; decimals: 1; factor: 100; unit: "%"; value: Theme.materialStrength; onMoved: v => Store.set("theme.materialStrength", v) }
    }
    SettingRow {
        key: "theme.effects.grain"; def: false;
        icon: "grain"; title: "Film grain"; desc: "A faint grain over menus, floating panels and the dock"
        Toggle { checked: Theme.fxGrain; onToggled: on => Store.set("theme.effects.grain", on) }
    }
    SettingRow {
        key: "theme.effects.edge"; def: false;
        icon: "highlight"; title: "Edge light"; desc: "A thin line of the accent colour along the top of menus, floating panels and the dock"
        Toggle { checked: Theme.fxEdge; onToggled: on => Store.set("theme.effects.edge", on) }
    }

    SectionHead { text: "Shadows" }
    SettingRow {
        key: "theme.shadow.on"; def: true;
        icon: "shadow"; title: "Shadows"
        desc: Theme.hardShadow > 0 ? "Your style draws its own hard shadow; these settings change the soft one other styles use" : "The soft shadow under the bar, menus, the dock, pop-ups and cards"
        Toggle { checked: Theme.shadowOn; onToggled: on => Store.set("theme.shadow.on", on) }
    }
    SettingRow {
        key: "theme.shadow.strength"; def: 1;
        visible: Theme.shadowOn
        icon: "contrast"; title: "Strength"; desc: "How dark the shadow is. 100 % is the normal shade"
        NumberBox { from: 0.1; to: 2; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.shadowStrength; onMoved: v => Store.set("theme.shadow.strength", v) }
    }
    SettingRow {
        key: "theme.shadow.softness"; def: 0.9;
        visible: Theme.shadowOn
        icon: "blur_medium"; title: "Softness"; desc: "0 % is a crisp edge, 100 % fades out far"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.shadowSoftness; onMoved: v => Store.set("theme.shadow.softness", v) }
    }
    SettingRow {
        key: "theme.shadow.distance"; def: 6;
        visible: Theme.shadowOn
        icon: "vertical_align_bottom"; title: "Distance"; desc: "How far down it falls (0 is all around)"
        NumberBox { from: -20; to: 30; unit: "px"; value: Theme.shadowDistance; onMoved: v => Store.set("theme.shadow.distance", v) }
    }
    SettingRow {
        key: "theme.shadow.sideways"; def: 0;
        visible: Theme.shadowOn
        icon: "swap_horiz"; title: "Direction"; desc: "Left (below 0) or right (above 0) of the shape"
        NumberBox { from: -20; to: 20; unit: "px"; value: Theme.shadowSideways; onMoved: v => Store.set("theme.shadow.sideways", v) }
    }
    SettingRow {
        key: "theme.shadow.colour"; def: "black";
        visible: Theme.shadowOn
        icon: "format_color_fill"; title: "Colour"; desc: "Black, a glow in the accent colour, or the text colour"
        Segmented { width: 260; opts: [["black", "Black"], ["accent", "Accent"], ["ink", "Text"]]; value: ["black", "accent", "ink"].indexOf(Theme.shadowTint) !== -1 ? Theme.shadowTint : "black"; onPicked: v => Store.set("theme.shadow.colour", v) }
    }

    // (the shell's and niri's animations: Animations → Speeds & windows, Animations.qml)
}
