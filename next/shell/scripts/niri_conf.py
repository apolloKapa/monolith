#!/usr/bin/env python3
"""Change one setting in a niri config file, leaving the rest of the file (comments, order,
everything you wrote) as it is. niri reloads the file by itself.

    niri_conf.py set  FILE BLOCK KEY VALUE...   set `KEY VALUE...` inside BLOCK (added if missing)
    niri_conf.py flag FILE BLOCK KEY on|off     a line that is just `KEY` (like `off`, `tap`)
    niri_conf.py get  FILE BLOCK KEY            print the value, nothing if unset

    niri_conf.py json FILE BLOCK|KEY...         several values as JSON (null = unset, "" = a bare flag)

BLOCK is a path of node headers split by '/', e.g. 'input/mouse' or 'output "DP-1"'; '-' is the
top level. Values are written as given: quote strings yourself ('"us,gr"').
FILE can be niri's config folder (~/.config/niri): then the file that already has the block is
used (config.kdl or one it includes from config/), else config.kdl.
"""
import glob
import json
import os
import re
import sys


def strip_comment(line):
    out, in_str, i = [], False, 0
    while i < len(line):
        ch = line[i]
        if ch == '"' and (i == 0 or line[i - 1] != "\\"):
            in_str = not in_str
        if not in_str and line.startswith("//", i):
            break
        out.append(ch)
        i += 1
    return "".join(out)


def find_block(lines, path, start=0, end=None, depth_indent=""):
    """Return (open_line, close_line) of the block at `path` inside lines[start:end]."""
    end = len(lines) if end is None else end
    head, rest = path[0], path[1:]
    pat = re.compile(r"^\s*" + re.escape(head) + r"\s*\{\s*$")
    depth = 0
    i = start
    while i < end:
        code = strip_comment(lines[i])
        if depth == 0 and pat.match(code):
            # find its closing brace
            d, j = 0, i
            while j < end:
                c = strip_comment(lines[j])
                d += c.count("{") - c.count("}")
                if d == 0:
                    break
                j += 1
            if not rest:
                return i, j
            return find_block(lines, rest, i + 1, j)
        depth += code.count("{") - code.count("}")
        i += 1
    return None


def ensure_block(lines, path):
    """Find the block, creating it (and its parents) when missing."""
    for n in range(1, len(path) + 1):
        if find_block(lines, path[:n]) is None:
            if n == 1:
                if lines and lines[-1].strip():
                    lines.append("")
                lines += [path[0] + " {", "}"]
            else:
                o, c = find_block(lines, path[: n - 1])
                ind = indent_of(lines, o)
                lines[c:c] = [ind + path[n - 1] + " {", ind + "}"]
    return find_block(lines, path)


def key_line(lines, o, c, key):
    pat = re.compile(r"^\s*" + re.escape(key) + r"(\s|$)")
    d = 0
    for i in range(o + 1, c):
        code = strip_comment(lines[i])
        if d == 0 and pat.match(code):
            return i
        d += code.count("{") - code.count("}")
    return None


def indent_of(lines, o):
    if o < 0:
        return ""
    return re.match(r"^\s*", lines[o]).group(0) + "    "


def read_lines(file):
    try:
        with open(file) as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def block_of(lines, path):
    if not path:
        return -1, len(lines)
    return find_block(lines, path)


def pick_file(target, path, key=None):
    """A folder: the file that has the block's top node (or, at the top level, the key),
    else config.kdl."""
    if not os.path.isdir(target):
        return target
    main = os.path.join(target, "config.kdl")
    files = [main] + sorted(glob.glob(os.path.join(target, "config", "*.kdl")))
    if path:
        for f in files:
            if find_block(read_lines(f), path[:1]):
                return f
    elif key:
        for f in files:
            ls = read_lines(f)
            if key_line(ls, -1, len(ls), key) is not None:
                return f
    return main


def value_of(lines, path, key):
    b = block_of(lines, path)
    if not b:
        return None
    k = key_line(lines, *b, key)
    if k is None:
        return None
    return strip_comment(lines[k]).strip()[len(key):].strip()


def main():
    cmd, target = sys.argv[1:3]
    if cmd == "json":
        out = {}
        for spec in sys.argv[3:]:
            block, key = spec.split("|", 1)
            path = [p for p in block.split("/") if p and p != "-"]
            out[spec] = value_of(read_lines(pick_file(target, path, key)), path, key)
        print(json.dumps(out))
        return
    block, key = sys.argv[3:5]
    args = sys.argv[5:]
    path = [p for p in block.split("/") if p and p != "-"]
    file = pick_file(target, path, key)
    lines = read_lines(file)

    if cmd == "get":
        v = value_of(lines, path, key)
        if v is not None:
            print(v)
        return

    o, c = ensure_block(lines, path) if path else (-1, len(lines))
    k = key_line(lines, o, c, key)
    if cmd == "set":
        new = indent_of(lines, o) + key + " " + " ".join(args)
        if k is None:
            lines.insert(c, new)
        else:
            lines[k] = new
    elif cmd == "flag":
        on = args and args[0] == "on"
        if on and k is None:
            lines.insert(c, indent_of(lines, o) + key)
        elif not on and k is not None:
            del lines[k]
    else:
        sys.exit("unknown command " + cmd)

    with open(file, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
