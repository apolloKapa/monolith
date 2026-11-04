#!/usr/bin/env bash
# usage: niri_outputs.sh set NAME [setting...] [+ NAME [setting...]]...
#   settings: mode=WIDTHxHEIGHT@HZ
#             transform=normal|90|180|270|flipped|flipped-90|flipped-180|flipped-270
#             position=X,Y        (logical pixels, top-left corner of the monitor)
#             scale=S
# Sets monitors' resolution, refresh rate, rotation, position and scale in Monolith's niri
# config (config/output.kdl, or whichever config file already has that output), keeping their
# other lines (vrr, ...). Several monitors ("+" between them) are written in one go, so niri
# never sees half a layout. niri reloads its config by itself, which applies it; the result is
# validated with niri and the old files are put back if niri rejects it.
# Prints each changed output's {mode, transform, position, scale} as JSON.

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
[ "$1" = "set" ] && [ -n "$2" ] || { echo "usage: $0 set NAME [mode=WxH@HZ] [transform=...] [position=X,Y] [scale=S] [+ NAME ...]" >&2; exit 1; }
shift

backup_dir="$(mktemp -d)"
trap 'rm -rf "$backup_dir"' EXIT

python3 - "$conf_dir" "$backup_dir" "$@" <<'EOF' || exit 1
import glob, json, os, re, shutil, sys
conf_dir, backup_dir, argv = sys.argv[1], sys.argv[2], sys.argv[3:]

TRANSFORMS = ("normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270")

# NAME k=v k=v + NAME k=v ...
groups, cur = [], None
for a in argv:
    if a == "+":
        cur = None
    elif cur is None:
        cur = {"name": a, "want": {}}
        groups.append(cur)
    else:
        k, _, v = a.partition("=")
        w = cur["want"]
        if k == "mode":
            m = re.fullmatch(r"(\d+)x(\d+)@(\d+(?:\.\d+)?)", v)
            if not m:
                sys.exit(f"not a mode: {v}")
            w["mode"] = f"{m.group(1)}x{m.group(2)}@{float(m.group(3)):.3f}"
        elif k == "transform":
            if v not in TRANSFORMS:
                sys.exit(f"not a rotation: {v}")
            w["transform"] = v
        elif k == "position":
            m = re.fullmatch(r"(-?\d+),(-?\d+)", v)
            if not m:
                sys.exit(f"not a position: {v}")
            w["position"] = (int(m.group(1)), int(m.group(2)))
        elif k == "scale":
            try:
                s = float(v)
            except ValueError:
                sys.exit(f"not a scale: {v}")
            if not 0.25 <= s <= 10:
                sys.exit(f"not a scale: {v}")
            w["scale"] = s
        else:
            sys.exit(f"unknown setting: {k}")

files = sorted(glob.glob(os.path.join(conf_dir, "config", "*.kdl"))) + [os.path.join(conf_dir, "config.kdl")]
default_file = os.path.join(conf_dir, "config", "output.kdl")

def file_for(name):
    pat = re.compile(rf'^output\s+"{re.escape(name)}"', re.M)
    for f in files:
        try:
            if pat.search(open(f).read()):
                return f
        except OSError:
            pass
    return default_file

def block_end(text, start):
    """index just past the } matching the { that ends at start"""
    depth, i = 1, start
    while depth and i < len(text):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return i

texts, results = {}, {}
for g in groups:
    path = file_for(g["name"])
    if path not in texts:
        if not os.path.isfile(path):
            sys.exit(f"no niri output config at {path}")
        shutil.copy(path, os.path.join(backup_dir, str(len(texts))))
        texts[path] = open(path).read()
    text, name, want = texts[path], g["name"], g["want"]

    m = re.search(rf'^output\s+"{re.escape(name)}"\s*\{{', text, re.M)
    if m:
        end = block_end(text, m.end())
        body = text[m.end():end - 1]
    else:
        body = "\n"
    lines = body.split("\n")

    def set_line(key, new):
        for i, l in enumerate(lines):
            if re.match(rf"^\s*{key}(\s|$)", l):
                lines[i] = "    " + new
                return
        # a new line goes after the last real line
        last = max((i for i, l in enumerate(lines) if l.strip()), default=0)
        lines.insert(last + 1, "    " + new)

    # a monitor set to off gets turned on by choosing a mode for it
    if "mode" in want:
        lines = [l for l in lines if not re.match(r"^\s*off\s*;?\s*$", l)]
        set_line("mode", f'mode "{want["mode"]}"')
    if "transform" in want:
        if want["transform"] == "normal":
            lines = [l for l in lines if not re.match(r"^\s*transform\s", l)]
        else:
            set_line("transform", f'transform "{want["transform"]}"')
    if "position" in want:
        x, y = want["position"]
        set_line("position", f"position x={x} y={y}")
    if "scale" in want:
        s = f"{want['scale']:.3f}".rstrip("0")      # 1.0, 1.25, 1.333
        set_line("scale", "scale " + (s + "0" if s.endswith(".") else s))

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
    texts[path] = text

    get = lambda pat: re.search(pat, new_body, re.M)
    mo, tf = get(r'^\s*mode\s+"([^"]+)"'), get(r'^\s*transform\s+"([^"]+)"')
    po, sc = get(r"^\s*position\s+x=(-?\d+)\s+y=(-?\d+)"), get(r"^\s*scale\s+([0-9.]+)")
    results[name] = {
        "mode": mo.group(1) if mo else "",
        "transform": tf.group(1) if tf else "normal",
        "position": [int(po.group(1)), int(po.group(2))] if po else None,
        "scale": float(sc.group(1)) if sc else None,
    }

# remember which backup belongs to which file, for the shell part to restore
with open(os.path.join(backup_dir, "index"), "w") as f:
    for i, path in enumerate(texts):
        f.write(f"{i}\t{path}\n")
for path, text in texts.items():
    with open(path, "r+") as f:      # same file (inode): niri keeps watching it
        f.seek(0)
        f.write(text)
        f.truncate()
print(json.dumps(results))
EOF

if command -v niri >/dev/null 2>&1 && ! niri validate -c "$conf_dir/config.kdl" >/dev/null 2>&1; then
    while IFS=$'\t' read -r i path; do
        cat "$backup_dir/$i" > "$path"
    done < "$backup_dir/index"
    echo "niri rejected the new display settings; nothing was changed" >&2
    exit 1
fi
