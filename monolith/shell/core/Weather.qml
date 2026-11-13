pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The weather from Open-Meteo for your location (Settings → General: a place you picked, or
// found from your connection), refreshed every 20 minutes (or as set): now, the next hours,
// the next days.
Singleton {
    id: w
    readonly property var loc: Store.get("weather.location", null) || ((Prefs.raw.general && Prefs.raw.general.location) ? Prefs.raw.general.location : null)
    readonly property bool metric: Store.get("weather.unit", (Prefs.raw.general && Prefs.raw.general.weatherUnit === "imperial") ? "imperial" : "metric") !== "imperial"
    onMetricChanged: refresh()
    readonly property string city: loc ? (loc.city || "") : ""
    property var current: null      // { temp, feels, code, day }
    property var hours: []          // [{ time, temp, code, rain }]
    property var days: []           // [{ date, max, min, code }]
    readonly property bool ready: current !== null
    // no place set and none found from the connection either: the widgets say so (instead of
    // "Getting the weather…" for ever)
    property bool noPlace: false

    function icon(code, day) {
        if (code === 0) return day === false ? "clear_night" : "clear_day";
        if (code <= 2) return day === false ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 3) return "cloud";
        if (code <= 48) return "foggy";
        if (code <= 57) return "rainy_light";
        if (code <= 67) return "rainy";
        if (code <= 77) return "weather_snowy";
        if (code <= 82) return "rainy_heavy";
        if (code <= 86) return "snowing_heavy";
        return "thunderstorm";
    }
    function describe(code) {
        if (code === 0) return "Clear";
        if (code <= 2) return "Partly cloudy";
        if (code === 3) return "Cloudy";
        if (code <= 48) return "Fog";
        if (code <= 57) return "Drizzle";
        if (code <= 67) return "Rain";
        if (code <= 77) return "Snow";
        if (code <= 82) return "Showers";
        if (code <= 86) return "Snow showers";
        return "Thunderstorm";
    }
    readonly property string unit: metric ? "°C" : "°F"

    function refresh() {
        if (!loc) return;
        const u = "https://api.open-meteo.com/v1/forecast?latitude=" + loc.latitude + "&longitude=" + loc.longitude
            + "&timezone=" + encodeURIComponent(loc.timezone || "auto")
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability&forecast_hours=24"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=6"
            + (metric ? "" : "&temperature_unit=fahrenheit");
        fetch.command = ["curl", "-sf", "--max-time", "15", u];
        fetch.running = true;
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    w.current = { temp: d.current.temperature_2m, feels: d.current.apparent_temperature, code: d.current.weather_code, day: d.current.is_day === 1 };
                    w.hours = d.hourly.time.map((t, i) => ({ time: t.substring(11, 16), temp: d.hourly.temperature_2m[i], code: d.hourly.weather_code[i], rain: d.hourly.precipitation_probability[i] }));
                    w.days = d.daily.time.map((t, i) => ({ date: t, max: d.daily.temperature_2m_max[i], min: d.daily.temperature_2m_min[i], code: d.daily.weather_code[i] }));
                } catch (e) {}
            }
        }
    }
    Timer { interval: Number(Store.get("weather.interval", 20)) * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: w.refresh() }
    onLocChanged: { if (loc) noPlace = false; refresh(); }

    // No place set (a new install): found from the connection, like Settings → General's
    // "From my connection" button, rounded to about a kilometre and kept as found automatically.
    // A place you set yourself is never replaced. (ipwho.is, then ipapi.co)
    Timer { interval: 4000; running: true; onTriggered: if (!w.loc) w.findPlace() }
    property int tries: 0
    function findPlace() {
        finder.command = ["sh", "-c",
            "curl -sf --max-time 10 'https://ipwho.is/?fields=success,city,latitude,longitude,timezone' " +
            "|| curl -sf --max-time 10 'https://ipapi.co/json/'"];
        finder.running = true;
    }
    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                const lat = d ? Number(d.latitude) : NaN, lon = d ? Number(d.longitude) : NaN;
                if (!w.loc && !isNaN(lat) && !isNaN(lon) && d.success !== false) {
                    const tz = d.timezone ? (typeof d.timezone === "string" ? d.timezone : (d.timezone.id || "auto")) : "auto";
                    Store.set("weather.location", { city: d.city || "", latitude: Math.round(lat * 100) / 100, longitude: Math.round(lon * 100) / 100, timezone: tz, source: "auto" });
                } else if (!w.loc) {
                    // offline at start, maybe: try again in a while, a few times
                    w.tries++;
                    if (w.tries < 4) retry.restart(); else w.noPlace = true;
                }
            }
        }
    }
    Timer { id: retry; interval: 60000; onTriggered: if (!w.loc) w.findPlace() }
}
