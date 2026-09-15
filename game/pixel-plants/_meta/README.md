# game/pixel-plants — 植物像素素材包（交接文档）

本目录是 Pixel Vault 的植物素材包，按需求文本（`pasted_text_20260915-060046.txt`）中的
130 条色彩规格生成。全部素材为程序化逐像素绘制，可完全复现。

## 1. 目录结构

```
game/pixel-plants/
  <slug>.aseprite          169  瓦片源文件（多图层，可继续编辑）
  <slug>.png               169  瓦片导出图（RGBA，透明背景）
  <slug>-sway.aseprite      12  摇曳动画源文件（4 帧 + sway 标签）
  <slug>-sway_strip.png     12  摇曳动画横向帧条
  assets.manifest.json         本包清单（逐项记录，含校验用 w/h）
  _meta/
    README.md                  本文件：命名规则、目录结构、调色板、导出参数、再生成步骤
    ISSUES.md                  规格缺口与异常处理记录
    INTEGRATION.md             站点接入验证记录
    ROLLBACK.md                备份与回滚说明
    slug-map.md                编号 / 中文名 / slug / 类别 / 画布 / 原型 对照表
    preview.png                全量预览接触表（含中文名称标注）
    pixel-plants-master.gpl    64 色主板（Aseprite 可直接导入）
    pixel-plants-<cat>.gpl     5 个分类子板（classical / romance / herbal / trees / succulent）
    tools/                     再生成与校验脚本（见 tools/README.md）
```

## 2. 数量

| 项目 | 数量 |
|---|---|
| 基础瓦片（txt 130 条） | 130 |
| 变体瓦片（同形换色） | 39 |
| 瓦片合计 | 169 |
| 摇曳动画帧条 | 12 |
| 可见素材（.png，计入站点 manifest） | 181 |
| Aseprite 源文件（.aseprite） | 181 |

分类分布：古典仙气 15、浪漫花语 78、本草清雅 41、树木佛意 17、野趣多肉 18（含变体）。

## 3. 命名规则

- 文件名：小写 ASCII，拼音 kebab-case，如 `juan-er`、`man-zhu-sha-hua`、`xue-jian-cao`。
- 变体瓦片：`<base-slug>-<变体色拼音>`，如 `fu-sang-fen`、`xue-jian-cao`。
  变体色拼音对照：粉=fen 白=bai 黄=huang 蓝=lan 红=hong 紫=zi 黄绿=huang-lv。
- 动画：源文件 `<slug>-sway.aseprite`，帧条 `<slug>-sway_strip.png`
  （`_strip.png` 后缀沿用本仓库 `game/pixel-anim` 既有约定）。
- 中文名、来源条目与 slug 的完整对照见 `slug-map.md`。

## 4. 画布与图层

| 类别 | 画布 |
|---|---|
| 古典仙气 / 浪漫花语 / 本草清雅 / 野趣多肉 | 16×16 |
| 树木佛意 | 32×32 |

每个源文件固定 7 个图层，自下而上：

| 层名 | 用途 |
|---|---|
| `shadow` | 地面阴影（图层不透明度 76/255 ≈ 30%） |
| `stem` | 茎 / 树干 / 枝条 |
| `leaf` | 叶 / 树冠 |
| `bloom` | 花/果主体（主色） |
| `bloom-shade` | 暗部与描边（辅色），位于主色之上 |
| `core` | 花蕊 / 果实高光（点色） |
| `glint` | 1–2 像素高光（#FFF3B0） |

## 5. 调色板

逐条素材使用 txt 指定的 主色 / 辅色 / 点色；叶、茎、树干复用通用自然色板：

| 用途 | 色值 |
|---|---|
| 叶亮部 | `#6FA34A` |
| 叶暗部（兼绿茎） | `#3F6B3A` |
| 树干 | `#7A5A38` |
| 树干暗部 | `#4A3528` |
| 阴影 | `#1A1A20`（图层 30% 不透明度，落在 txt 的 25%–40% 区间） |
| 高光 | `#FFF3B0` |
| 水面/水光（水生条目用） | `#2E6F96` / `#6FB6D1` |

单枚瓦片不透明颜色数控制在 4–7（实测 3–7），符合 txt「每株限制 4–6 色」的意图。
`pixel-plants-master.gpl` 为 64 色主板，5 个分类子板各自附带该分类用到的全部颜色。

## 6. 导出参数

| 参数 | 值 |
|---|---|
| 格式 | PNG |
| 色彩 | RGBA（独立 alpha 通道） |
| 背景 | 全透明（alpha=0） |
| 缩放 | 1×（与源文件同尺寸；帧条为 4 帧横向拼接） |
| 边缘 | 硬边无抗锯齿；唯一允许的半透明像素是阴影色 `#1A1A20`（alpha 76） |

## 7. 动画规格

- 帧数 4，帧时长 150ms，合计 600ms/循环，帧率 6.67fps。
- 循环方向 `pingpong`（`sway` 标签，帧 1–4）。
- 帧条尺寸：16×16 素材为 64×16，32×32 素材为 128×32。
- 逐帧位移：`bloom` / `core` / `glint` 横向 ±1px，`leaf` ±0.5px（取整 ±1/0），
  `shadow` 与 `stem` 不动，形成「花头轻摆」效果。
- 动画条目（12）：`ling-lan`、`yue-jian-cao`、`yang-gan-ju`、`man-zhu-sha-hua`、
  `xun-yi-cao`、`jiang-li`、`mi-die-xiang`、`ren-dong`、`pu-ti-shu`、`sheng-shi-hua`、
  `fo-zhu`、`xuan-cao`。

## 8. 再生成步骤

依赖：Aseprite 1.3.18（`C:\Atian\Aseprite\aseprite.exe`）、Aseprite MCP 服务
（`C:\Atian\aseprite-mcp`，`uv run -m aseprite_mcp`，stdio）、Python 3.13 + Pillow。

1. 生成 spec 与批处理脚本：
   `python _meta/tools/spec_build.py`
   （读取 `_meta/tools/plant_lib.lua`，产出 `spec.json` 与 `gen_<category>.lua`）
2. 通过 Aseprite MCP 逐分类生成瓦片（一次 Aseprite 启动生成一个分类）：
   `python _meta/tools/run_lua.py _meta/tools/gen_classical.lua`（其余 4 个分类同理）
3. 生成 12 组摇曳动画：
   `python _meta/tools/run_lua.py _meta/tools/gen_anim.lua`
   再用 MCP 的 `set_tag`（`sway`, 1–4, pingpong）与 `export_spritesheet`
   （`sheet_type=horizontal`）导出帧条。
4. 重建本包清单：`python _meta/tools/build_pack_manifest.py plant_spec.json <repo-root>`
5. 重建预览图：`python _meta/tools/make_preview.py plant_spec.json <pack-dir> _meta/preview.png`
6. 重建调色板：`python _meta/tools/make_gpl.py plant_spec.json _meta`
7. 校验：`python _meta/tools/verify_assets.py <pack-dir> --manifest <pack-dir>/assets.manifest.json`
8. 站点清单：`node tools/build-manifest.mjs`（仓库根目录）

脚本依赖的 MCP 桥接脚本为 `_meta/tools/mcp_call.py` 与 `_meta/tools/run_lua.py`；
`mcp_call.py` 通过 stdio 启动 Aseprite MCP 服务并调用其工具（本包生成过程即经由该 MCP 完成）。

## 9. 校验方式

```powershell
python game/pixel-plants/_meta/tools/verify_assets.py `
  game/pixel-plants `
  --manifest game/pixel-plants/assets.manifest.json
```

退出码 0 表示全部通过。校验项：尺寸、RGBA 通道、透明背景存在、硬边（半透明像素只能是阴影色）、
不透明颜色数上限、文件命名、与 `assets.manifest.json` 的双向对账（无孤立文件、无空指向）。
