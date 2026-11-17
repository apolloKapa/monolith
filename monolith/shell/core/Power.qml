pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sleeping, restarting, powering off, logging out: one place for every button and the idle
// timer. On systemd that's `systemctl <action>` (systemd's loginctl has no such commands); with
// elogind (OpenRC, …) it's `loginctl <action>`. When neither can do it you get a notification
// instead of nothing happening.
// The buttons go through a goodbye first (status/Goodbye.qml): each screen is pictured (grim),
// shown blurred, with "Shutting down…" and a small animation over it; the action runs once that
// has played. (Sleep from the idle timer skips it: that happens behind the lock.)
Singleton {
    id: pw
    readonly property string script: 'a="$1"
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then systemctl "$a" && exit 0
elif command -v loginctl >/dev/null 2>&1; then loginctl "$a" && exit 0
fi
notify-send -a Monolith -i dialog-error "Couldn\'t $a" "Neither systemd nor elogind would do it (is your session active, and polkit running?)"'
    function run(action) { Quickshell.execDetached(["sh", "-c", script, "_", action]); }
    // straight away (the idle timer)
    function suspend() { run("suspend"); }
    function hibernate() { run("hibernate"); }

    // ── the buttons: a goodbye first ──
    function sleep() { begin("suspend"); }
    function reboot() { begin("reboot"); }
    function poweroff() { begin("poweroff"); }
    // our own buttons already asked: skip niri's "are you sure"
    function logout() { begin("logout"); }

    // what's happening ("" when nothing): poweroff | reboot | logout | suspend
    property string going: ""
    // the screens' pictures are in (or couldn't be taken): the goodbye shows
    property bool shotsReady: false
    property int shotsTaken: 0
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-goodbye"
    function shotFor(name) { return shotDir + "/" + String(name).replace(/[^A-Za-z0-9_-]/g, "_") + ".png"; }

    function begin(action) {
        if (going !== "") return;
        going = action;
        shotsReady = false;
        shotsTaken++;
        const cmds = Quickshell.screens.map(s => "grim -o '" + String(s.name).replace(/'/g, "") + "' '" + shotFor(s.name) + "' 2>/dev/null");
        shots.command = ["sh", "-c", "umask 077; mkdir -p '" + shotDir + "'; " + (cmds.join(" & ") || "true") + "; wait"];
        shots.running = true;
        shotsLate.restart();
    }
    Process { id: shots; onExited: pw.shown() }
    // (grim slow or missing: the goodbye shows anyway, dimmed instead of blurred)
    Timer { id: shotsLate; interval: 700; onTriggered: pw.shown() }
    function shown() {
        if (shotsReady || going === "") return;
        shotsLate.stop();
        shotsReady = true;
        fire.restart();
    }
    // long enough to see the animation; short with animations off
    Timer { id: fire; interval: Theme.animOn ? 1500 : 350; onTriggered: pw.act() }
    function act() {
        const a = going;
        if (a === "logout") Niri.action(["quit", "--skip-confirmation"]);
        else run(a);
        // waking up from sleep, or an action that didn't happen: the screen comes back
        clear.interval = a === "suspend" ? 2500 : 12000;
        clear.restart();
    }
    Timer { id: clear; onTriggered: { pw.going = ""; pw.shotsReady = false; cleanup.running = true; } }
    Process { id: cleanup; command: ["sh", "-c", "rm -rf \"$1\"", "_", pw.shotDir] }
}
