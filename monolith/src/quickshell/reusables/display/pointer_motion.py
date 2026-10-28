#!/usr/bin/env python3
"""Running total of mouse motion, for liquid glass while niri drags a window.

niri reports no window position during an interactive move, but the window follows the
pointer 1:1, so the glass can follow the pointer instead. Reads relative-motion devices
(mice) without grabbing them and prints "x y" (summed REL_X/REL_Y) whenever it changes,
"down x y" when the left button goes down (niri only reports the drag once the window starts
moving, a few pixels later, so the glass measures from the press) and "up" when it's released
(the glass only follows the pointer while a button is held: a window niri reports no position
for that isn't being dragged mustn't slide the glass around with every mouse movement).
Needs read access to /dev/input (the input group); prints "unavailable" and exits otherwise.

Motion goes out at most once per FLUSH_S (a 240 Hz frame): a gaming mouse reports up to 1000+
times a second, and every line costs the shell a round of bindings on its GUI thread, so
printing each one queued them up and the glass trailed behind the window.
"""
import glob
import os
import select
import struct
import sys
import time

EVENT = struct.Struct("llHHi")
EV_SYN, EV_KEY, EV_REL = 0, 1, 2
REL_X, REL_Y = 0, 1
BTN_LEFT = 0x110


def is_mouse(event_path):
    name = os.path.basename(event_path)
    try:
        with open(f"/sys/class/input/{name}/device/capabilities/rel") as f:
            words = f.read().split()
    except OSError:
        return False
    # the lowest bits come last: REL_X and REL_Y are bits 0 and 1
    return bool(words) and (int(words[-1], 16) & 0b11) == 0b11


RESCAN_MS = 2000
FLUSH_S = 1 / 240


def open_new_mice(opened, poller):
    """Open mice not seen yet (a receiver waking up or a mouse plugged in later)."""
    for path in sorted(glob.glob("/dev/input/event*")):
        if path in opened.values() or not is_mouse(path):
            continue
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        opened[fd] = path
        poller.register(fd, select.POLLIN)


def main():
    opened = {}
    poller = select.poll()
    open_new_mice(opened, poller)
    if not opened:
        print("unavailable", flush=True)
        return
    print("ready", flush=True)
    x = y = 0
    dirty = False
    last_flush = 0.0

    def flush():
        nonlocal dirty, last_flush
        sys.stdout.write(f"{x} {y}\n")
        sys.stdout.flush()
        dirty = False
        last_flush = time.monotonic()

    while True:
        if dirty:
            timeout = max(0, int((last_flush + FLUSH_S - time.monotonic()) * 1000) + 1)
        else:
            timeout = RESCAN_MS
        events = poller.poll(timeout)
        if not events and not dirty:
            open_new_mice(opened, poller)
        for fd, flags in events:
            if flags & (select.POLLERR | select.POLLHUP | select.POLLNVAL):
                poller.unregister(fd)
                os.close(fd)
                opened.pop(fd, None)
                continue
            try:
                data = os.read(fd, EVENT.size * 64)
            except BlockingIOError:
                continue
            for offset in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, offset)
                if kind == EV_REL and code == REL_X:
                    x += value
                    dirty = True
                elif kind == EV_REL and code == REL_Y:
                    y += value
                    dirty = True
                elif kind == EV_KEY and code == BTN_LEFT and value in (0, 1):
                    # the motion before a press/release goes out first, in order
                    if dirty:
                        flush()
                    sys.stdout.write(f"down {x} {y}\n" if value == 1 else "up\n")
                    sys.stdout.flush()
        if dirty and time.monotonic() - last_flush >= FLUSH_S:
            flush()

if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
