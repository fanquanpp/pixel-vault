# -*- coding: utf-8 -*-
"""Emit Aseprite-importable GIMP .gpl palettes:
   one 64-colour master board + one sub-board per category.
"""
import json
import os
import sys
from collections import Counter


def hex2rgb(h):
    return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)


def write_gpl(path, name, colors):
    lines = ["GIMP Palette", "Name: " + name, "Columns: 8", "#"]
    for h, label in colors:
        r, g, b = hex2rgb(h)
        lines.append("%3d %3d %3d\t%-22s %s" % (r, g, b, h, label))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return len(colors)


NATURAL = [
    ("#23402A", "leaf-dark"), ("#3F6B3A", "leaf-mid"), ("#6FA34A", "leaf-light"), ("#A8CF6A", "leaf-hi"),
    ("#4A3528", "stem-dark"), ("#7A5A38", "stem-mid"), ("#B88952", "stem-light"), ("#D9B87A", "stem-hi"),
    ("#2E221C", "soil-dark"), ("#5A3F2C", "soil-mid"), ("#8C6440", "soil-light"), ("#B88952", "soil-hi"),
    ("#3E414A", "stone-dark"), ("#6E7380", "stone-mid"), ("#AEB3BD", "stone-light"), ("#D9DCE3", "stone-hi"),
    ("#1E3F5C", "water-dark"), ("#2E6F96", "water-mid"), ("#6FB6D1", "water-light"), ("#B8E3F2", "water-hi"),
    ("#1A1A20", "neutral-dark/shadow"), ("#8A8F98", "neutral-mid"), ("#E8D9B8", "neutral-light"), ("#F6F2E6", "neutral-hi"),
    ("#C75B1A", "gold-dark"), ("#F2C14E", "gold-mid"), ("#FFD84D", "gold-light"), ("#FFF3B0", "gold-hi"),
]


def main():
    spec_path, meta_dir = sys.argv[1], sys.argv[2]
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
    items = spec["items"]

    freq = Counter()
    label_of = {}
    for it in items:
        for k in ("main", "accent", "dot"):
            freq[it[k]] += 1
            label_of.setdefault(it[k], it["slug"] + ":" + k)

    master = list(NATURAL)
    used = {h for h, _ in master}
    for h, _ in freq.most_common():
        if len(master) >= 64:
            break
        if h not in used:
            master.append((h, label_of[h]))
            used.add(h)

    n = write_gpl(os.path.join(meta_dir, "pixel-plants-master.gpl"),
                  "pixel-plants master (64)", master)
    print("master.gpl colors =", n)

    total = 0
    for cat in spec["categories"]:
        cs = [it for it in items if it["category"] == cat["id"]]
        seen = {}
        for it in cs:
            for k in ("main", "accent", "dot"):
                seen.setdefault(it[k], it["slug"] + ":" + k)
        cols = NATURAL + [(h, seen[h]) for h in sorted(seen, key=lambda x: -freq[x])]
        p = os.path.join(meta_dir, "pixel-plants-%s.gpl" % cat["id"])
        c = write_gpl(p, "pixel-plants %s" % cat["id"], cols)
        total += c
        print("  %-10s %3d colors -> %s" % (cat["id"], c, os.path.basename(p)))
    print("sub-board total =", total)


if __name__ == "__main__":
    main()
