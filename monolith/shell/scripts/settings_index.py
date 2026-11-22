#!/usr/bin/env python3
"""The settings search's index: every settings row with a plain-text title (and its
description), page by page, from shell/hub/settings/*.qml. Prints JSON:
[{"file": "Capture", "title": "Preview after a shot", "desc": "...", "icon": "...",
  "only": "", "link": false}, ...]
  only  "niri" or "hyprland" for a row (or heading) that's only there on that desktop (its
        `show:` or `visible:` says so), so the search doesn't offer the other desktop's twin
  link  the row only points at another page (an Open button): left out of the results when the
        setting itself is among them
Rows whose title is worked out at run time (a screen's name…) are left out; their page's
own name still finds them."""
import json, os, re, sys

here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hub", "settings")
STR = r'"((?:[^"\\]|\\.)*)"'


def block(src, start):
    """the block that opens just before src[start]: (all of it, only what's directly in it,
    without its children's blocks). Strings and // comments don't count as braces."""
    depth, i, n, own = 1, start, len(src), []
    while i < n and depth:
        ch = src[i]
        if ch == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            if depth == 1:
                own.append(src[i:j + 1])
            i = j + 1
            continue
        if ch == "/" and src[i:i + 2] == "//":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif depth == 1:
            own.append(ch)
        i += 1
    return src[start:i], "".join(own)


def only(expr):
    """which desktop a show/visible expression keeps it to"""
    if "!Niri.hyprland" in expr:
        return "niri"
    return "hyprland" if "Niri.hyprland" in expr else ""


out = []
for name in sorted(os.listdir(here)):
    if not name.endswith(".qml"):
        continue
    src = open(os.path.join(here, name), encoding="utf-8").read()
    page = name[:-4]
    for m in re.finditer(r'\bSettingRow\s*\{', src):
        whole, own = block(src, m.end())
        t = re.search(r'\btitle:\s*' + STR + r'(?!\s*[+?])', own)
        if not t:
            continue
        d = re.search(r'\bdesc:\s*' + STR + r'(?!\s*[+?])', own)
        i = re.search(r'\bicon:\s*' + STR, own)
        s = re.search(r'\bshow:\s*([^\n;]*)', own)
        out.append({"file": page, "title": t.group(1).replace('\\"', '"'),
                    "desc": d.group(1).replace('\\"', '"') if d else "",
                    "icon": i.group(1) if i else "tune",
                    "only": only(s.group(1)) if s else "",
                    "link": "HubState.openSettings(" in whole})
    # a card with its own heading (About's "This PC"): found by its name, its page opens
    for m in re.finditer(r'(?<![\w.])Card\s*\{', src):
        whole, own = block(src, m.end())
        t = re.search(r'\btitle:\s*' + STR + r'(?!\s*[+?])', own)
        if not t:
            continue
        i = re.search(r'\bicon:\s*' + STR, own)
        v = re.search(r'\bvisible:\s*([^\n;]*)', own)
        out.append({"file": page, "title": t.group(1), "desc": "", "icon": i.group(1) if i else "tune",
                    "only": only(v.group(1)) if v else "", "link": False})
    for m in re.finditer(r'\bSectionHead\s*\{', src):
        whole, own = block(src, m.end())
        t = re.search(r'\btext:\s*' + STR, own)
        if not t:
            continue
        v = re.search(r'\bvisible:\s*([^\n;]*)', own)
        out.append({"file": page, "title": t.group(1), "desc": "", "icon": "segment",
                    "only": only(v.group(1)) if v else "", "link": False})
json.dump(out, sys.stdout)
