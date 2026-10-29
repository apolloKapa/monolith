#!/usr/bin/env python3
"""Presses wooz's zoom keys for zoom.sh (Meta+Ctrl+scroll).

wooz reads raw key codes, and wtype sends its own temporary keymap's codes (its "+" arrives as
code 1, which wooz takes for Esc and closes), so the keys come from a small virtual keyboard
(/dev/uinput) instead. It's made once and kept while wooz runs: a new input device takes a moment
before the compositor uses it. Commands come through a FIFO, one per line: "in N" (= pressed N
times) or "out N" (-). wooz's key step is small (10 px of the view), so zoom.sh sends a burst per
scroll notch. It quits when wooz does.
"""
import fcntl
import os
import select
import struct
import subprocess
import sys
import time

FIFO = sys.argv[1]
EV_SYN, EV_KEY = 0, 1
KEY_MINUS, KEY_EQUAL = 12, 13
UI_SET_EVBIT, UI_SET_KEYBIT, UI_DEV_CREATE, UI_DEV_DESTROY = 0x40045564, 0x40045565, 0x5501, 0x5502


def wooz_running():
    return subprocess.run(["pgrep", "-x", "wooz"], capture_output=True).returncode == 0


def main():
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
    for k in (KEY_MINUS, KEY_EQUAL):
        fcntl.ioctl(fd, UI_SET_KEYBIT, k)
    os.write(fd, struct.pack("80sHHHHi", b"monolith-zoom-keys", 3, 1, 0x7a6f, 1, 0) + b"\0" * (64 * 4 * 4))
    fcntl.ioctl(fd, UI_DEV_CREATE)

    def tap(key, n):
        # press and release in one go: wooz acts on the press, the release stops its key repeat
        for _ in range(n):
            for value in (1, 0):
                os.write(fd, struct.pack("llHHi", 0, 0, EV_KEY, key, value))
                os.write(fd, struct.pack("llHHi", 0, 0, EV_SYN, 0, 0))
            time.sleep(0.002)

    # read and write ends, so the FIFO never reports end-of-file between commands
    rfd = os.open(FIFO, os.O_RDONLY | os.O_NONBLOCK)
    keep = os.open(FIFO, os.O_WRONLY)
    time.sleep(0.25)          # let the compositor pick up the new keyboard
    buf = b""
    try:
        while wooz_running():
            ready, _, _ = select.select([rfd], [], [], 0.5)
            if not ready:
                continue
            buf += os.read(rfd, 256)
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                parts = line.split()
                n = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1
                if parts[:1] == [b"in"]:
                    tap(KEY_EQUAL, min(n, 100))
                elif parts[:1] == [b"out"]:
                    tap(KEY_MINUS, min(n, 100))
    finally:
        fcntl.ioctl(fd, UI_DEV_DESTROY)
        os.close(fd)
        os.close(rfd)
        os.close(keep)


if __name__ == "__main__":
    main()
