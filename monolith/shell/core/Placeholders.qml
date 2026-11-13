pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// BlurHash placeholders: a tiny code per picture (or video) that ui/Placeholder draws as a soft
// blur of its colours while the real thing loads. hash(path) gives the code if it's known and
// asks scripts/blurhash.py for it if not (in batches; it keeps a cache in
// ~/.cache/monolith/blurhash.json, so each file is worked out once). Bindings on hash(path)
// update when the code arrives.
Singleton {
    id: ph

    property var hashes: ({})          // path → hash
    property var asked: ({})           // paths already asked for (or being worked out)
    property var queue: []
    property var pending: ({})         // arrived, not yet handed out

    function hash(path) {
        if (!path) return "";
        const p = String(path).replace(/^file:\/\//, "");
        if (!/^\//.test(p)) return "";           // only files (not http: no fetching for this)
        const h = hashes[p];
        if (h !== undefined) return h;
        if (!asked[p]) { asked[p] = true; queue.push(p); batch.restart(); }
        return "";
    }

    // the cache, read once at start so known codes show at once
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/monolith/blurhash.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                const m = Object.assign({}, ph.hashes);
                for (const k in c) if (c[k] && c[k].h) m[k] = c[k].h;
                ph.hashes = m;
            } catch (e) {}
        }
    }

    Timer {
        id: batch
        interval: 120
        onTriggered: {
            if (proc.running || ph.queue.length === 0) return;
            const list = ph.queue.slice(0, 64);
            ph.queue = ph.queue.slice(64);
            proc.command = ["python3", Qt.resolvedUrl("../scripts/blurhash.py").toString().replace("file://", "")].concat(list);
            proc.running = true;
        }
    }
    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => {
                const tab = line.lastIndexOf("\t");
                if (tab > 0) { ph.pending[line.slice(0, tab)] = line.slice(tab + 1); flush.start(); }
            }
        }
        onExited: { flush.start(); if (ph.queue.length) batch.restart(); }
    }
    // hand the new codes out in batches (a new object, so bindings see it)
    Timer {
        id: flush
        interval: 60
        onTriggered: {
            const m = Object.assign({}, ph.hashes);
            for (const k in ph.pending) m[k] = ph.pending[k];
            ph.pending = ({});
            ph.hashes = m;
        }
    }
}
