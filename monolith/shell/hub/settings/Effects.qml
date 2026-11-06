import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Theme → Effects: see-through panels, the blur behind them, and the animations.
ColumnLayout {
    spacing: 8
    SettingRow {
        key: "theme.panelOpacity";
        icon: "opacity"; title: "Panel opacity"; desc: "How solid the bar, menus, dock and panels are (below 100 % the blur shows through)"
        NumberBox { from: 0.2; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.panelOpacity; onMoved: v => Store.set("theme.panelOpacity", v) }
    }
    SettingRow {
        keys: ["theme.blur", "theme.panelOpacity"];
        icon: "blur_on"; title: "Blur behind panels"; desc: "The compositor blurs what's behind the bar, menus, dock and pop-ups"
        Toggle { checked: Theme.blur; onToggled: on => { Store.set("theme.blur", on); if (on && Theme.panelOpacity > 0.95) Store.set("theme.panelOpacity", 0.75); } }
    }
    SettingRow {
        key: "theme.blurStrength"; def: 3;
        icon: "deblur"; title: "Blur strength"; desc: "How soft (written to niri's config, monolith-shell.kdl)"
        NumberBox { from: 1; to: 8; value: Number(Store.get("theme.blurStrength", 3)); onMoved: v => Store.set("theme.blurStrength", v) }
    }
    SettingRow {
        key: "theme.effects.grain"; def: false;
        icon: "grain"; title: "Grain"; desc: "A faint film grain over menus, floating panels and the dock"
        Toggle { checked: Theme.fxGrain; onToggled: on => Store.set("theme.effects.grain", on) }
    }
    SettingRow {
        key: "theme.effects.edge"; def: false;
        icon: "highlight"; title: "Edge light"; desc: "A thin accent light along the top of menus, floating panels and the dock"
        Toggle { checked: Theme.fxEdge; onToggled: on => Store.set("theme.effects.edge", on) }
    }
    SettingRow {
        key: "theme.effects.unfold"; def: false;
        icon: "unfold_more"; title: "Unfold"; desc: "Menus open out of a thin line through their middle, and fold back into it"
        Toggle { checked: Store.get("theme.effects.unfold", Theme.oldFx.unfold === true) === true; onToggled: on => Store.set("theme.effects.unfold", on) }
    }
    SettingRow {
        key: "theme.animations";
        icon: "animation"; title: "Shell animations"; desc: "The bar, menus and pop-ups. Off: everything appears at once"
        Toggle { checked: Theme.animOn; onToggled: on => Store.set("theme.animations", on) }
    }
    SettingRow {
        key: "theme.animSpeed"; def: 1;
        icon: "speed"; title: "Shell animation speed"; desc: "Faster or slower than normal"
        NumberBox { from: 0.25; to: 3; step: 0.05; decimals: 2; unit: "×"; value: Number(Store.get("theme.animSpeed", 1)); onMoved: v => Store.set("theme.animSpeed", v) }
    }
}
