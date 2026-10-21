pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property string appClass: ""
    property string appTitle: ""
    readonly property string displayText: appTitle !== "" ? appTitle : appClass
    readonly property bool isFocused: displayText !== ""

    function updateFocus(dataStr) {
        if (!dataStr) return;
        let txt = (typeof dataStr === "string" ? dataStr : "").trim();
        if (txt !== "") {
            try {
                let data = JSON.parse(txt);
                if (data && typeof data === "object") {
                    root.appClass = data.app_class || "";
                    root.appTitle = data.app_title || "";
                }
            } catch(e) {}
        }
    }

    Process {
        id: focusDaemon
        command: ["bash", "-c", "exec " + Caching.monolithDir + "/scripts/current_focus.sh"]
        running: typeof Caching !== "undefined" && Caching.monolithDir !== undefined && Caching.monolithDir !== ""
        stdout: SplitParser {
            onRead: data => root.updateFocus(data)
        }
    }

    FileView {
        id: focusWatcher
        path: (typeof Caching !== "undefined" && Caching.getRunDir && Caching.getRunDir("focustime")) ? (Caching.getRunDir("focustime") + "/focus_state.json") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.updateFocus(text());
        }
    }

    Component.onCompleted: {
        if (typeof focusWatcher.text === "function") {
            root.updateFocus(focusWatcher.text());
        }
    }
}
