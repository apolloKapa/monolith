#!/usr/bin/env python3
"""The settings search's index: every settings row with a plain-text title (and its
description), page by page, from shell/hub/settings/*.qml. Prints JSON:
[{"file": "Capture", "title": "Preview after a shot", "desc": "...", "icon": "..."}, ...]
Rows whose title is worked out at run time (a screen's name…) are left out; their page's
own name still finds them."""
import json, os, re, sys

here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hub", "settings")
STR = r'"((?:[^"\\]|\\.)*)"'
out = []
for name in sorted(os.listdir(here)):
    if not name.endswith(".qml"):
        continue
    src = open(os.path.join(here, name), encoding="utf-8").read()
    page = name[:-4]
    # each row: from its "SettingRow {" to the next row (good enough: the title and desc lines
    # come first in every row)
    parts = re.split(r'\bSettingRow\s*\{', src)[1:]
    for part in parts:
        head = part[:1500]
        t = re.search(r'\btitle:\s*' + STR + r'(?!\s*[+?])', head)
        if not t:
            continue
        d = re.search(r'\bdesc:\s*' + STR + r'(?!\s*[+?])', head)
        i = re.search(r'\bicon:\s*' + STR, head)
        out.append({"file": page, "title": t.group(1).replace('\\"', '"'),
                    "desc": d.group(1).replace('\\"', '"') if d else "",
                    "icon": i.group(1) if i else "tune"})
    for m in re.finditer(r'\bSectionHead\s*\{[^}]*?\btext:\s*' + STR, src):
        out.append({"file": page, "title": m.group(1), "desc": "", "icon": "segment"})
json.dump(out, sys.stdout)
