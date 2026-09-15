# CONTENT · 内容说明

> Pixel Vault 全部内容的规格、来源与使用方式。统计基于 manifest.json（559 件可见素材 / 413 个 Aseprite 源）。

## 总览 / Overview

| 族 | 画布规格 | 格式 | 数量 |
|---|---|---|---|
| avatars/ | 源 256×256，导出 512×512 | .aseprite（bg/icon/text 三层）+ .png | 110 组 |
| game/pixel-ui-pack/ | 16×16（按钮 48×16、面板 48×48） | .aseprite + .png | 17 件 |
| game/pixel-ui-pack-hd/ | 32×32 | .aseprite（icon/glyph 层）+ .png | 6 件 |
| game/pixel-tiles/ | 16×16 | .aseprite + .png | 8 块 |
| game/pixel-anim/ | 16×16（落叶 32×32），4-8 帧横向帧条 | .aseprite（多帧）+ _strip.png | 8 组 |
| game/pixel-plants/ | 16×16（树木 32×32），169 瓦片 + 12 组 4 帧帧条 | .aseprite（7 层）+ .png / _strip.png | 181 |
| game/speed-rouge/ | 混合（16px 条带到 6400×1080 关卡层） | .aseprite + .png | 151 |
| game/bianqv/ | 混合 | .aseprite + .png | 1 |
| icons/vector/ | 矢量 | .svg | 69 |
| icons/speed-rouge/ | 混合 | .png/.aseprite | 5 |
| branding/ | 社交卡 1200×630 / bianqv 图标 | .png/.svg | 3 |

## avatars/ — 像素专业方向头像

面向高校专业/职业方向的系列头像，统一版式：白底、单色系像素图标（24 格网格、4px 像素）、Fusion Pixel 字体中文标题与英文字幕、分隔线。

- 类目：计算机软件(29)、电子信息(3)、机械自动化(13)、土木建筑(6)、医学健康(9)、经济管理(12)、人文法学(7)、教育体育(5)、理学(10)、艺术设计(6)、公共服务(6，新)、legacy-black(4，旧版风格存档)
- 命名：`<方向>.png`（512 导出）+ `<方向>.aseprite`（256 源，bg / icon / text 三层可编辑）
- 配色：每方向一主色，五阶色带 + 金色徽记点缀；全系列经撞色排查
- 明暗：纯色图标统一加同色系暗部（左上光源，右/下缘加深约 28%），已有多阶配色的图标保持原样

## game/ — 游戏素材

### pixel-ui-pack（16×16 基础包）
红心三态、金币双色、宝石、钥匙、星、药水、宝箱开合、盾、剑、骷髅，以及 48×16 按钮两态与 48×48 九宫面板。与 HD 版同源的五阶色带：同色系深色描边（受光面偏暖）、镜面高光、明暗过渡沿左上光源方向。

### pixel-ui-pack-hd（32×32 精雕版）
心/金币/宝石/钥匙/药水/星。在基础包规格上提升：五阶同色系色带、棋盘抖动过渡、同色系深色描边、白色镜面高光。aseprite 内 icon 与 glyph 分层。

### pixel-tiles（16×16 地贴）
草/土/石/沙/木板/砖/水/雪。细节以 2 像素簇排布（草叶/碎石/波纹），避免孤立杂点；结构性线条全宽或按 8 行周期排布，3×3 平铺验证无缝；砖与石块带手工接缝与受光面。

### pixel-anim（动画帧条）
水流/火焰/风/落叶/枯萎/奔跑/烟雾/星光八组逐帧动画，导出为横向帧条 `_strip.png`（4-8 帧，帧宽 16 或 32；aseprite 源内逐帧可编辑）。
- `water-flow`：4 帧无缝循环，光暗波纹线按 4px/帧位移表现流向，白色浪尖点缀
- `flame`：6 帧火苗循环，上半部剪影左右摆动 + 火星飘散，五阶色带（深红-红-橙-琥珀-黄-白热）
- `wind-gust`：6 帧阵风，风线拉长-扫过-消散，绿叶粒子同步翻滚
- `leaves-fall`：8 帧落叶，双叶（绿/琥珀）之字摇摆下落，相位错半周期，无缝循环
- `plant-wither`：6 帧单向枯萎序列：挺立-垂头-褪色转褐-倒伏落瓣
- `run-cycle`：6 帧奔跑循环，接触/下压/腾空三关键姿态 × 双摆臂相位，身体随步幅起伏
- `smoke-puff`：5 帧烟雾上升消散；`sparkle`：4 帧星形闪烁循环

### pixel-plants（植物像素素材）
169 枚植物瓦片 + 12 组摇曳动画帧条，按「古典仙气 / 浪漫花语 / 本草清雅 / 树木佛意 / 野趣多肉」五类组织；文件名用拼音 kebab-case（如 `juan-er`、`man-zhu-sha-hua`），中文名与逐条来源见 `game/pixel-plants/_meta/slug-map.md`。
- 画布：小花草本 16×16，树木 32×32；导出为透明背景 PNG，硬边无抗锯齿
- 图层：每枚源文件统一 7 层，自下而上 `shadow / stem / leaf / bloom / bloom-shade / core / glint`，可继续编辑
- 调色板：主色/辅色/点色按清单逐条给定，叶茎复用通用自然色板；单枚瓦片不透明颜色数控制在 4-7
- 变体：同形换色（只替换主/辅/点色，叶茎不变），共 39 枚变体瓦片
- 动画：`<slug>-sway_strip.png` 为 4 帧横向帧条（帧宽等于画布宽），150ms/帧、pingpong 循环，源文件内打 `sway` 标签
- 清单与文档：`game/pixel-plants/assets.manifest.json`（逐项名称/类别/尺寸/帧数/调色板/路径/状态/来源条目）；`game/pixel-plants/_meta/` 含预览接触表、`.gpl` 调色板（64 色主板 + 5 个子板）、命名映射与再生成脚本

### speed-rouge（完整平台跳跃项目素材）
- `buildings/` `geometry/` 建筑与几何地景
- `mechanics/` 机关（检查点、传送门、琴键地块、限时桥、变速门、弹射垫等），`*_strip.png` 为横向帧条
- `levels/` 关卡导出（`_ent` 实体层 / `_map` 地形层 / 基础层），含 rogue 模式五类机关 × 三难度 × 双节奏变体
- `characters/`（cat_sheet 猫奔跑条）、`collectibles/`、`fx/`（死亡碎屑/落地尘/换位爆闪）、`ui/`（card/poster 边框）

### bianqv
该项目的 sprite sheet（icons.png）及 aseprite 源。

## icons/ — 图标

### vector（SVG 69 枚）
speed-rouge 界面用扁平线性图标，按 arrows / audio / buttons / characters / icons / keys / objects / ui 八组组织，纯白单色，适合做遮罩或 currentColor 染色。

### speed-rouge
speed-rouge 应用图标与自适应图标分层。

## branding/ — 品牌资产

site/social-card.png（站点分享卡）、bianqv 的 icon64 与 logo。

## 使用约定 / Conventions

- 像素图放大请使用最近邻插值：CSS `image-rendering: pixelated`，引擎中关闭纹理过滤。
- 像素图原生尺寸即设计尺寸（16/32px），不要缩小。
- 所有 .aseprite 源用 Aseprite 打开即可编辑分层；导出位置与画布约定见各目录 README 级说明（本文件）。
- 修改再分发请保留 LICENSE 声明；字体相关注意 DISCLAIMER 第 3 节。
