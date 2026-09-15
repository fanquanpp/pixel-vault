# -*- coding: utf-8 -*-
"""Apply the documented site-integration text edits for the new pixel-plants pack.

Every anchor must match exactly once; the script aborts otherwise so a partial
or duplicated edit can never happen. Idempotent: re-running is a no-op.
"""
import io
import os
import sys

REPO = sys.argv[1] if len(sys.argv) > 1 else r"C:\Atian\Project\pixel-vault"


def read(p):
    with io.open(p, encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def sub_once(text, old, new, label, done_marker=None):
    if done_marker and done_marker in text:
        print("  skip (already applied):", label)
        return text
    n = text.count(old)
    if n != 1:
        raise SystemExit("ANCHOR FAIL [%s]: expected 1 match, found %d" % (label, n))
    print("  applied:", label)
    return text.replace(old, new, 1)


changed = []

# ---------------------------------------------------------------- app.js
appjs = os.path.join(REPO, "app.js")
s = read(appjs)
s = sub_once(
    s,
    '  "game/pixel-anim": "动画帧条",\n',
    '  "game/pixel-anim": "动画帧条",\n  "game/pixel-plants": "像素植物",\n',
    "app.js SUB_LABELS",
    done_marker='"game/pixel-plants"',
)
write(appjs, s)
changed.append("app.js")

# ---------------------------------------------------------------- README.md
readme = os.path.join(REPO, "README.md")
s = read(readme)
s = sub_once(s, "badge/%E5%8F%AF%E8%A7%81%E7%B4%A0%E6%9D%90-378-fee761.svg",
             "badge/%E5%8F%AF%E8%A7%81%E7%B4%A0%E6%9D%90-559-fee761.svg", "README assets badge")
s = sub_once(s, "badge/Aseprite_%E6%BA%90%E6%96%87%E4%BB%B6-232-2ce8f5.svg",
             "badge/Aseprite_%E6%BA%90%E6%96%87%E4%BB%B6-413-2ce8f5.svg", "README sources badge")
s = sub_once(
    s,
    "| `game/pixel-anim/` | 动画帧条：水流/火焰/风/落叶/枯萎/奔跑/烟雾/星光 Animated strips | 8 组 |\n",
    "| `game/pixel-anim/` | 动画帧条：水流/火焰/风/落叶/枯萎/奔跑/烟雾/星光 Animated strips | 8 组 |\n"
    "| `game/pixel-plants/` | 植物像素素材：169 枚瓦片（16×16 花草本草 / 32×32 树木）+ 12 组摇曳帧条 Plant tiles | 181 |\n",
    "README content table row",
    done_marker="`game/pixel-plants/`",
)
write(readme, s)
changed.append("README.md")

# ---------------------------------------------------------------- CONTENT.md
content = os.path.join(REPO, "CONTENT.md")
s = read(content)
s = sub_once(s, "（378 件可见素材 / 232 个 Aseprite 源）",
             "（559 件可见素材 / 413 个 Aseprite 源）", "CONTENT header counts")
s = sub_once(
    s,
    "| game/pixel-anim/ | 16×16（落叶 32×32），4-8 帧横向帧条 | .aseprite（多帧）+ _strip.png | 8 组 |\n",
    "| game/pixel-anim/ | 16×16（落叶 32×32），4-8 帧横向帧条 | .aseprite（多帧）+ _strip.png | 8 组 |\n"
    "| game/pixel-plants/ | 16×16（树木 32×32），169 瓦片 + 12 组 4 帧帧条 | .aseprite（7 层）+ .png / _strip.png | 181 |\n",
    "CONTENT overview table row",
    done_marker="game/pixel-plants/ |",
)

SECTION = """### pixel-plants（植物像素素材）
169 枚植物瓦片 + 12 组摇曳动画帧条，按「古典仙气 / 浪漫花语 / 本草清雅 / 树木佛意 / 野趣多肉」五类组织；文件名用拼音 kebab-case（如 `juan-er`、`man-zhu-sha-hua`），中文名与逐条来源见 `game/pixel-plants/_meta/slug-map.md`。
- 画布：小花草本 16×16，树木 32×32；导出为透明背景 PNG，硬边无抗锯齿
- 图层：每枚源文件统一 7 层，自下而上 `shadow / stem / leaf / bloom / bloom-shade / core / glint`，可继续编辑
- 调色板：主色/辅色/点色按清单逐条给定，叶茎复用通用自然色板；单枚瓦片不透明颜色数控制在 4-7
- 变体：同形换色（只替换主/辅/点色，叶茎不变），共 39 枚变体瓦片
- 动画：`<slug>-sway_strip.png` 为 4 帧横向帧条（帧宽等于画布宽），150ms/帧、pingpong 循环，源文件内打 `sway` 标签
- 清单与文档：`game/pixel-plants/assets.manifest.json`（逐项名称/类别/尺寸/帧数/调色板/路径/状态/来源条目）；`game/pixel-plants/_meta/` 含预览接触表、`.gpl` 调色板（64 色主板 + 5 个子板）、命名映射与再生成脚本

"""
s = sub_once(s, "### speed-rouge（完整平台跳跃项目素材）",
             SECTION + "### speed-rouge（完整平台跳跃项目素材）",
             "CONTENT pixel-plants section",
             done_marker="### pixel-plants（植物像素素材）")
write(content, s)
changed.append("CONTENT.md")

print("changed:", ", ".join(changed))
