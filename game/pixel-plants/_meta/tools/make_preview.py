# -*- coding: utf-8 -*-
"""Build the pixel-plants preview contact sheet (all tiles, grouped by category,
labelled with the Chinese name, integer-upscaled with NEAREST so pixels stay hard)."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = r"C:\Users\fanqu\.aseprite-mcp\fonts\fusion-pixel-12px-proportional-zh_hans.otf"
BG = (26, 28, 44, 255)
PANEL = (38, 40, 58, 255)
LINE = (70, 74, 100, 255)
INK = (222, 226, 240, 255)
DIM = (150, 156, 180, 255)
ACCENT = (254, 231, 97, 255)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


def main():
    spec_path, pack, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)

    cols = 16
    content = 56
    pad = 5
    cell = content + pad * 2
    lab_h = 26
    f_title = font(22)
    f_hd = font(15)
    f_name = font(11)
    f_slug = font(9)

    cats = []
    for c in spec["categories"]:
        cats.append((c["nameZh"], [it for it in spec["items"] if it["category"] == c["id"]]))

    W = cols * cell + pad * 2
    # plan heights
    rows_plan = [(zh, items, (len(items) + cols - 1) // cols) for zh, items in cats]
    H = 74
    for _, _, r in rows_plan:
        H += 30 + r * (cell + lab_h) + 10
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)

    d.text((pad + 4, 16), "像素植物素材总览  pixel-plants", font=f_title, fill=INK)
    d.text((pad + 4, 46), "共 %d 枚植物瓦片 + 12 组摇曳动画帧条 · 16x16 / 32x32 · 透明背景 PNG · MIT"
           % len(spec["items"]), font=f_hd, fill=DIM)

    y = 74
    for zh, items, rn in rows_plan:
        d.rectangle([pad, y, W - pad - 1, y + 24], fill=PANEL)
        d.text((pad + 6, y + 4), "%s  ·  %d 枚" % (zh, len(items)), font=f_hd, fill=ACCENT)
        y += 30
        for i, it in enumerate(items):
            col = i % cols
            row = i // cols
            cx = pad + col * cell
            cy = y + row * (cell + lab_h)
            d.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], fill=PANEL)
            p = os.path.join(pack, it["slug"] + ".png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGBA")
                s = content // max(im.width, im.height)
                s = max(1, s)
                im2 = im.resize((im.width * s, im.height * s), Image.NEAREST)
                sheet.alpha_composite(im2, (cx + (cell - im2.width) // 2,
                                            cy + (cell - im2.height) // 2))
            else:
                d.rectangle([cx + 4, cy + 4, cx + cell - 5, cy + cell - 5], outline=(200, 60, 60, 255))
                d.text((cx + 6, cy + 20), "MISSING", font=f_slug, fill=(255, 90, 90, 255))
            d.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=LINE)
            name = it["nameZh"]
            if len(name) > 9:
                name = name[:8] + "…"
            d.text((cx + 3, cy + cell + 1), name, font=f_name, fill=INK)
            d.text((cx + 3, cy + cell + 14), it["slug"], font=f_slug, fill=DIM)
        y += rn * (cell + lab_h) + 10

    sheet.save(out_path)
    print("preview:", out_path, sheet.size, "categories:", len(cats))


if __name__ == "__main__":
    main()
