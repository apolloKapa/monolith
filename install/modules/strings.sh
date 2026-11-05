#!/usr/bin/env bash
# The installer's messages, from install/strings.json:  t "installer.deps.syncing" "pkg=foo"
# fills {pkg} in the text. A key that isn't there prints as itself.
STRINGS_FILE="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/strings.json"

t() {
    python3 - "$STRINGS_FILE" "$@" <<'PY' 2>/dev/null || printf '%s' "$1"
import json, sys
path, key, *args = sys.argv[1:]
node = json.load(open(path, encoding="utf-8"))
for part in key.split("."):
    node = node.get(part, key) if isinstance(node, dict) else key
text = node if isinstance(node, str) else key
for a in args:
    name, _, value = a.partition("=")
    text = text.replace("{" + name + "}", value)
sys.stdout.write(text)
PY
}
