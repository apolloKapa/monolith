import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> General -> Online: features that talk to the internet, all off until switched on.
SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj
    property var online: Config.getSetting("online", {}) || {}

    function setOnline(key, val) {
        let o = Config.getSetting("online", {}) || {};
        o[key] = val;
        Config.setSetting("online", o);
        section.online = o;
    }

    Connections {
        target: Config
        function onSettingsLoaded() { section.online = Config.getSetting("online", {}) || {}; }
    }

    SettingsRow {
        rootObj: section.rootObj
        settingId: "online_song_recognition"
        icon: "󰎈"
        title: I18n.t("guide.general.online.song.title", "Song recognition")
        description: I18n.t("guide.general.online.song.desc", "\"What's this song?\" in the dashboard: records 8 seconds of what your speakers play and sends an audio fingerprint to Shazam (needs songrec)")
        searchKeywords: "song recognition shazam songrec music identify online internet privacy"

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.online.songRecognition === true
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(val) { section.setOnline("songRecognition", val); }
        }
    }

    SettingsRow {
        rootObj: section.rootObj
        settingId: "online_wallhaven"
        icon: "󰸉"
        title: I18n.t("guide.general.online.wallhaven.title", "Wallhaven")
        description: I18n.t("guide.general.online.wallhaven.desc", "Search and download wallpapers from wallhaven.cc (safe-for-work only). Open it with: monolith msg toggle wallhaven")
        searchKeywords: "wallhaven wallpapers download online internet browse search"

        Toggle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: section.online.wallhaven === true
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(val) { section.setOnline("wallhaven", val); }
        }
    }
}
