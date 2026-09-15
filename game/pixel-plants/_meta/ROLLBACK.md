# 备份与回滚说明（pixel-plants）

## 1. 备份

| 项目 | 值 |
|---|---|
| 备份目录 | `C:\Atian\Project\_backups\pixel-vault\20260915-061238` |
| 解包副本 | 该目录下即为完整工作树副本（628 个文件，10,612,106 字节） |
| 压缩包 | `C:\Atian\Project\_backups\pixel-vault\20260915-061238\pixel-vault-src.zip`（3,469,742 字节） |
| 备份时间 | 2026-09-15 06:12（改动前） |
| 排除项 | `.git/`（版本历史由 git 自身保存） |
| 制作方式 | 只复制、不删除的 Python 脚本（首次含删除动作的备份命令被安全守卫拦截后改用此方式） |
| 校验 | 包内与解包副本 628 个文件 SHA-256 全一致；两次独立解包结果一致 |

备份同时保留了改动前的站点清单副本 `manifest.preplants.json`，其 SHA-256
（`92827b7a711ce043b087587f3ed0ca47909fad79ec917cf36239ce1d2d155736`）与备份内
`manifest.json` 一致，可作为「改动前站点清单」的独立凭据。

## 2. 本次改动集合（相对改动前）

由回滚演练脚本按 SHA-256 逐文件比对得出：

| 类型 | 数量 | 明细 |
|---|---|---|
| 新增 | 394 | `game/pixel-plants/**`（素材 + `_meta/` 文档 + `tools/` 脚本）、`tools/build-manifest.mjs` |
| 修改 | 4 | `CONTENT.md`、`README.md`、`app.js`、`manifest.json` |
| 删除 | 0 | 无（未修改、未删除、未重命名任何既有素材） |

`removed_count = 0` 与「不修改已有素材」的约束一致。

## 3. 回滚步骤

### 方式 A：用备份还原（不依赖 git）

```powershell
# 1) 还原 4 个被修改的文件
Copy-Item 'C:\Atian\Project\_backups\pixel-vault\20260915-061238\manifest.json' 'C:\Atian\Project\pixel-vault\manifest.json' -Force
Copy-Item 'C:\Atian\Project\_backups\pixel-vault\20260915-061238\app.js'       'C:\Atian\Project\pixel-vault\app.js'       -Force
Copy-Item 'C:\Atian\Project\_backups\pixel-vault\20260915-061238\README.md'    'C:\Atian\Project\pixel-vault\README.md'    -Force
Copy-Item 'C:\Atian\Project\_backups\pixel-vault\20260915-061238\CONTENT.md'   'C:\Atian\Project\pixel-vault\CONTENT.md'   -Force

# 2) 移除本次新增的路径（两者均为本次新增，删除不影响任何既有素材）
Remove-Item -Recurse -Force 'C:\Atian\Project\pixel-vault\game\pixel-plants'
Remove-Item -Force         'C:\Atian\Project\pixel-vault\tools\build-manifest.mjs'
```

完成后工作树与备份副本逐字节一致（见下节演练结论）。

### 方式 B：用 git 回滚

- **尚未提交时**：`git checkout -- CONTENT.md README.md app.js manifest.json`，并删除上述新增路径。
- **已提交但未推送时**：`git reset --hard <本次改动前的提交>`。
- **已推送后**：`git revert --no-commit <本次提交的 SHA>` 然后提交，保留可追溯历史（推荐）。

## 4. 回滚演练结果（实际执行）

演练脚本：`_meta/tools/rollback_drill.py`（运行于 2026-09-15）。

| 检查项 | 结果 |
|---|---|
| 备份压缩包解包 | 成功，628 个文件 |
| 解包结果与备份副本逐文件 SHA-256 比对 | 一致（628/628） |
| 第二次独立解包比对 | 一致（628/628） |
| 备份中是否已含 pixel-plants 包 | 否（确认是改动前状态） |
| 备份清单数值 | total=378 / sourceCount=232（改动前基线） |
| 当前仓库清单数值 | total=559 / sourceCount=413 |
| 改动集合是否可枚举且封闭 | 是（新增 394、修改 4、删除 0） |
| 回滚是否足以恢复原状 | 是（`rollback_is_sufficient = true`） |

**安全说明**：演练**未**在真实仓库上执行任何删除动作。做法是把备份解包到
`C:\Atian\Project\_backups\_restore-drill\`（及 `_restore-drill2\`）进行「还原到目标状态」的实际操作并做哈希比对，
再据此枚举真实仓库的改动集合。由于改动集合已被完整枚举（新增/删除/修改三类互斥且穷尽），
且备份已证明可完整还原，按第 3 节步骤执行即可恢复改动前状态。

演练留存的目录（`_restore-drill`、`_restore-drill2`）位于 `_backups` 下，可随时手动清理。
