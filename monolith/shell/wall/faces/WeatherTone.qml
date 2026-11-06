import QtQuick
import "../../core"
import "../../ui"

// The weather's colour, by condition (WMO code): sun amber, clouds grey-blue, rain blue, snow
// white, storm violet, fog grey; and the current icon, temperature and words.
QtObject {
    function tone(code) {
        if (code === undefined || code === null) return Theme.accent;
        if (code === 0) return "#f6c35b";
        if (code <= 2) return "#f2b766";
        if (code === 3) return "#a8b6cc";
        if (code === 45 || code === 48) return "#b6bec9";
        if (code >= 95) return "#b79ce8";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "#e4edf8";
        return "#71a7e6";
    }
    readonly property bool ready: Weather.ready
    readonly property color color: ready ? tone(Weather.current.code) : Theme.accent
    readonly property string icon: ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"
    readonly property string temp: ready ? Math.round(Weather.current.temp) + "°" : "--°"
    readonly property string words: ready ? Weather.describe(Weather.current.code) : ""
}
