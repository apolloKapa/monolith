pragma Singleton
import QtQuick
import Quickshell

// Sleeping, restarting, powering off, logging out: one place for every button and the idle
// timer. On systemd that's `systemctl <action>` (systemd's loginctl has no such commands); with
// elogind (OpenRC, …) it's `loginctl <action>`. When neither can do it you get a notification
// instead of nothing happening.
Singleton {
    id: pw
    readonly property string script: 'a="$1"
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then systemctl "$a" && exit 0
elif command -v loginctl >/dev/null 2>&1; then loginctl "$a" && exit 0
fi
notify-send -a Monolith -i dialog-error "Couldn\'t $a" "Neither systemd nor elogind would do it (is your session active, and polkit running?)"'
    function run(action) { Quickshell.execDetached(["sh", "-c", script, "_", action]); }
    function suspend() { run("suspend"); }
    function hibernate() { run("hibernate"); }
    function reboot() { run("reboot"); }
    function poweroff() { run("poweroff"); }
    // our own buttons already asked: skip niri's "are you sure"
    function logout() { Niri.action(["quit", "--skip-confirmation"]); }
}
