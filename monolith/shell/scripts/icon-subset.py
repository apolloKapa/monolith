#!/usr/bin/env python3
"""Monolith Symbols: the Material Symbols icons the shell uses, in a font of their own.

The full Material Symbols font (every icon, four variable axes) took about 40 MB of the shell's
memory. This keeps only the icons named anywhere in the shell's code (as a quoted word), each with
its filled form, and fixes the axes the shell never changes (weight 400, grade 0); the filled
switch (FILL) and the optical size (opsz) stay. Writes, beside the shell:

  fonts/MonolithSymbols-Rounded.ttf, fonts/MonolithSymbols-Sharp.ttf   (families "Monolith Symbols …")
  core/iconnames.js   the names in them: an icon not among them is drawn with the full font
                      (ui/Icon.qml), so one missed here still shows

Run it again after adding icons (needs fontTools: pip install fonttools). Usage:
  icon-subset.py [folder with MaterialSymbolsRounded.ttf and MaterialSymbolsSharp.ttf]
"""
import json
import os
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.dirname(HERE)
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/fonts/material-symbols")


def ligatures(font):
    """{icon name: glyph}"""
    order = {"underscore": "_"}
    for d, w in enumerate(["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]):
        order["digit_" + w] = str(d)
    out = {}
    for lk in font["GSUB"].table.LookupList.Lookup:
        for st in lk.SubTable:
            t = st.ExtSubTable if lk.LookupType == 7 else st
            for first, ligs in getattr(t, "ligatures", {}).items():
                for L in ligs:
                    name = "".join(order.get(g, g) for g in [first] + list(L.Component))
                    out[name] = L.LigGlyph
    return out


def words_in_shell():
    """every quoted lower-case word in the shell's code (QML, JS)"""
    words = set()
    for root, dirs, files in os.walk(SHELL):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.endswith((".qml", ".js", ".mjs")) and f != "iconnames.js":
                with open(os.path.join(root, f), encoding="utf-8", errors="replace") as fh:
                    words.update(re.findall(r"""["'`]([a-z0-9_]{2,})["'`]""", fh.read()))
    return words


def build(style, words):
    path = os.path.join(SRC, f"MaterialSymbols{style}.ttf")
    font = TTFont(path)
    ligs = ligatures(font)
    names = sorted(w for w in words if w in ligs)
    glyphs = set()
    for n in names:
        g = ligs[n]
        glyphs.add(g)
        if g + ".fill" in font.getGlyphOrder():
            glyphs.add(g + ".fill")
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.layout_closure = False           # only the ligatures whose icon is kept
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.glyph_names = True
    opts.drop_tables += ["DSIG"]
    sub = subset.Subsetter(opts)
    text = "abcdefghijklmnopqrstuvwxyz0123456789_"
    sub.populate(text=text, glyphs=sorted(glyphs))
    sub.subset(font)
    # then the axes the shell never moves fixed (in this order: fixed first, the subsetter lost the
    # letters' entries)
    font = instancer.instantiateVariableFont(font, {"wght": 400, "GRAD": 0})
    # its own family, so it never stands in for the full font in other apps
    family = f"Monolith Symbols {style}"
    for rec in font["name"].names:
        if rec.nameID in (1, 16):
            rec.string = family
        elif rec.nameID in (4,):
            rec.string = family
        elif rec.nameID in (6,):
            rec.string = family.replace(" ", "") + "-Regular"
    os.makedirs(os.path.join(SHELL, "fonts"), exist_ok=True)
    out = os.path.join(SHELL, "fonts", f"MonolithSymbols-{style}.ttf")
    font.save(out)
    print(f"{style}: {len(names)} icons, {os.path.getsize(out) // 1024} KB (from {os.path.getsize(path) // 1024} KB)")
    return names


def main():
    words = words_in_shell()
    rounded = build("Rounded", words)
    sharp = build("Sharp", words)
    common = sorted(set(rounded) & set(sharp))
    with open(os.path.join(SHELL, "core", "iconnames.js"), "w", encoding="utf-8") as f:
        f.write("// Written by scripts/icon-subset.py: the icons in Monolith Symbols (fonts/). An icon not\n"
                "// here is drawn with the full Material Symbols font (ui/Icon.qml).\n.pragma library\n"
                "var names = " + json.dumps({n: 1 for n in common}, separators=(",", ":")) + ";\n")
    print(f"core/iconnames.js: {len(common)} names")


if __name__ == "__main__":
    main()
