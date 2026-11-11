import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Theme → Effects: see-through panels and the blur behind them, the finishes drawn over
// panels, and how things move.
ColumnLayout {
    spacing: 8

    SectionHead { text: "See-through panels" }
    SettingRow {
        key: "theme.panelOpacity";
        icon: "opacity"; title: "Panel opacity"; desc: "How solid the bar, menus, dock and pop-ups are. Below 100 % you see through them"
        NumberBox { from: 0.2; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.panelOpacity; onMoved: v => Store.set("theme.panelOpacity", v) }
    }
    SettingRow {
        keys: ["theme.blur", "theme.panelOpacity"];
        icon: "blur_on"; title: "Blur behind panels"
        desc: Theme.panelOpacity > 0.95 ? "Blurs what's behind see-through panels. Turning it on also sets the opacity to 75 %, or there'd be nothing to see" : "Blurs what's behind the bar, menus, dock and pop-ups, so text on them stays readable"
        Toggle { checked: Theme.blur; onToggled: on => { Store.set("theme.blur", on); if (on && Theme.panelOpacity > 0.95) Store.set("theme.panelOpacity", 0.75); } }
    }
    SettingRow {
        key: "theme.blurStrength"; def: 3;
        visible: Theme.blur
        icon: "deblur"; title: "Blur strength"; desc: "1 is a light haze, 8 is very soft"
        NumberBox { from: 1; to: 8; value: Number(Store.get("theme.blurStrength", 3)); onMoved: v => Store.set("theme.blurStrength", v) }
    }

    SectionHead { text: "Finishes" }
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
    SettingRow {
        key: "widgets.shadow"; def: "off";
        icon: "widgets"; title: "Shadows under widgets"
        desc: "For every desktop and lock screen widget that doesn't pick its own (each widget's Shadow setting)"
        Segmented { width: 260; opts: [["off", "Off"], ["soft", "Soft"], ["strong", "Strong"]]; value: Theme.widgetShadow; onPicked: v => Store.set("widgets.shadow", v) }
    }

    SectionHead { text: "Motion" }
    SettingRow {
        key: "theme.animations";
        icon: "animation"; title: "Animations"; desc: "Off: the bar, menus and pop-ups appear at once, with no movement"
        Toggle { checked: Theme.animOn; onToggled: on => Store.set("theme.animations", on) }
    }
    SettingRow {
        key: "theme.animSpeed"; def: 1;
        visible: Theme.animOn
        icon: "speed"; title: "Animation speed"
        desc: { const v = Number(Store.get("theme.animSpeed", 1)); return v === 1 ? "1 × is normal. Higher is faster, lower is slower" : (v > 1 ? "Animations take " + (Math.round(100 / v) / 100) + " × as long as normal (faster)" : "Animations take " + (Math.round(100 / v) / 100) + " × as long as normal (slower)"); }
        NumberBox { from: 0.25; to: 3; step: 0.05; decimals: 2; unit: "×"; value: Number(Store.get("theme.animSpeed", 1)); onMoved: v => Store.set("theme.animSpeed", v) }
    }
    SettingRow {
        key: "theme.effects.unfold"; def: false;
        visible: Theme.animOn
        icon: Theme.fxUnfold ? "unfold_more" : "zoom_out_map"; title: "How menus open"
        desc: Theme.fxUnfold ? "Unfold: a menu opens out of a thin bright line through its middle, and folds back into it" : "Zoom: a menu fades in while growing a little, and shrinks away"
        Segmented { width: 220; opts: [["zoom", "Zoom"], ["unfold", "Unfold"]]; value: Theme.fxUnfold ? "unfold" : "zoom"; onPicked: v => Store.set("theme.effects.unfold", v === "unfold") }
    }
}
