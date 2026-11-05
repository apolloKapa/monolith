pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// niri's state, kept up to date from `niri msg -j event-stream`: workspaces per output,
// windows, the focused window and keyboard layouts. Actions go through `niri msg action`.
Singleton {
    id: niri

    property var workspaces: []          // sorted by output, then idx
    property var windows: ({})           // id -> window
    property var focusedWindowId: null
    property var layouts: []
    property int layoutIndex: 0

    readonly property var focusedWindow: focusedWindowId !== null && windows[focusedWindowId] ? windows[focusedWindowId] : null
    readonly property string focusedTitle: focusedWindow ? (focusedWindow.title || "") : ""
    readonly property string focusedAppId: focusedWindow ? (focusedWindow.app_id || "") : ""
    // niri 26.04 does not report fullscreen; kept for when it does
    readonly property bool focusedFullscreen: !!(focusedWindow && focusedWindow.is_fullscreen === true)
    // the screen with the focused workspace
    readonly property string focusedOutput: { const w = workspaces.find(w => w.is_focused); return w ? (w.output || "") : ""; }
    readonly property string layoutName: layouts.length > layoutIndex ? layouts[layoutIndex] : ""

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output);
    }

    function focusWorkspace(idx) { action(["focus-workspace", String(idx)]); }
    function action(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)); }

    function sortWorkspaces(list) {
        return list.slice().sort((a, b) => (a.output === b.output) ? a.idx - b.idx : String(a.output).localeCompare(String(b.output)));
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = sortWorkspaces(ev.WorkspacesChanged.workspaces);
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id, focused = ev.WorkspaceActivated.focused;
            const target = workspaces.find(w => w.id === id);
            if (!target) return;
            workspaces = workspaces.map(w => {
                const n = Object.assign({}, w);
                if (n.output === target.output) n.is_active = (n.id === id);
                if (focused) n.is_focused = (n.id === id);
                return n;
            });
        } else if (ev.WorkspaceActiveWindowChanged) {
            const e = ev.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(w => w.id === e.workspace_id ? Object.assign({}, w, { active_window_id: e.active_window_id }) : w);
        } else if (ev.WindowsChanged) {
            const m = {};
            for (const w of ev.WindowsChanged.windows) { m[w.id] = w; if (w.is_focused) focusedWindowId = w.id; }
            windows = m;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const m = Object.assign({}, windows);
            m[w.id] = w;
            windows = m;
            if (w.is_focused) focusedWindowId = w.id;
        } else if (ev.WindowClosed) {
            const m = Object.assign({}, windows);
            delete m[ev.WindowClosed.id];
            windows = m;
            if (focusedWindowId === ev.WindowClosed.id) focusedWindowId = null;
        } else if (ev.WindowFocusChanged) {
            focusedWindowId = ev.WindowFocusChanged.id;
        } else if (ev.KeyboardLayoutsChanged) {
            layouts = ev.KeyboardLayoutsChanged.keyboard_layouts.names || [];
            layoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx || 0;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIndex = ev.KeyboardLayoutSwitched.idx || 0;
        }
    }

    // a window has windows on it: for the status line's occupied dots
    function workspaceHasWindows(wsId) {
        for (const k in windows) if (windows[k].workspace_id === wsId) return true;
        return false;
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => { try { niri.handle(JSON.parse(line)); } catch (e) {} }
        }
        // niri restarted or the stream dropped: reconnect
        onExited: restart.start()
    }
    Timer { id: restart; interval: 1000; onTriggered: stream.running = true }
}
