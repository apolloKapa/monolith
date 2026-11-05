import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Theme → Effects: see-through panels, the blur behind them, and the animations.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "opacity"; title: "Panel opacity"; desc: "How solid the bar, menus, dock and panels are (below 100 % the blur shows through)"
        NumberBox { from: 0.2; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Theme.panelOpacity; onMoved: v => Store.set("theme.panelOpacity", v) }
    }
    SettingRow {
        icon: "blur_on"; title: "Blur behind panels"; desc: "The compositor blurs what's behind the bar, menus, dock and pop-ups"
        Toggle { checked: Theme.blur; onToggled: on => { Store.set("theme.blur", on); if (on && Theme.panelOpacity > 0.95) Store.set("theme.panelOpacity", 0.75); } }
    }
    SettingRow {
        icon: "deblur"; title: "Blur strength"; desc: "How soft (written to niri's config, monolith-shell.kdl)"
        NumberBox { from: 1; to: 8; value: Number(Store.get("theme.blurStrength", 3)); onMoved: v => Store.set("theme.blurStrength", v) }
    }
    SettingRow {
        icon: "animation"; title: "Animations"; desc: "Off: everything appears at once"
        Toggle { checked: Theme.animOn; onToggled: on => Store.set("theme.animations", on) }
    }
    SettingRow {
        icon: "speed"; title: "Animation speed"; desc: "Faster or slower than normal"
        NumberBox { from: 0.25; to: 3; step: 0.05; decimals: 2; unit: "×"; value: Number(Store.get("theme.animSpeed", 1)); onMoved: v => Store.set("theme.animSpeed", v) }
    }
}
