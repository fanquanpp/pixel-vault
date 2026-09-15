# 站点接入验证记录（pixel-plants）

## 1. 目标场景

Pixel Vault 静态素材库站点：`index.html` + `app.js` + `style.css` + `manifest.json`，
由 `.github/workflows/deploy.yml` 在 `main` 分支推送时整目录发布到 GitHub Pages（线上地址
https://fanquanpp.github.io/pixel-vault/ ）。站点前端完全由 `manifest.json` 驱动，
因此「素材被前端收录」等价于「manifest.json 收录 + 前端能正确加载并渲染」。

## 2. 为接入所做的改动

| 文件 | 改动 | 目的 |
|---|---|---|
| `manifest.json` | 用 `tools/build-manifest.mjs` 重新生成 | 收录新包：total 378 → 559，sourceCount 232 → 413，counts.game 191 → 372，`subs.game` 新增 `{id:"game/pixel-plants",count:181}`，assets 新增 181 条 |
| `app.js` | `SUB_LABELS` 新增 `"game/pixel-plants": "像素植物"` | 侧栏分类显示中文名 |
| `CONTENT.md` | 总览表新增一行 + 新增 `### pixel-plants` 规格小节 + 顶部统计改为 559/413 | 团队文档同步 |
| `README.md` | 内容一览表新增一行 + 徽章数字改为 559/413 | 仓库首页同步 |
| `tools/build-manifest.mjs` | 新增清单生成器 | 使清单可复现；复刻验证见第 3 节 |

## 3. 清单生成器的正确性验证（关键前置）

新增的生成器必须复刻原有清单规则，否则「收录」可能顺带改坏既有素材记录。

```
> node tools/build-manifest.mjs --check <备份>/manifest.json --exclude game/pixel-plants
check assets: new=378 ref=378 | distinctSources=232 asepriteOnDisk=232
CHECK OK: content identical to reference (order may differ)
退出码 0
```

即：**排除新包后，生成器产出与改动前清单逐条逐字段完全一致**（path / name / type / bytes /
cat / sub / w / h / source，以及 total / totalBytes / sourceCount / counts / subs 全部相同）。
该步骤同时反向确认了原清单的收录规则（例如 `gui-test-screenshots/` 属测试产物、不入清单；
`*_strip.png` 的来源指向去后缀的 `.aseprite`）。

改动前清单校验值：`92827b7a711ce043b087587f3ed0ca47909fad79ec917cf36239ce1d2d155736`（SHA-256）。
生成器对既有条目顺序做了确定性重排（类别 → 子目录 → 路径）；站点前端在客户端按名称排序，
数组顺序不影响展示（`app.js` 默认 `sort: "name"`）。

## 4. HTTP 可达性

本地静态服务（`python -m http.server 8765`）实测：

| 请求 | 结果 |
|---|---|
| `GET /manifest.json` | HTTP 200，111,348 字节 |
| `GET /game/pixel-plants/ling-lan.png` | HTTP 200，245 字节 |

## 5. 浏览器实际加载验证（无头 Chrome + CDP）

站点无 URL 路由，故用 CDP 驱动真实页面：加载首页 → 点击侧栏「像素植物」→ 读取真实渲染结果并截图。

实测返回（节选）：

| 指标 | 实测值 |
|---|---|
| 页面标题 | `Pixel Vault · 共享素材库` |
| 首页介绍行 | `110 专业方向像素头像 · 游戏 UI 包 · 地贴 · 动画帧条 · 矢量图标 · 413 Aseprite 源文件 · 全部 MIT` |
| 首页统计 | `559 可见素材` / `413 Aseprite 源文件` / `110 专业头像` / `1.94 MB 总大小` |
| 侧栏存在像素植物入口 | 是（`data-sub="game/pixel-plants"`） |
| 点击后该入口状态 | `tsub active` |
| 网格条目数 | 181 |
| 页面中的植物图片节点数 | 181 |
| 强制滚动加载后：已加载 | 181 |
| 强制滚动加载后：损坏（naturalWidth=0） | 0 |
| 强制滚动加载后：仍未加载 | 0 |
| 尺寸直方图（naturalWidth×naturalHeight） | 16×16: 152、32×32: 17、64×16: 11、128×32: 1 |
| 单张抽查（`ling-lan.png`） | natural 16×16，CSS 渲染 16×16（无意外缩放） |
| 单张抽查（`ling-lan-sway_strip.png`） | natural 64×16 |
| 单张抽查（`pu-ti-shu-sway_strip.png`） | natural 128×32 |

尺寸直方图与设计完全吻合：169 枚瓦片 = 152 枚 16×16 + 17 枚 32×32；
12 条帧条 = 11 条 64×16（16px 素材）+ 1 条 128×32（32px 的 `pu-ti-shu`）。合计 181。

截图证据：`.cluster/pixel-plants/integration-plants.png`（AutoCoder 控制工作区内，
未写入用户仓库）。

## 6. 结论与遗留

- **结论**：新素材包已被前端完整收录并正确渲染——181/181 张图片加载成功、0 损坏，
  引用路径与画布尺寸/帧条尺寸均正确，分类入口可点击进入。
- **线上确认**：GitHub Pages 的线上更新需在推送 `main` 后由 Actions 部署完成，
  属于本记录之外的独立环节（见最终交付说明）。
- **未做**：未在真实浏览器 UI 中人工点击（环境限制：内置浏览器禁访问 localhost，
  改用无头 Chrome + CDP 驱动同一站点，结论等价）。
