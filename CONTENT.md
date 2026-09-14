# CONTENT · 内容说明

> Pixel Vault 全部内容的规格、来源与使用方式。统计基于 manifest.json（382 件可见素材 / 236 个 Aseprite 源）。

## 总览 / Overview

| 族 | 画布规格 | 格式 | 数量 |
|---|---|---|---|
| avatars/ | 源 256×256，导出 512×512 | .aseprite（bg/icon/text 三层）+ .png | 110 组 |
| game/pixel-ui-pack/ | 16×16（按钮 48×16、面板 48×48） | .aseprite + .png | 17 件 |
| game/pixel-ui-pack-hd/ | 32×32 | .aseprite（icon/glyph 层）+ .png | 6 件 |
| game/pixel-tiles/ | 16×16 | .aseprite + .png | 8 块 |
| game/speed-rouge/ | 混合（16px 条带到 6400×1080 关卡层） | .aseprite + .png | 151 |
| game/bianqv/ | 混合 | .aseprite + .png | 2 |
| icons/file-icons/ | 32×32 | .aseprite（icon/glyph 两层）+ .png | 12 枚 |
| icons/vector/ | 矢量 | .svg | 69 |
| icons/speed-rouge/ | 混合 | .png/.aseprite | 5 |
| branding/ | 社交卡 1200×630 / bianqv 图标 | .png/.svg | 3 |

## avatars/ — 像素专业方向头像

面向高校专业/职业方向的系列头像，统一版式：白底、单色系像素图标（24 格网格、4px 像素）、Fusion Pixel 字体中文标题与英文字幕、分隔线。

- 类目：计算机软件(29)、电子信息(3)、机械自动化(13)、土木建筑(6)、医学健康(9)、经济管理(12)、人文法学(7)、教育体育(5)、理学(10)、艺术设计(6)、公共服务(6，新)、legacy-black(4，旧版风格存档)
- 命名：`<方向>.png`（512 导出）+ `<方向>.aseprite`（256 源，bg / icon / text 三层可编辑）
- 配色：每方向一主色，五阶色带 + 金色徽记点缀；全系列经撞色排查

## game/ — 游戏素材

### pixel-ui-pack（16×16 基础包）
红心三态、金币双色、宝石、钥匙、星、药水、宝箱开合、盾、剑、骷髅，以及 48×16 按钮两态与 48×48 九宫面板。与 HD 版同源的五阶色带：同色系深色描边（受光面偏暖）、镜面高光、明暗过渡沿左上光源方向。

### pixel-ui-pack-hd（32×32 精雕版）
心/金币/宝石/钥匙/药水/星。在基础包规格上提升：五阶同色系色带、棋盘抖动过渡、同色系深色描边、白色镜面高光。aseprite 内 icon 与 glyph 分层。

### pixel-tiles（16×16 地贴）
草/土/石/沙/木板/砖/水/雪。细节以 2 像素簇排布（草叶/碎石/波纹），避免孤立杂点；结构性线条全宽或按 8 行周期排布，3×3 平铺验证无缝；砖与石块带手工接缝与受光面。

### speed-rouge（完整平台跳跃项目素材）
- `buildings/` `geometry/` 建筑与几何地景
- `mechanics/` 机关（检查点、传送门、琴键地块、限时桥、变速门、弹射垫等），`*_strip.png` 为横向帧条
- `levels/` 关卡导出（`_ent` 实体层 / `_map` 地形层 / 基础层），含 rogue 模式五类机关 × 三难度 × 双节奏变体
- `characters/`（cat_sheet 猫奔跑条）、`collectibles/`、`fx/`（死亡碎屑/落地尘/换位爆闪）、`ui/`（card/poster 边框）

### bianqv
该项目的 sprite sheet（icons.png）及 aseprite 源。

## icons/ — 图标

### file-icons（32×32 开发者文件图标）
参照代码编辑器文件图标的配色语言（橙=HTML、蓝=CSS/TS、黄=JS/JSON、红=Git）：git、jekyll、html、css、js、ts、json、md、svg、png、zip、folder。徽章类带倒角高光，字形独立 glyph 层。商标说明见 DISCLAIMER。

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
