# -*- coding: utf-8 -*-
"""Final AutoCoder verification pass over the shipped pixel-plants pack."""
import glob
import io
import json
import os
from collections import Counter

from PIL import Image

REPO = r"C:\Atian\Project\pixel-vault"
PACK = os.path.join(REPO, "game", "pixel-plants")
SHADOW_ALPHA_OK = {0, 76, 255}

spec = json.load(io.open(os.path.join(PACK, "_meta", "tools", "plant_spec.json"), encoding="utf-8"))
man = json.load(io.open(os.path.join(PACK, "assets.manifest.json"), encoding="utf-8"))
canvas = {it["slug"]: it["canvas"] for it in spec["items"]}

fails = []
notes = []

# 1) inventory / stray files
top = os.listdir(PACK)
exts = Counter(os.path.splitext(f)[1].lower() for f in top if os.path.isfile(os.path.join(PACK, f)))
tiles_png = [f for f in top if f.endswith(".png") and not f.endswith("_strip.png")]
tiles_ase = [f for f in top if f.endswith(".aseprite") and not f.endswith("-sway.aseprite")]
strips = [f for f in top if f.endswith("_strip.png")]
sway_ase = [f for f in top if f.endswith("-sway.aseprite")]
print("inventory: tiles_png=%d tiles_aseprite=%d strips=%d sway_aseprite=%d"
      % (len(tiles_png), len(tiles_ase), len(strips), len(sway_ase)))
print("top-level extensions:", dict(exts))
if len(tiles_png) != 169 or len(tiles_ase) != 169 or len(strips) != 12 or len(sway_ase) != 12:
    fails.append("inventory count mismatch")

# 2) duplicate slugs (case-insensitive) and coverage vs spec
slugs = [os.path.splitext(f)[0] for f in tiles_png]
dup = [s for s, c in Counter(x.lower() for x in slugs).items() if c > 1]
if dup:
    fails.append("duplicate slug(s): %s" % dup)
missing = sorted(set(canvas) - set(slugs))
extra = sorted(set(slugs) - set(canvas))
print("spec slugs=%d png slugs=%d | missing=%d extra=%d" % (len(canvas), len(slugs), len(missing), len(extra)))
if missing:
    fails.append("missing tiles: %s" % missing[:5])
if extra:
    fails.append("extra tiles: %s" % extra[:5])

# 3) per-tile pixel checks
alpha_sets, color_counts = Counter(), Counter()
for f in sorted(tiles_png):
    s = os.path.splitext(f)[0]
    im = Image.open(os.path.join(PACK, f)).convert("RGBA")
    if im.size != (canvas[s], canvas[s]):
        fails.append("size mismatch %s: %s != %dx%d" % (f, im.size, canvas[s], canvas[s]))
        continue
    px = list(im.getdata())
    alphas = {a for *_, a in px}
    if not alphas <= SHADOW_ALPHA_OK:
        fails.append("unexpected alpha values in %s: %s" % (f, sorted(alphas - SHADOW_ALPHA_OK)))
    alpha_sets[tuple(sorted(alphas))] += 1
    if 0 not in alphas:
        fails.append("no transparent background in %s" % f)
    if 255 not in alphas:
        fails.append("no opaque pixels in %s" % f)
    for r, g, b, a in px:
        if a == 76 and (r, g, b) != (26, 26, 32):
            fails.append("semi-transparent non-shadow pixel in %s" % f)
            break
    n = len({(r, g, b) for r, g, b, a in px if a == 255})
    color_counts[n] += 1
    if not (3 <= n <= 8):
        notes.append("color count %d in %s" % (n, f))
print("alpha value sets seen:", {",".join(map(str, k)): v for k, v in alpha_sets.items()})
print("opaque colour counts:", dict(sorted(color_counts.items())))

# 4) strips are exactly 4 frames wide
for f in sorted(strips):
    base = f[: -len("-sway_strip.png")]
    c = canvas.get(base)
    im = Image.open(os.path.join(PACK, f))
    if c is None or im.size != (c * 4, c):
        fails.append("strip geometry wrong %s: %s expected %s" % (f, im.size, (c * 4 if c else "?", c)))
print("strips checked:", len(strips))

# 5) manifest reconciliation + dimensions
disk_png = set()
for p in glob.glob(os.path.join(PACK, "**", "*.png"), recursive=True):
    disk_png.add(os.path.relpath(p, PACK).replace("\\", "/"))
man_png = {e["path"] for e in man["items"]}
print("disk png=%d manifest entries=%d" % (len(disk_png), len(man_png)))
if disk_png - man_png:
    fails.append("orphan files on disk: %s" % sorted(disk_png - man_png)[:5])
if man_png - disk_png:
    fails.append("manifest points at missing files: %s" % sorted(man_png - disk_png)[:5])
dim_mismatch = 0
for e in man["items"]:
    fp = os.path.join(PACK, *e["path"].split("/"))
    if not os.path.exists(fp):
        continue
    if e["path"].endswith(".png"):
        with Image.open(fp) as im:
            if e.get("w") and (im.size != (e["w"], e["h"])):
                dim_mismatch += 1
                fails.append("manifest w/h mismatch %s" % e["path"])
print("manifest dimension mismatches:", dim_mismatch)

# 6) site manifest
site = json.load(io.open(os.path.join(REPO, "manifest.json"), encoding="utf-8"))
pl = [a for a in site["assets"] if a["path"].startswith("game/pixel-plants/")]
print("site manifest: total=%d sourceCount=%d counts.game=%d plants=%d sum(counts)=%d sum(bytes)=%d totalBytes=%d"
      % (site["total"], site["sourceCount"], site["counts"]["game"], len(pl),
         sum(site["counts"].values()), sum(a["bytes"] for a in site["assets"]), site["totalBytes"]))
if site["total"] != 559 or site["sourceCount"] != 413 or len(pl) != 181:
    fails.append("site manifest numbers unexpected")
if "game/pixel-plants" not in [s["id"] for s in site["subs"]["game"]]:
    fails.append("site subs missing pixel-plants")

print()
print("FAILURES:", len(fails))
for f in fails[:20]:
    print("  -", f)
print("NOTES (soft):", len(notes))
for n in notes[:10]:
    print("  -", n)
print("RESULT:", "PASS" if not fails else "FAIL")
