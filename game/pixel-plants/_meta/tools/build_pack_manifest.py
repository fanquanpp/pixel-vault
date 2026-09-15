# -*- coding: utf-8 -*-
"""Build game/pixel-plants/assets.manifest.json from spec.json + on-disk files."""
import json
import os
import sys

PACK_REL = "game/pixel-plants"
ANIM = {"ling-lan": 1, "yue-jian-cao": 1, "yang-gan-ju": 1, "man-zhu-sha-hua": 1,
        "xun-yi-cao": 1, "jiang-li": 1, "mi-die-xiang": 1, "ren-dong": 1,
        "pu-ti-shu": 1, "sheng-shi-hua": 1, "fo-zhu": 1, "xuan-cao": 1}
FRAME_MS = 150


def main():
    spec_path, repo = sys.argv[1], sys.argv[2]
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
    pack = os.path.join(repo, "game", "pixel-plants")
    pal = spec["palette"]

    def entry(path_rel, kind, w, h, frames, **extra):
        full = os.path.join(repo, *path_rel.split("/"))
        ok = os.path.exists(full)
        rel = path_rel[len("game/pixel-plants/"):]
        rec = {
            "name": os.path.splitext(os.path.basename(path_rel))[0],
            "kind": kind, "path": rel, "repoPath": path_rel, "w": w, "h": h, "frames": frames,
            "fps": round(1000.0 / FRAME_MS, 2) if frames > 1 else None,
            "loop": "pingpong" if frames > 1 else None,
            "status": "ok" if ok else "missing-file",
            "bytes": os.path.getsize(full) if ok else None,
        }
        rec.update(extra)
        return rec

    items = []
    for it in spec["items"]:
        slug = it["slug"]
        rec = entry("game/pixel-plants/%s.png" % slug, "tile", it["canvas"], it["canvas"], 1,
                    nameZh=it["nameZh"], category=it["category"],
                    categoryNameZh=it["categoryNameZh"], archetype=it["archetype"],
                    palette={"main": it["main"], "accent": it["accent"], "dot": it["dot"],
                             "leafLight": pal["leafLight"], "leafDark": pal["leafDark"],
                             "shadow": pal["shadow"], "glint": pal["glint"]},
                    source="game/pixel-plants/%s.aseprite" % slug,
                    baseIndex=it["baseIndex"], variantOf=it["variantOf"],
                    variantLabel=it["variantLabel"])
        items.append(rec)
        if slug in ANIM:
            items.append(entry("game/pixel-plants/%s-sway_strip.png" % slug, "strip",
                               it["canvas"] * 4, it["canvas"], 4,
                               nameZh=it["nameZh"] + "（摇曳）", category=it["category"],
                               categoryNameZh=it["categoryNameZh"], archetype=it["archetype"],
                               palette=rec["palette"],
                               source="game/pixel-plants/%s-sway.aseprite" % slug,
                               baseIndex=it["baseIndex"], variantOf=it["variantOf"],
                               variantLabel=it["variantLabel"]))

    missing = [r["path"] for r in items if r["status"] != "ok"]
    pv = "game/pixel-plants/_meta/preview.png"
    from PIL import Image as _I
    with _I.open(os.path.join(pack, "_meta", "preview.png")) as _im:
        pw, ph = _im.size
    items.append({
        "name": "preview", "kind": "preview", "path": "_meta/preview.png",
        "repoPath": pv, "w": pw, "h": ph,
        "frames": 1, "fps": None, "loop": None, "status": "ok",
        "bytes": os.path.getsize(os.path.join(pack, "_meta", "preview.png")),
        "nameZh": "全量预览接触表", "category": None, "categoryNameZh": None,
        "archetype": None, "palette": None, "source": None,
        "baseIndex": None, "variantOf": None, "variantLabel": None,
    })
    for extra in ("preview.png", "pixel-plants-master.gpl"):
        fp = os.path.join(pack, "_meta", extra)
        if not os.path.exists(fp):
            missing.append("game/pixel-plants/_meta/" + extra)

    doc = {
        "generated": "2026-09-15",
        "pack": PACK_REL,
        "sourceTxt": "pasted_text_20260915-060046.txt",
        "license": "MIT",
        "palette": pal,
        "counts": {
            "base": spec["baseCount"], "variants": spec["variantCount"],
            "tiles": spec["baseCount"] + spec["variantCount"],
            "animated": len(ANIM), "entries": len(items),
            "asepriteSources": len(spec["items"]) + len(ANIM),
        },
        "animation": {"frames": 4, "frameMs": FRAME_MS, "loop": "pingpong",
                      "tag": "sway", "fps": round(1000.0 / FRAME_MS, 2)},
        "paletteFiles": ["game/pixel-plants/_meta/pixel-plants-master.gpl"] +
                        ["game/pixel-plants/_meta/pixel-plants-%s.gpl" % c["id"]
                         for c in spec["categories"]],
        "docs": ["game/pixel-plants/_meta/README.md", "game/pixel-plants/_meta/ISSUES.md",
                 "game/pixel-plants/_meta/INTEGRATION.md", "game/pixel-plants/_meta/ROLLBACK.md"],
        "missing": missing,
        "items": items,
    }
    out = os.path.join(pack, "assets.manifest.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("manifest:", out)
    print("entries:", len(items), "| missing:", len(missing))
    print("tiles:", doc["counts"]["tiles"], "| strips:", len(ANIM),
          "| sources:", doc["counts"]["asepriteSources"])


if __name__ == "__main__":
    main()
