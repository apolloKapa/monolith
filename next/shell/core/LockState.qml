pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Locking: lock() shows the lock screen on every screen; the password goes through PAM
// (the "monolith" service, so a fingerprint works where Monolith set that up).
Singleton {
    id: ls
    property bool locked: false
    property string message: ""
    property bool busy: false
    property int failures: 0
    signal failed()

    function lock() { message = ""; locked = true; }
    function tryPassword(pw) {
        if (busy) return;
        pending = pw;
        busy = true;
        message = "";
        pam.start();
    }
    property string pending: ""

    PamContext {
        id: pam
        config: "monolith"
        onPamMessage: { if (responseRequired) respond(ls.pending); else if (message !== "") ls.message = message; }
        onCompleted: result => {
            ls.busy = false;
            ls.pending = "";
            if (result === PamResult.Success) { ls.failures = 0; ls.locked = false; }
            else { ls.failures++; ls.message = "That's not the password"; ls.failed(); }
        }
        onError: { ls.busy = false; ls.message = "Couldn't check the password"; }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { ls.lock(); }
    }
}
