# _meta/tools — 再生成与校验脚本

所有脚本均为本次交付的可复现工具，路径以本目录为基准。Windows + PowerShell 环境。

## 依赖

| 依赖 | 版本 / 位置 |
|---|---|
| Aseprite | 1.3.18.5，`C:\Atian\Aseprite\aseprite.exe` |
| Aseprite MCP 服务 | `C:\Atian\aseprite-mcp`，以 stdio 方式 `python -m aseprite_mcp` 启动 |
| Python | 3.13（含 Pillow）；本次使用 `C:\Atian\aseprite-mcp\.venv\Scripts\python.exe` |
| Node.js | v22（仅 `build-manifest.mjs` 与集成探针需要；使用内置 fetch / WebSocket，无第三方依赖） |

## 脚本清单

| 文件 | 作用 |
|---|---|
| `plant_lib.lua` | 绘图库：基元（线/圆/叶片/钟形花/珠串等）与 21 种植物原型 |
| `spec_build.py` | 由色彩规格表生成 `plant_spec.json` 与 5 个分类批处理脚本 `gen_<cat>.lua` |
| `plant_spec.json` | 结构化清单：169 条（130 基础 + 39 变体），含 slug / 画布 / 三色 / 原型 / 种子 |
| `gen_classical.lua` … `gen_succulent.lua` | 分类生成脚本（`plant_lib.lua` + 该分类数据） |
| `gen_anim.lua` | 为 12 条代表素材生成 4 帧摇曳动画源文件 |
| `mcp_call.py` / `run_lua.py` | Aseprite MCP 客户端：经 stdio 连接 MCP 服务并调用其工具（`run_lua.py` 执行 Lua 脚本） |
| `build_pack_manifest.py` | 生成本包清单 `assets.manifest.json` |
| `make_preview.py` | 生成全量预览接触表（含中文名称标注） |
| `make_gpl.py` | 生成 `pixel-plants-master.gpl`（64 色主板）与 5 个分类子板 |
| `verify_assets.py` | 素材校验：尺寸 / RGBA / 透明背景 / 硬边 / 颜色数 / 命名 / 与清单双向对账 |
| `rollback_drill.py` | 备份可还原性演练与改动集合枚举 |
| `build-manifest.mjs` | 站点 `manifest.json` 生成器（与仓库 `tools/build-manifest.mjs` 同源） |
| `apply_site_edits.py` | 站点文档/标签的定点文本改动（幂等，锚点必须唯一） |
| `integration_shot.mjs` / `cdp_probe.mjs` | 无头 Chrome + CDP 的接入验证与探针 |
| `probe_expr.js` / `probe_expr2.js` | CDP 探针表达式（尺寸抽查、滚动强制加载统计） |

## 完整再生成流程

```powershell
$PY = 'C:\Atian\aseprite-mcp\.venv\Scripts\python.exe'
$T  = 'game/pixel-plants/_meta/tools'

# 1) 生成 spec 与分类脚本
& $PY "$T/spec_build.py"

# 2) 经 Aseprite MCP 生成 169 枚瓦片（每个分类一次 Aseprite 启动）
foreach ($c in 'classical','romance','herbal','trees','succulent') {
  & $PY "$T/run_lua.py" "$T/gen_$c.lua"
}

# 3) 生成 12 组摇曳动画源文件
& $PY "$T/run_lua.py" "$T/gen_anim.lua"
#    随后用 MCP 的 set_tag(sway,1-4,pingpong) 与 export_spritesheet(horizontal) 导出 *_strip.png

# 4) 包清单 / 预览图 / 调色板
& $PY "$T/build_pack_manifest.py" "$T/plant_spec.json" (Resolve-Path .)
& $PY "$T/make_preview.py" "$T/plant_spec.json" game/pixel-plants game/pixel-plants/_meta/preview.png
& $PY "$T/make_gpl.py" "$T/plant_spec.json" game/pixel-plants/_meta

# 5) 校验（退出码 0 为通过）
& $PY "$T/verify_assets.py" game/pixel-plants --manifest game/pixel-plants/assets.manifest.json

# 6) 站点清单
node tools/build-manifest.mjs
```

## 说明

- `spec_build.py` 读取同目录的 `plant_lib.lua`；两者必须放在同一目录。
- 生成过程是确定性的：所有形态变化由素材编号（seed）驱动，不使用随机数，重复运行产出逐字节一致。
- `mcp_call.py` 会在每次调用时启动 Aseprite 批处理进程；批量生成时优先使用 `run_lua.py`
  一次性提交整段 Lua（一次 Aseprite 启动生成一个分类），避免逐条调用带来的开销。
- 如需换用其他 Aseprite 安装位置，改 `mcp_call.py` 中的 `ASEPRITE` 常量与
  `C:\Atian\aseprite-mcp\.env` 的 `ASEPRITE_PATH`。
