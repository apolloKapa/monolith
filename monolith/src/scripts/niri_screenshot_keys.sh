#!/usr/bin/env bash
# Keeps niri's keybinds in step with the screenshot tool's keys (Settings -> Screenshots).
# niri handles Mod/Meta combos itself, so a screenshot key like Meta+C never reaches the tool
# when niri already binds Mod+C. Such binds are wrapped to run screenshot_key.sh, which gives
# the key to the screenshot tool while it's open and otherwise runs the original action
# (saved in ~/.config/monolith/niri-key-fallbacks.json). Binds no longer needed are restored.
# niri reloads its config by itself.

conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
settings="${QS_SETTINGS:-$HOME/.config/monolith/settings.json}"
fallbacks="$HOME/.config/monolith/niri-key-fallbacks.json"
file="$(grep -l -E '^\s*binds\s*\{' "$conf_dir/config/keybinds.kdl" "$conf_dir"/config/*.kdl "$conf_dir/config.kdl" 2>/dev/null | head -1)"
[ -n "$file" ] || { echo "no binds block found in $conf_dir" >&2; exit 1; }

# screenshot keys that use Meta, in niri's spelling (Meta+C -> Mod+C)
keys="$(jq -r '
    ({"capture":"Return","copy":"Ctrl+C","edit":"Ctrl+E","cancel":"Escape","mode":"Tab","maximize":"F11"}
     + ((.screenshot.keys) // {})) | .[] | select(test("(^|\\+)(meta|super|mod)\\+"; "i"))
' "$settings" 2>/dev/null | sed -E 's/(^|\+)(Meta|Super|meta|super|mod)\+/\1Mod+/g')"

backup="$(mktemp)"
cp "$file" "$backup"
[ -s "$fallbacks" ] || echo '{}' > "$fallbacks"

python3 - "$file" "$fallbacks" "$keys" <<'EOF'
import json, os, re, sys
MONOLITH_BIN = os.path.expanduser("~/.local/bin/monolith")
path, fb_path, keys = sys.argv[1], sys.argv[2], [k for k in sys.argv[3].split("\n") if k]
text = open(path).read()
fallbacks = json.load(open(fb_path))
norm = lambda k: k.lower()
wanted = {norm(k): k for k in keys}

bind = re.compile(r'^(?P<ind>\s*)(?P<key>[A-Za-z0-9_+]+)(?P<props>[^{\n]*)\{(?P<body>.*)\}\s*$')
out, changed = [], []
for line in text.split("\n"):
    m = bind.match(line)
    if not m:
        out.append(line); continue
    key, body = m.group("key"), m.group("body").strip()
    forwarded = '"screenshot-key"' in body
    if norm(key) in wanted and not forwarded:
        fallbacks[key] = body
        body = f'spawn "{MONOLITH_BIN}" "screenshot-key" "{key}";'
        changed.append(f"wrapped {key}")
    elif forwarded and norm(key) not in wanted:
        body = fallbacks.pop(key, body)
        changed.append(f"restored {key}")
    else:
        out.append(line); continue
    out.append(f'{m.group("ind")}{key}{m.group("props")}{{ {body} }}')
open(path, "w").write("\n".join(out))
json.dump(fallbacks, open(fb_path, "w"), indent=2)
print("\n".join(changed) or "nothing to change")
EOF

if command -v niri >/dev/null && ! niri validate -c "$conf_dir/config.kdl" >/dev/null 2>&1; then
    cp "$backup" "$file"
    echo "niri rejected the change; kept the old keybinds" >&2
    rm -f "$backup"; exit 1
fi
rm -f "$backup"
