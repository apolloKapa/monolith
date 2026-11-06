import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// General: your picture (lock screen), where you are (for the weather and night light's
// sunset), the weather's units and how often it refreshes.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var loc: Weather.loc
    property var found: []
    property string status: ""

    // places by name (Open-Meteo's geocoding)
    Process {
        id: geo
        property string q: ""
        command: ["curl", "-sf", "--max-time", "10", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&name=" + encodeURIComponent(q)]
        stdout: StdioCollector {
            onStreamFinished: {
                try { sec.found = (JSON.parse(text).results || []).map(r => ({ city: r.name, latitude: r.latitude, longitude: r.longitude, timezone: r.timezone || "auto", label: [r.name, r.admin1, r.country].filter(x => x).join(", ") })); }
                catch (e) { sec.found = []; }
                sec.status = sec.found.length ? "" : "Nothing found";
            }
        }
    }
    // from your connection (city level; the address isn't kept)
    Process {
        id: ipLoc
        command: ["curl", "-sf", "--max-time", "10", "https://ipwho.is/?fields=city,latitude,longitude,timezone"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.latitude !== undefined) { Store.set("weather.location", { city: d.city || "", latitude: d.latitude, longitude: d.longitude, timezone: (d.timezone && d.timezone.id) || "auto" }); sec.status = ""; Weather.refresh(); }
                    else sec.status = "Couldn't find it";
                } catch (e) { sec.status = "Couldn't find it"; }
            }
        }
    }

    // ── you ──
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : Quickshell.env("HOME") + "/.face")
    SettingRow {
        key: "general.avatar"; def: "";
        icon: "account_circle"; title: "Your picture"; desc: "On the lock screen. An image file"
        Row {
            spacing: 10
            Avatar { size: 40; anchors.verticalCenter: parent.verticalCenter }
            Field { width: 260; text: Store.get("general.avatar", ""); placeholder: sec.avatar.replace(Quickshell.env("HOME"), "~"); onAccepted: v => { const p = v.trim().replace(/^~/, Quickshell.env("HOME")); if (p !== Store.get("general.avatar", "")) Store.set("general.avatar", p); } }
        }
    }

    // ── where you are ──
    SettingRow {
        icon: "location_on"; title: "Location"
        desc: (sec.loc ? (sec.loc.city || "Set") + "  ·  " + Number(sec.loc.latitude).toFixed(2) + ", " + Number(sec.loc.longitude).toFixed(2) : "Not set: no weather yet") + (sec.status !== "" ? "   ·   " + sec.status : "")
        Row {
            spacing: 6
            Field { width: 200; placeholder: "Find a city"; onAccepted: v => { if (v.trim() !== "") { geo.q = v.trim(); sec.status = "Looking…"; geo.running = true; } } }
            Button { text: "From my connection"; icon: "my_location"; onClicked: { sec.status = "Looking…"; ipLoc.running = true; } }
        }
    }
    Repeater {
        model: sec.found
        Pressable {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: Theme.containerHigh
            onClicked: { Store.set("weather.location", { city: modelData.city, latitude: modelData.latitude, longitude: modelData.longitude, timezone: modelData.timezone }); sec.found = []; Weather.refresh(); }
            Row {
                x: 16; spacing: 10
                anchors.verticalCenter: parent.verticalCenter
                Icon { name: "pin_drop"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: parent.parent.modelData.label; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ── the weather ──
    SettingRow {
        key: "weather.unit";
        icon: "thermostat"; title: "Temperature units"
        Segmented { opts: [["metric", "°C, km/h"], ["imperial", "°F, mph"]]; value: Weather.metric ? "metric" : "imperial"; onPicked: v => Store.set("weather.unit", v) }
    }
    SettingRow {
        key: "weather.interval"; def: 20;
        icon: "update"; title: "Weather refresh"; desc: "How often it looks again"
        NumberBox { from: 5; to: 720; slideTo: 120; step: 5; unit: "min"; value: Number(Store.get("weather.interval", 20)); onMoved: v => Store.set("weather.interval", v) }
    }
}
