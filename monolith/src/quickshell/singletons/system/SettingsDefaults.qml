pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// The settings Monolith ships with (config/monolith/settings.json, copied next to the shell as
// assets/default_settings.json when it's installed). Settings rows use it for their Reset
// button: a row whose value differs from this gets a button that puts it back.
Item {
    id: root

    property var data: ({})
    // after a reset: the open Settings page rebuilds itself so every control shows the default
    signal resetDone(string path)

    function _at(obj, path) {
        let cur = obj;
        const parts = path.split(".");
        for (let i = 0; i < parts.length; i++) {
            if (cur === null || cur === undefined || typeof cur !== "object") return undefined;
            cur = cur[parts[i]];
        }
        return cur;
    }

    // the shipped value at "section.key.sub", or undefined
    function value(path) { return root._at(root.data, path); }
    // the current value at that path
    function current(path) { return root._at(Config.rawSettings || {}, path); }

    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }

    // has this setting been changed away from its default? (fallback: the default the code
    // uses when the shipped file doesn't have the key)
    function isChanged(path, fallback) {
        const cur = root.current(path);
        if (cur === undefined) return false;
        let def = root.value(path);
        if (def === undefined) def = fallback;
        if (def === undefined) return true;
        return !root.same(cur, def);
    }

    // put a setting back to its default (or remove it, so the code's own default applies)
    function reset(path) {
        const parts = path.split(".");
        const section = parts[0];
        let obj = JSON.parse(JSON.stringify(Config.getSetting(section, {}) || {}));
        const def = root.value(path);
        if (parts.length === 1) {
            Config.setSetting(section, def === undefined ? {} : JSON.parse(JSON.stringify(def)));
            root.resetDone(path);
            return;
        }
        let cur = obj;
        for (let i = 1; i < parts.length - 1; i++) {
            if (cur[parts[i]] === undefined || typeof cur[parts[i]] !== "object") cur[parts[i]] = {};
            cur = cur[parts[i]];
        }
        const last = parts[parts.length - 1];
        if (def === undefined) delete cur[last];
        else cur[last] = JSON.parse(JSON.stringify(def));
        Config.setSetting(section, obj);
        root.resetDone(path);
    }

    FileView {
        id: installedFile
        path: Caching.monolithDir ? Caching.monolithDir + "/assets/default_settings.json" : ""
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: repoFile.path = Caching.monolithDir + "/../../config/monolith/settings.json"
    }
    // running from the repo: the file the installer copies
    FileView {
        id: repoFile
        path: ""
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
    }
}
