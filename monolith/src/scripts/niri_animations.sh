#!/usr/bin/env bash
# usage: niri_animations.sh <speed>|off
# Applies Monolith's animation speed to niri's window animations by editing the `animations`
# block (slowdown / off) in ~/.config/niri. Your own slowdown is kept as the base: speed 1 = it.
# niri reloads its config by itself.

arg="$1"
[ -n "$arg" ] || { echo "usage: $0 <speed>|off" >&2; exit 1; }

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
file="$(grep -l -E '^\s*animations\s*\{' "$conf_dir/config/layout.kdl" "$conf_dir/config.kdl" "$conf_dir"/config/*.kdl 2>/dev/null | head -1)"
[ -n "$file" ] || { echo "no animations block found in $conf_dir" >&2; exit 1; }

python3 - "$file" "$arg" <<'EOF'
import re, sys
path, arg = sys.argv[1], sys.argv[2]
text = open(path).read()
m = re.search(r"^(\s*)animations\s*\{", text, re.M)
start = m.end()
depth, i = 1, start
while depth and i < len(text):
    depth += {"{": 1, "}": -1}.get(text[i], 0)
    i += 1
body = text[start:i - 1]
ind = m.group(1) + "    "

base = re.search(r"//\s*monolith-base-slowdown\s+([0-9.]+)", body)
if base:
    base = float(base.group(1))
else:
    cur = re.search(r"^\s*slowdown\s+([0-9.]+)", body, re.M)
    base = float(cur.group(1)) if cur else 1.0

body = re.sub(r"^\s*(off|slowdown\s+[0-9.]+|//\s*monolith-base-slowdown.*)\s*\n", "", body, flags=re.M)
lines = [f"{ind}// monolith-base-slowdown {base:g}"]
if arg == "off":
    lines.append(f"{ind}off")
else:
    speed = max(0.25, min(3.0, float(arg)))
    lines.append(f"{ind}slowdown {base / speed:.3g}")
body = "\n" + "\n".join(lines) + "\n" + body.lstrip("\n")
open(path, "w").write(text[:start] + body + text[i - 1:])
EOF
