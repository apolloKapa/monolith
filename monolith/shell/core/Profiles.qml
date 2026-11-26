pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Profiles (Settings → General → Profiles & backup): named copies of all your settings, to
// switch between ("Clean", "Gaming"…), and a backup to a file you can bring back. Kept in
// ~/.config/monolith/profiles/<name>.json as { name, saved, wallpaper, data }. What's yours
// rather than a look (launch counts, notes, update checks, where the picker was) stays as it is.
// Profiles and backups hold only the look, so they're safe to give to someone: nothing that
// says who you are (your GitHub name, your weather place, your picture) goes in, and paths in
// your home folder are written as ~/… (not /home/<you>/…), made yours again when loaded.
Singleton {
    id: pr
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/monolith/profiles"
    readonly property var keep: ["welcome", "launches", "updates", "notes", "software", "quick.calcHistory",
        "wallpaper.pickerPos", "wallpaper.playlistLast", "wallpaper.playlistApplied", "profile", "gaming.session"]
    // who you are: never written into a profile or a backup, and kept as they are when one is loaded
    readonly property var personal: ["widgets.github.user", "weather.location", "general.avatar"]
    property var list: []              // [{ name, saved, wallpaper, file }]
    readonly property string current: Store.get("profile.current", "")
    property string message: ""

    function fileOf(name) { return dir + "/" + name.replace(/[^\w .-]/g, "_") + ".json"; }
    function refresh() { lister.running = true; }
    Process {
        id: lister
        command: ["python3", "-c",
            "import json,os,sys\nd=sys.argv[1]\nout=[]\n" +
            "for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:\n" +
            "  if f.endswith('.json'):\n" +
            "    try:\n      j=json.load(open(os.path.join(d,f)))\n      out.append({'name':j.get('name',f[:-5]),'saved':j.get('saved',''),'wallpaper':j.get('wallpaper',True),'file':os.path.join(d,f)})\n" +
            "    except Exception: pass\n" +
            "print(json.dumps(out))", pr.dir]
        stdout: StdioCollector { onStreamFinished: { try { pr.list = JSON.parse(text); } catch (e) { pr.list = []; } } }
    }
    Component.onCompleted: refresh()

    // write { name, saved, wallpaper, data } to a file
    Component { id: jobC; Process {} }
    function writeJson(file, obj, then) {
        const p = jobC.createObject(pr, { command: ["python3", "-c",
            "import json,os,sys\nos.makedirs(os.path.dirname(sys.argv[1]),exist_ok=True)\n" +
            "t=sys.argv[1]+'.tmp'\nopen(t,'w').write(sys.argv[2])\nos.replace(t,sys.argv[1])", file, JSON.stringify(obj, null, 2)] });
        p.exited.connect(code => { if (then) then(code === 0); p.destroy(); });
        p.running = true;
    }
    function readJson(file, then) {
        const p = jobC.createObject(pr, { command: ["cat", file] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => { let j = null; try { j = JSON.parse(out.text); } catch (e) {} then(j); p.destroy(); });
        p.running = true;
    }
    Component { id: outC; StdioCollector {} }

    function dropPaths(d, paths) {
        for (const path of paths) {
            const keys = path.split(".");
            let cur = d;
            for (let i = 0; i < keys.length - 1 && cur; i++) cur = cur[keys[i]];
            if (cur && typeof cur === "object") delete cur[keys[keys.length - 1]];
        }
    }
    // every text inside, changed by f (lists and objects gone through)
    function mapText(v, f) {
        if (typeof v === "string") return f(v);
        if (Array.isArray(v)) return v.map(x => pr.mapText(x, f));
        if (v && typeof v === "object") {
            const o = {};
            for (const k in v) o[k] = pr.mapText(v[k], f);
            return o;
        }
        return v;
    }
    // /home/<you>/… -> ~/… (so the file doesn't carry your user name), and back when loaded
    function homeOut(v) {
        const h = Quickshell.env("HOME");
        return pr.mapText(v, t => h && (t === h || t.startsWith(h + "/")) ? "~" + t.slice(h.length) : t);
    }
    function homeIn(v) {
        const h = Quickshell.env("HOME");
        return pr.mapText(v, t => t === "~" ? h : (t.startsWith("~/") ? h + t.slice(1) : t));
    }
    // what goes in a profile: the look only, without what's yours (launch counts, notes…) or
    // who you are, with ~/ for your home folder (and without the wallpaper when it shouldn't
    // switch it)
    function snapshot(withWall) {
        const d = JSON.parse(JSON.stringify(Store.data));
        dropPaths(d, keep.concat(personal));
        if (!withWall && d.wallpaper) { delete d.wallpaper.path; delete d.wallpaper.screens; }
        return homeOut(d);
    }
    function save(name, withWall) {
        name = (name || "").trim();
        if (name === "") return;
        writeJson(fileOf(name), { name: name, saved: new Date().toISOString(), wallpaper: withWall !== false, data: snapshot(withWall !== false) }, ok => {
            if (ok) { Store.set("profile.current", name); pr.message = "Saved “" + name + "”"; }
            else pr.message = "Couldn't save it";
            refresh();
        });
    }
    // switch to one: its settings, keeping the personal bits (and the wallpaper, if it has none)
    function apply(name) {
        const e = list.find(x => x.name === name);
        readJson(e ? e.file : fileOf(name), j => {
            if (!j || typeof j.data !== "object") { pr.message = "Couldn't read “" + name + "”"; return; }
            pr.use(j.data, j.wallpaper === false);
            Store.set("profile.current", j.name || name);
            pr.message = "Switched to “" + (j.name || name) + "”";
        });
    }
    function use(data, keepWall) {
        const before = Store.get("wallpaper.path", "");
        Store.replace(homeIn(data), keep.concat(personal).concat(keepWall ? ["wallpaper.path", "wallpaper.screens"] : []));
        const after = Store.get("wallpaper.path", "");
        if (after !== "" && after !== before) Wall.makePalette(after);
    }
    function remove(name) {
        const e = list.find(x => x.name === name);
        Quickshell.execDetached(["rm", "-f", e ? e.file : fileOf(name)]);
        if (current === name) Store.unset("profile.current");
        removeLater.restart();
    }
    Timer { id: removeLater; interval: 300; onTriggered: pr.refresh() }

    // ── sharing: the look you're on to a file, and someone's profile file into your list ──
    function shareExport() {
        const name = current || "My look";
        const p = jobC.createObject(pr, { command: ["sh", "-c",
            "zenity --file-selection --save --confirm-overwrite --title='Export a Monolith profile' --filename=\"$HOME/$1.monolith.json\" 2>/dev/null", "_", name.replace(/[^\w .-]/g, "_")] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => {
            const f = out.text.trim();
            p.destroy();
            if (f === "") return;
            // (the look only, as a profile is: safe to give to someone)
            writeJson(f, { monolith: "profile", name: name, saved: new Date().toISOString(), wallpaper: true, data: snapshot(true) },
                ok => pr.message = ok ? "Exported “" + name + "” to " + f.replace(Quickshell.env("HOME"), "~") : "Couldn't write " + f);
        });
        p.running = true;
    }
    function shareImport() {
        const p = jobC.createObject(pr, { command: ["sh", "-c", "zenity --file-selection --title='Import a Monolith profile' --file-filter='Monolith profiles | *.json' 2>/dev/null"] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => {
            const f = out.text.trim();
            p.destroy();
            if (f === "") return;
            readJson(f, j => {
                const data = j && typeof j.data === "object" ? j.data : null;
                if (!data) { pr.message = "That isn't a Monolith profile"; return; }
                // its name (or the file's), made unique among yours
                let base = String(j.name || f.replace(/^.*\//, "").replace(/(\.monolith)?\.json$/i, "")).trim() || "Imported";
                base = base.slice(0, 60);
                let name = base, n = 2;
                while (pr.list.some(x => x.name.toLowerCase() === name.toLowerCase())) name = base + " (" + (n++) + ")";
                // (cleaned again: nothing of whoever made it about who they are, no foreign home paths)
                const d = JSON.parse(JSON.stringify(data));
                pr.dropPaths(d, pr.keep.concat(pr.personal));
                writeJson(fileOf(name), { name: name, saved: new Date().toISOString(), wallpaper: j.wallpaper !== false, data: pr.homeOut(d) }, ok => {
                    pr.message = ok ? "Added “" + name + "”: Switch to use it" : "Couldn't add it";
                    pr.refresh();
                });
            });
        });
        p.running = true;
    }

    // ── a backup file of everything (all of next.json), and bringing one back ──
    function exportTo() {
        const p = jobC.createObject(pr, { command: ["sh", "-c",
            "zenity --file-selection --save --confirm-overwrite --title='Back up Monolith settings' --filename=\"$HOME/monolith-settings-$(date +%Y%m%d).json\" 2>/dev/null"] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => {
            const f = out.text.trim();
            // (the look and your other settings, but not who you are, and ~/ for your home folder)
            const d = JSON.parse(JSON.stringify(Store.data));
            pr.dropPaths(d, pr.personal);
            if (f !== "") writeJson(f, { monolith: "settings", saved: new Date().toISOString(), data: pr.homeOut(d) }, ok => pr.message = ok ? "Backed up to " + f.replace(Quickshell.env("HOME"), "~") : "Couldn't write " + f);
            p.destroy();
        });
        p.running = true;
    }
    function importFrom() {
        const p = jobC.createObject(pr, { command: ["sh", "-c", "zenity --file-selection --title='Bring back Monolith settings' --file-filter='Settings | *.json' 2>/dev/null"] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => {
            const f = out.text.trim();
            p.destroy();
            if (f === "") return;
            readJson(f, j => {
                // a backup ({ data }), a profile ({ name, data }) or a bare next.json
                const data = j && typeof j.data === "object" ? j.data : (j && typeof j === "object" ? j : null);
                if (!data) { pr.message = "That isn't a Monolith settings file"; return; }
                // what you had goes into a profile first, so it can come back
                pr.save("Before import " + Qt.formatDateTime(new Date(), "yyyy-MM-dd hh.mm"), true);
                pr.use(data, false);
                pr.message = "Brought back " + f.replace(/^.*\//, "") + " (your previous settings are in “Before import…”)";
            });
        });
        p.running = true;
    }

    IpcHandler {
        target: "profile"
        function apply(name: string): void { pr.apply(name); }
        function save(name: string): void { pr.save(name, true); }
        function list(): string { return pr.list.map(x => x.name).join("\n"); }
    }
}
