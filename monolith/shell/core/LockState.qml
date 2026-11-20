pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Locking: lock() shows the lock screen on every screen; the password goes through PAM
// (the "monolith" service, so a fingerprint works where Monolith set that up).
// It animates both ways: before locking, a picture of each screen is taken (grim, ~30 ms), so the
// lock screen can start as your desktop and blur into itself; on the right password everything
// animates back out to that picture first (`unlocking`), and only then is the session unlocked.
Singleton {
    id: ls
    property bool locked: false
    property string message: ""
    property bool busy: false
    property int failures: 0
    signal failed()

    property bool unlocking: false
    property int shotStamp: 0                // changes with each picture, so it reloads
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-lock"
    function shotFor(name) { return shotDir + "/" + name + ".ppm"; }
    property bool hasShot: false
    // now: lock straight away, without the picture (before suspending)
    function lock(now) {
        if (now === true || !Theme.animOn) {
            // straight away, even if a picture is being taken (it's dropped)
            shootLater.stop(); giveUp.stop(); shooting.running = false; release.stop();
            message = ""; unlocking = false; hasShot = false; locked = true;
            return;
        }
        if (locked || shooting.running || shootLater.running) return;
        message = ""; unlocking = false;
        // an open menu closes first, so it isn't in the picture
        if (HubState.open) { HubState.close(); shootLater.restart(); } else shoot();
    }
    Timer { id: shootLater; interval: 300; onTriggered: ls.shoot() }
    function shoot() {
        shooting.command = ["sh", "-c", "mkdir -p \"$1\"; d=\"$1\"; shift; for o; do grim -t ppm -o \"$o\" \"$d/$o.ppm\" & done; wait", "_", shotDir]
            .concat(Quickshell.screens.map(s => s.name));
        shooting.running = true;
        giveUp.restart();
    }
    Process {
        id: shooting
        onExited: code => { if (!giveUp.running) return; giveUp.stop(); ls.hasShot = code === 0; ls.shotStamp++; ls.locked = true; }
    }
    // never wait long for the picture
    Timer { id: giveUp; interval: 800; onTriggered: { shooting.running = false; ls.hasShot = false; ls.locked = true; } }
    // the right password: animate out, then unlock
    // (as long as the lock screen's way out: lock/LockScreen.qml)
    Timer { id: release; interval: Theme.ms(700); onTriggered: { ls.locked = false; ls.unlocking = false; } }
    function tryPassword(pw) {
        if (busy) return;
        pending = pw;
        busy = true;
        message = "";
        pam.start();
    }
    property string pending: ""
    // what's typed so far, shared by every screen: the keyboard may be on a screen without the
    // password box (Lock & idle → Password box on), and the box shows it wherever it is
    property string typed: ""
    onFailed: typed = ""

    PamContext {
        id: pam
        config: "monolith"
        onPamMessage: { if (responseRequired) respond(ls.pending); else if (message !== "") ls.message = message; }
        onCompleted: result => {
            ls.busy = false;
            ls.pending = "";
            if (result === PamResult.Success) { ls.failures = 0; ls.unlocking = true; release.restart(); Sounds.play("unlock"); }
            else { ls.failures++; ls.message = "That's not the password"; ls.failed(); Sounds.play("error"); }
        }
        onError: { ls.busy = false; ls.message = "Couldn't check the password"; }
    }

    // ── Fingerprint (fprintd), for the Fingerprint widget on the lock screen. While it's locked
    // and this user has a finger enrolled, fprintd-verify waits for a finger: a match unlocks
    // (after the widget has had a moment to turn into its tick), a wrong finger shakes the widget
    // and waits again. Five wrong ones in a row and it stops: the password then.
    // fp: off (no reader, none enrolled, not locked) | ready | fail | ok ──
    property string fp: "off"
    property bool fpEnrolled: false
    property int fpMisses: 0
    signal fpFailed()
    signal fpMatched()
    Process {
        id: fpList
        running: true
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$USER\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: ls.fpEnrolled = /#\d+:/.test(text) }
    }
    Process {
        id: fpVerify
        command: ["fprintd-verify"]
        stdout: SplitParser {
            onRead: line => {
                if (!ls.locked || ls.unlocking) return;
                if (/verify-match/.test(line)) {
                    ls.fp = "ok"; ls.fpMatched(); ls.failures = 0; ls.fpMisses = 0;
                    Sounds.play("unlock"); fpUnlock.restart();
                } else if (/verify-no-match|verify-unknown-error/.test(line)) {
                    ls.fp = "fail"; ls.fpFailed(); ls.fpMisses++;
                    Sounds.play("error"); fpAgain.restart();
                }
            }
        }
        // (it ends after each try, and on a swipe too short to read: wait for the next finger)
        onExited: if (ls.locked && !ls.unlocking && ls.fp === "ready") fpAgain.restart()
    }
    Timer { id: fpUnlock; interval: 650; onTriggered: { ls.unlocking = true; release.restart(); } }
    Timer {
        id: fpAgain; interval: 900
        onTriggered: {
            if (!ls.locked || ls.unlocking || ls.fp === "ok") return;
            if (ls.fpMisses >= 5) { ls.fp = "off"; ls.message = "Too many tries: use your password"; return; }
            ls.fp = "ready";
            fpVerify.running = true;
        }
    }
    function fpStart() {
        fpMisses = 0;
        if (!fpEnrolled) { fp = "off"; return; }
        fp = "ready"; fpVerify.running = true;
    }
    onLockedChanged: {
        typed = "";
        if (locked) Sounds.play("lock");
        if (locked) { fpList.running = true; fpStart(); }
        else { fpAgain.stop(); fpUnlock.stop(); fpVerify.running = false; fp = "off"; }
    }
    // a look at it without a reader (a click on the widget while not locked): wrong, then right
    property bool fpDemoOk: false
    function fpDemo() {
        if (locked || fpDemoEnd.running) return;
        fpDemoOk = !fpDemoOk;
        if (fpDemoOk) { fp = "fail"; fpFailed(); } else { fp = "ok"; fpMatched(); }
        fpDemoEnd.restart();
    }
    Timer { id: fpDemoEnd; interval: 1800; onTriggered: if (!ls.locked) ls.fp = "off" }

    IpcHandler {
        target: "lock"
        function lock(): void { ls.lock(); }
    }
}
