#!/usr/bin/env python3
"""Turns a Portage binary-package folder into what goes on the `binhost` release: every package
as one flat file (a release can't have folders: app-misc/jq/jq-1.8.2-1.gpkg.tar becomes
app-misc--jq--jq-1.8.2-1.gpkg.tar) and Portage's index, Packages, with each entry's PATH pointing
at its flat file. Portage fetches <sync-uri>/<PATH>, so the release's download URL works as a
binhost as it is.

    publish.py PKGDIR OUT       (run `emaint binhost --fix` with that PKGDIR first: a fresh index)
    publish.py --unflatten DIR PKGDIR    the release's files back into a Portage PKGDIR (the next
                                         build starts from what's published)
"""
import os
import shutil
import sys


def flat(path):
    return path.replace("/", "--")


def entries(text):
    """the index's header and its package entries, each a list of 'KEY: value' lines"""
    blocks = [b.strip("\n").split("\n") for b in text.split("\n\n") if b.strip()]
    return blocks[0], blocks[1:]


def field(block, key):
    for line in block:
        if line.startswith(key + ": "):
            return line[len(key) + 2:]
    return None


def publish(pkgdir, out):
    os.makedirs(out, exist_ok=True)
    head, pkgs = entries(open(os.path.join(pkgdir, "Packages"), encoding="utf-8").read())
    kept = []
    for b in pkgs:
        path = field(b, "PATH")
        if not path:
            cpv = field(b, "CPV")
            bid = field(b, "BUILD_ID")
            cat, pf = cpv.split("/", 1)
            pn = pf.rsplit("-", 2)[0] if pf.count("-") >= 2 and pf.rsplit("-", 1)[1].startswith("r") else pf.rsplit("-", 1)[0]
            path = f"{cat}/{pn}/{pf}-{bid}.gpkg.tar" if bid else f"{cat}/{pf}.tbz2"
        src = os.path.join(pkgdir, path)
        if not os.path.isfile(src):
            continue
        shutil.copy2(src, os.path.join(out, flat(path)))
        b = [l for l in b if not l.startswith("PATH: ")] + ["PATH: " + flat(path)]
        kept.append(b)
    head = [l for l in head if not l.startswith("PACKAGES: ")] + [f"PACKAGES: {len(kept)}"]
    with open(os.path.join(out, "Packages"), "w", encoding="utf-8") as f:
        f.write("\n".join(head) + "\n\n" + "\n\n".join("\n".join(b) for b in kept) + "\n")
    print(f"published {len(kept)} packages to {out}")


def unflatten(src, pkgdir):
    n = 0
    for name in os.listdir(src):
        if not (name.endswith(".gpkg.tar") or name.endswith(".tbz2")) or "--" not in name:
            continue
        dest = os.path.join(pkgdir, name.replace("--", "/"))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(os.path.join(src, name), dest)
        n += 1
    print(f"restored {n} packages into {pkgdir}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--unflatten":
        unflatten(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 3:
        publish(sys.argv[1], sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)
