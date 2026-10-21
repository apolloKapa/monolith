#!/usr/bin/env bash
# usage: niri_borders.sh get
#        niri_borders.sh set enabled=1 width=2 active=#ffffff inactive=#555555 urgent=#9b0000
# Reads or rewrites the window border block in niri's `layout { border { ... } }`.
# `set` validates the result with niri and puts the old file back if niri rejects it.
# niri reloads its config by itself.

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
file="$(grep -l -E '^layout\s*\{' "$conf_dir/config/layout.kdl" "$conf_dir"/config/*.kdl "$conf_dir/config.kdl" 2>/dev/null | head -1)"
[ -n "$file" ] || { echo "no layout block found in $conf_dir" >&2; exit 1; }

mode="$1"; shift
case "$mode" in
    get|set) ;;
    *) echo "usage: $0 get | set key=value..." >&2; exit 1 ;;
esac

backup="$(mktemp)"
cp "$file" "$backup"

python3 - "$file" "$mode" "$@" <<'EOF' || { rm -f "$backup"; exit 1; }
import json, re, sys
path, mode, args = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(path).read()

def block(text, start):
    """index just past the matching } for the { that ends at start"""
    depth, i = 1, start
    while depth and i < len(text):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return i

lay = re.search(r"^layout\s*\{", text, re.M)
lay_end = block(text, lay.end())
inner = text[lay.end():lay_end - 1]
m = re.search(r"^([ \t]*)border\s*\{", inner, re.M)

cur = {"enabled": True, "width": 4, "active": "#ffc87f", "inactive": "#505050", "urgent": "#9b0000"}
if m:
    b_end = block(inner, m.end())
    body = inner[m.end():b_end - 1]
    cur["enabled"] = not re.search(r"^\s*off\s*;?\s*$", body, re.M)
    w = re.search(r"^\s*width\s+([0-9.]+)", body, re.M)
    if w: cur["width"] = float(w.group(1)) if "." in w.group(1) else int(w.group(1))
    for key, name in (("active", "active-color"), ("inactive", "inactive-color"), ("urgent", "urgent-color")):
        c = re.search(rf'^\s*{name}\s+"([^"]+)"', body, re.M)
        if c: cur[key] = c.group(1)

if mode == "get":
    print(json.dumps(cur))
    sys.exit(0)

new = dict(cur)
for a in args:
    k, _, v = a.partition("=")
    if k == "enabled":
        new["enabled"] = v in ("1", "true", "on", "yes")
    elif k == "width":
        new["width"] = max(1, min(20, int(float(v))))
    elif k in ("active", "inactive", "urgent"):
        if not re.fullmatch(r"#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", v):
            sys.exit(f"not a hex colour: {v}")
        new[k] = v.lower()

ind = m.group(1) if m else "    "
lines = ([f"{ind}    off"] if not new["enabled"] else []) + [
    f"{ind}    width {new['width']}",
    f'{ind}    active-color "{new["active"]}"',
    f'{ind}    inactive-color "{new["inactive"]}"',
    f'{ind}    urgent-color "{new["urgent"]}"',
]
border = f"{ind}border {{\n" + "\n".join(lines) + f"\n{ind}}}"
if m:
    inner = inner[:m.start()] + border + inner[b_end:]
else:
    inner = inner.rstrip() + "\n\n" + border + "\n"
open(path, "w").write(text[:lay.end()] + inner + text[lay_end - 1:])
print(json.dumps(new))
EOF

if [ "$mode" = set ] && command -v niri >/dev/null; then
    if ! niri validate -c "$conf_dir/config.kdl" >/dev/null 2>&1; then
        cp "$backup" "$file"
        echo "niri rejected the new border settings; kept the old ones" >&2
        rm -f "$backup"
        exit 1
    fi
fi
rm -f "$backup"
