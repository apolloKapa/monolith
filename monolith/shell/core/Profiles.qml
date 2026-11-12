pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Profiles (Settings → General → Profiles & backup): named copies of all your settings, to
// switch between ("Clean", "Gaming"…), and a backup to a file you can bring back. Kept in
// ~/.config/monolith/profiles/<name>.json as { name, saved, wallpaper, data }. What's yours
// rather than a look (launch counts, notes, update checks, where the picker was) stays as it is.
Singleton {
    id: pr
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/monolith/profiles"
    readonly property var keep: ["welcome", "launches", "updates", "notes", "software", "quick.calcHistory",
        "wallpaper.pickerPos", "wallpaper.playlistLast", "wallpaper.playlistApplied", "profile", "gaming.session"]
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

    // what goes in a profile: the settings without the personal bits (and without the wallpaper
    // when it shouldn't switch it)
    function snapshot(withWall) {
        const d = JSON.parse(JSON.stringify(Store.data));
        for (const path of keep) {
            const keys = path.split(".");
            let cur = d;
            for (let i = 0; i < keys.length - 1 && cur; i++) cur = cur[keys[i]];
            if (cur && typeof cur === "object") delete cur[keys[keys.length - 1]];
        }
        if (!withWall && d.wallpaper) { delete d.wallpaper.path; delete d.wallpaper.screens; }
        return d;
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
        Store.replace(data, keep.concat(keepWall ? ["wallpaper.path", "wallpaper.screens"] : []));
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

    // ── a backup file of everything (all of next.json), and bringing one back ──
    function exportTo() {
        const p = jobC.createObject(pr, { command: ["sh", "-c",
            "zenity --file-selection --save --confirm-overwrite --title='Back up Monolith settings' --filename=\"$HOME/monolith-settings-$(date +%Y%m%d).json\" 2>/dev/null"] });
        const out = outC.createObject(p);
        p.stdout = out;
        out.streamFinished.connect(() => {
            const f = out.text.trim();
            if (f !== "") writeJson(f, { monolith: "settings", saved: new Date().toISOString(), data: Store.data }, ok => pr.message = ok ? "Backed up to " + f.replace(Quickshell.env("HOME"), "~") : "Couldn't write " + f);
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
