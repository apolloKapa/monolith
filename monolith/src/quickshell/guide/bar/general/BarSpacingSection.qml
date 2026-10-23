import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../reusables/guide"

// Settings -> Bar -> Spacing: how far apart the bar's pills sit (the see-through gaps between
// them), the room between its left/centre/right sections, and how thick the Frame's border is.
SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    component SpacingSlider: Draggable {
        id: slider
        property string field: ""
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Layout.rightMargin: section.rootObj.s(8)
        implicitWidth: section.rootObj.s(220)
        implicitHeight: section.rootObj.s(18)
        stepSize: 1
        showValueBubble: true
        valueFormatter: function(v) { return Math.round(v) + "px" }
        value: section.tab[field]
        backgroundColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        handleColor: ThemeBackend.text
        handleBorderColor: ThemeBackend.mantle
        onMoved: function(val) {
            section.tab.clearPendingGroup();
            let rounded = Math.round(val);
            if (section.tab[field] !== rounded) {
                section.tab[field] = rounded;
                section.tab.barWidthDebounceTimer.restart();
            }
        }
        onDragFinished: {
            section.tab.barWidthDebounceTimer.stop();
            section.tab.updateBarSettings();
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "bar_gap"
        icon: "󰡏"
        title: I18n.t("guide.bar.gap.title", "Gap between pills")
        description: I18n.t("guide.bar.gap.desc", "The see-through space between the bar's pills (Modular style, or Solid with distinct pills). 0 joins them")
        searchKeywords: "gap spacing space pills invisible between modules"

        SpacingSlider { field: "pillGap"; from: 0; to: 32; defaultValue: 2 }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "bar_section_gap"
        icon: "󰯌"
        title: I18n.t("guide.bar.section_gap.title", "Gap between sections")
        description: I18n.t("guide.bar.section_gap.desc", "Room between the left, centre and right groups")
        searchKeywords: "gap spacing sections left center right"

        SpacingSlider { field: "sectionGap"; from: 0; to: 96; defaultValue: 10 }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "bar_frame_thickness"
        visible: section.tab.barStyle === "frame"
        icon: "󰹑"
        title: I18n.t("guide.bar.frame_thickness.title", "Border thickness")
        description: I18n.t("guide.bar.frame_thickness.desc", "How thick the Frame's border around the screen is. 0 leaves just the bar")
        searchKeywords: "frame border thickness edge thin thick"

        SpacingSlider { field: "frameThickness"; from: 0; to: 40; defaultValue: 8 }
    }
}
