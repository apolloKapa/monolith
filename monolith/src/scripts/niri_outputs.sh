#!/usr/bin/env bash
# usage: niri_outputs.sh set NAME [mode=WIDTHxHEIGHT@HZ] [transform=normal|90|180|270|flipped|flipped-90|flipped-180|flipped-270]
# Sets a monitor's resolution, refresh rate and rotation in Monolith's niri config
# (config/output.kdl, or whichever config file already has that output), keeping its other
# lines (position, scale, vrr...). niri reloads its config by itself, which applies it;
# `set` validates the result with niri and puts the old file back if niri rejects it.
# Prints the output's new {mode, transform} as JSON.

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
[ "$1" = "set" ] && [ -n "$2" ] || { echo "usage: $0 set NAME [mode=WxH@HZ] [transform=...]" >&2; exit 1; }
name="$2"; shift 2

file="$(grep -l -E "^output[[:space:]]+\"$name\"" "$conf_dir"/config/*.kdl "$conf_dir/config.kdl" 2>/dev/null | head -1)"
[ -n "$file" ] || file="$conf_dir/config/output.kdl"
[ -f "$file" ] || { echo "no niri output config at $file" >&2; exit 1; }

backup="$(mktemp)"
cp "$file" "$backup"

python3 - "$file" "$name" "$@" <<'EOF' || { cp "$backup" "$file"; rm -f "$backup"; exit 1; }
import json, re, sys
path, name, args = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(path).read()

TRANSFORMS = ("normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270")
want = {}
for a in args:
    k, _, v = a.partition("=")
    if k == "mode":
        m = re.fullmatch(r"(\d+)x(\d+)@(\d+(?:\.\d+)?)", v)
        if not m:
            sys.exit(f"not a mode: {v}")
        want["mode"] = f"{m.group(1)}x{m.group(2)}@{float(m.group(3)):.3f}"
    elif k == "transform":
        if v not in TRANSFORMS:
            sys.exit(f"not a rotation: {v}")
        want["transform"] = v
    else:
        sys.exit(f"unknown setting: {k}")

def block_end(text, start):
    """index just past the } matching the { that ends at start"""
    depth, i = 1, start
    while depth and i < len(text):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return i

m = re.search(rf'^output\s+"{re.escape(name)}"\s*\{{', text, re.M)
if m:
    end = block_end(text, m.end())
    body = text[m.end():end - 1]
else:
    body = "\n"

lines = [l for l in body.split("\n")]
def set_line(key, value):
    global lines
    new = f'    {key} "{value}"'
    for i, l in enumerate(lines):
        if re.match(rf"^\s*{key}\s", l):
            lines[i] = new
            return
    # a new line goes after the last real line
    last = max((i for i, l in enumerate(lines) if l.strip()), default=0)
    lines.insert(last + 1, new)

# a monitor set to off gets turned on by choosing a mode for it
if "mode" in want:
    lines = [l for l in lines if not re.match(r"^\s*off\s*;?\s*$", l)]
    set_line("mode", want["mode"])
if "transform" in want:
    if want["transform"] == "normal":
        lines = [l for l in lines if not re.match(r"^\s*transform\s", l)]
    else:
        set_line("transform", want["transform"])

new_body = "\n".join(lines)
if not new_body.startswith("\n"):
    new_body = "\n" + new_body
if not new_body.endswith("\n"):
    new_body += "\n"
block = f'output "{name}" {{{new_body}}}'
if m:
    text = text[:m.start()] + block + text[end:]
else:
    text = text.rstrip("\n") + "\n\n" + block + "\n"
with open(path, "r+") as f:      # same file (inode): niri keeps watching it
    f.seek(0)
    f.write(text)
    f.truncate()

cur_mode = re.search(r'^\s*mode\s+"([^"]+)"', new_body, re.M)
cur_tf = re.search(r'^\s*transform\s+"([^"]+)"', new_body, re.M)
print(json.dumps({"mode": cur_mode.group(1) if cur_mode else "", "transform": cur_tf.group(1) if cur_tf else "normal"}))
EOF

if command -v niri >/dev/null 2>&1 && ! niri validate -c "$conf_dir/config.kdl" >/dev/null 2>&1; then
    cp "$backup" "$file"
    rm -f "$backup"
    echo "niri rejected the new display settings; nothing was changed" >&2
    exit 1
fi
rm -f "$backup"
