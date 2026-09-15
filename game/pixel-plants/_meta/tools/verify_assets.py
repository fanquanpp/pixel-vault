#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_assets.py -- 像素素材导出图合规校验器 (pixel-plants)

用法:
    python verify_assets.py <assets_dir> [--manifest <assets.manifest.json>] [--json-out <path>]

对 <assets_dir> (递归) 下每个 *.png 逐张校验并汇总，输出人类可读报告；
同时生成机器可读 JSON（写入 --json-out，或打印到 stdout）。

校验规则:
  R1  尺寸         : 与期望尺寸比对 (manifest 的 w/h > 文件名中 WxH > 无法推断则仅记录实测值)
  R2  通道         : 必须为 RGBA (含 alpha)；P / RGB / LA / L 等 -> error
  R3  透明背景     : alpha 必须同时出现过 0 与 255
  R4  硬边(无抗锯齿): 所有 0<alpha<255 的像素，其 RGB 必须等于阴影色 #1A1A20，
                     且 alpha 落在 [0.25,0.40]*255 = [64,102] 区间内 (容差 ±8 -> [56,110])
  R5  受控调色板   : alpha==255 的不透明像素，唯一 RGB 数 > 12 -> warning
  R6  文件命名     : 仅允许小写 a-z0-9 与单连字符，且必须以 .png 结尾
  R7  manifest 对账: manifest 每条 path 必须在磁盘存在；磁盘每个 .png 必须出现在 manifest 中

退出码:
  0 = 全部通过 (允许 warning)
  1 = 存在至少一个 error
  2 = 参数 / 环境错误 (目录不存在、无 PNG、manifest 无法解析等)

作者: AutoCoder (OpenClaw subagent)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image
except Exception as exc:  # pragma: no cover - 环境缺失时给出明确提示
    sys.stderr.write("FATAL: 需要 Pillow (PIL)。安装: pip install Pillow\n%s\n" % exc)
    raise SystemExit(2)


# --------------------------------------------------------------------------
# 常量 / 默认阈值
# --------------------------------------------------------------------------
DEFAULT_SHADOW_HEX = "#1A1A20"
DEFAULT_ALPHA_MIN = 64      # round(0.25 * 255)
DEFAULT_ALPHA_MAX = 102     # round(0.40 * 255)
DEFAULT_ALPHA_TOL = 8       # ±8 容差
DEFAULT_MAX_COLORS = 12     # 不透明像素唯一颜色上限

# 文件名: 允许段 = [a-z0-9]+ , 段之间单个连字符; 不得以连字符开头/结尾, 不得出现 '--'
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.png$")


def name_ok(name: str, allow_suffixes=()) -> bool:
    """R6 naming: strict kebab-case, plus explicitly allowed project suffixes.

    The library's own animation strips are named <name>_strip.png (see
    game/pixel-anim and CONTENT.md), which the strict pattern rejects, so the
    exception is opt-in via --allow-suffix and never silently applied.
    """
    if NAME_RE.match(name):
        return True
    if not name.lower().endswith(".png"):
        return False
    stem = name[: -len(".png")]
    for suf in allow_suffixes:
        if suf and stem.endswith(suf) and NAME_RE.match(stem[: -len(suf)] + ".png"):
            return True
    return False
# 文件名中的尺寸标记, 例如 foo-16x16.png / bar_32X48.png
SIZE_RE = re.compile(r"(?<![0-9])(\d{1,4})\s*[xX]\s*(\d{1,4})(?![0-9])")

MANIFEST_LIST_KEYS = ("assets", "files", "items", "entries", "tiles", "sprites", "resources")
MANIFEST_PATH_KEYS = ("path", "file", "filename", "file_name", "name", "src", "source", "out", "output", "relpath", "relative_path")

SEVERITY_ERROR = "error"
SEVERITY_WARNING = "warning"


# --------------------------------------------------------------------------
# 工具函数
# --------------------------------------------------------------------------
def parse_hex_color(text: str) -> tuple[int, int, int]:
    s = text.strip().lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        raise ValueError("颜色必须是 #RRGGBB, 收到: %r" % text)
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def issue(rule: str, level: str, code: str, message: str, **extra) -> dict:
    item = {"rule": rule, "level": level, "code": code, "message": message}
    item.update(extra)
    return item


def size_from_name(name: str) -> tuple[int, int] | None:
    """从文件名推断期望尺寸, 例如 plant-16x16.png -> (16,16)。"""
    m = SIZE_RE.search(name)
    if not m:
        return None
    w, h = int(m.group(1)), int(m.group(2))
    if w <= 0 or h <= 0:
        return None
    return (w, h)


def _coerce_size(value) -> tuple[int, int] | None:
    """把 manifest 里的各种尺寸写法统一成 (w,h)。"""
    if value is None:
        return None
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        try:
            return (int(value[0]), int(value[1]))
        except (TypeError, ValueError):
            return None
    if isinstance(value, str):
        m = SIZE_RE.search(value)
        if m:
            return (int(m.group(1)), int(m.group(2)))
    return None


def _coerce_int(value):
    if value is None:
        return None
    try:
        iv = int(value)
    except (TypeError, ValueError):
        return None
    return iv if iv > 0 else None


def normalize_manifest_entry(index: int, entry) -> dict | None:
    """把 manifest 单条记录规整为 {path, w, h}。无法解析则返回 None。"""
    if isinstance(entry, str):
        return {"path": entry, "w": None, "h": None}
    if not isinstance(entry, dict):
        return None

    path = None
    for key in MANIFEST_PATH_KEYS:
        val = entry.get(key)
        if isinstance(val, str) and val.strip():
            path = val.strip()
            break
    if path is None:
        return None

    w = _coerce_int(entry.get("w"))
    if w is None:
        w = _coerce_int(entry.get("width"))
    if w is None:
        w = _coerce_int(entry.get("expected_w"))
    h = _coerce_int(entry.get("h"))
    if h is None:
        h = _coerce_int(entry.get("height"))
    if h is None:
        h = _coerce_int(entry.get("expected_h"))

    if w is None or h is None:
        size = _coerce_size(entry.get("size"))
        if size is None:
            size = _coerce_size(entry.get("dimensions"))
        if size:
            w, h = size

    return {
        "path": path,
        "kind": entry.get("kind"),
        "w": w,
        "h": h,
        "index": index,
        "raw_size": entry.get("size") if isinstance(entry.get("size"), (str, list, tuple)) else None,
    }


def load_manifest(path: Path) -> tuple[list[dict], str | None]:
    """读取 manifest, 返回 (entries, error_message)。"""
    try:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError as exc:
        return [], "无法读取 manifest: %s" % exc
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        return [], "manifest 不是合法 JSON: %s" % exc

    raw_list = None
    if isinstance(data, list):
        raw_list = data
    elif isinstance(data, dict):
        for key in MANIFEST_LIST_KEYS:
            if isinstance(data.get(key), list):
                raw_list = data[key]
                break
        if raw_list is None:
            # 形如 {"foo.png": {...}} 的 map
            if data and all(isinstance(v, (dict, str)) for v in data.values()):
                items = []
                for k, v in data.items():
                    if isinstance(v, dict):
                        merged = dict(v)
                        merged.setdefault("path", k)
                        items.append(merged)
                    else:
                        items.append({"path": k, "size": v})
                raw_list = items

    if raw_list is None:
        return [], "manifest 结构无法识别 (既不是数组, 也不含 assets/files/items 列表)"

    entries = []
    for i, raw in enumerate(raw_list):
        norm = normalize_manifest_entry(i, raw)
        if norm is not None:
            entries.append(norm)
    if not entries:
        return [], "manifest 中没有任何可解析的条目 (需要 path/file/name 字段)"
    return entries, None


def norm_rel(p) -> str:
    """统一的相对路径字符串 (正斜杠)。"""
    return str(p).replace("\\", "/")


def collect_pngs(assets_dir: Path) -> list[Path]:
    """递归收集 PNG (不区分大小写扩展名), 排序稳定。"""
    found = []
    for p in assets_dir.rglob("*"):
        if p.is_file() and p.suffix.lower() == ".png":
            found.append(p)
    return sorted(found, key=lambda p: norm_rel(p.relative_to(assets_dir)).lower())


# --------------------------------------------------------------------------
# 单文件校验
# --------------------------------------------------------------------------
def check_file(
    img_path: Path,
    assets_dir: Path,
    expected: tuple[int, int] | None,
    expected_source: str,
    shadow_rgb: tuple[int, int, int],
    alpha_lo: int,
    alpha_hi: int,
    max_colors: int,
    allow_suffixes: tuple = (),
    kind: str | None = None,
) -> dict:
    rel = norm_rel(img_path.relative_to(assets_dir))
    result = {
        "path": rel,
        "status": "pass",
        "expected_size": list(expected) if expected else None,
        "expected_size_source": expected_source if expected else None,
        "actual_size": None,
        "mode": None,
        "stats": {},
        "issues": [],
    }

    # ---- R6 命名 (先做, 即使图片打不开也能报) ----
    if img_path.suffix.lower() != ".png":
        result["issues"].append(
            issue("R6", SEVERITY_ERROR, "bad_extension", "文件扩展名不是小写 .png: %r" % img_path.name)
        )
    elif not name_ok(img_path.name, allow_suffixes):
        result["issues"].append(
            issue(
                "R6",
                SEVERITY_ERROR,
                "bad_filename",
                "文件名不合规 (仅允许小写 a-z0-9 与单连字符, 且以 .png 结尾): %r" % img_path.name,
            )
        )

    # ---- 打开图片 ----
    try:
        with Image.open(img_path) as im:
            im.load()
            width, height = im.size
            mode = im.mode
            result["actual_size"] = [width, height]
            result["mode"] = mode
            result["format"] = im.format

            # ---- R1 尺寸 ----
            if expected is not None and (width, height) != tuple(expected):
                result["issues"].append(
                    issue(
                        "R1",
                        SEVERITY_ERROR,
                        "size_mismatch",
                        "尺寸不符: 期望 %dx%d (来源: %s), 实际 %dx%d"
                        % (expected[0], expected[1], expected_source, width, height),
                    )
                )
            elif expected is None:
                result["issues"].append(
                    issue(
                        "R1",
                        SEVERITY_WARNING,
                        "size_unknown",
                        "无期望尺寸可比对 (未提供 manifest 且文件名无 WxH 标记), 实测 %dx%d" % (width, height),
                    )
                )

            # ---- R2 通道 ----
            has_alpha = "A" in mode.split(";")[0] or im.mode in ("RGBA", "LA", "PA")
            if mode != "RGBA":
                msg = "必须为 RGBA (含独立 alpha 通道)，实际为 %s" % mode
                if mode == "P":
                    msg += " (调色板图, 请导出为 RGBA)"
                elif mode in ("RGB", "L", "1", "I", "F"):
                    msg += " (无 alpha 通道)"
                elif mode in ("LA", "PA"):
                    msg += " (alpha 与灰度打包)"
                result["issues"].append(issue("R2", SEVERITY_ERROR, "mode_not_rgba", msg))
                if not has_alpha:
                    result["issues"].append(
                        issue("R2", SEVERITY_ERROR, "no_alpha_channel", "无 alpha 通道, 无法校验透明/硬边")
                    )

            # 像素级检查仅在 RGBA 且为素材类 (tile/strip) 时执行;
            # _meta/ 下的文档图 (kind=preview 等) 不适用透明背景与硬边规则。
            if mode == "RGBA" and kind in (None, "tile", "strip"):
                rgba = im.getdata()
                n_transparent = 0
                n_opaque = 0
                n_semi = 0
                alpha_seen = set()
                opaque_colors = set()
                semi_bad_color = {}   # rgb -> count
                semi_bad_alpha = {}   # alpha -> count
                semi_bad_alpha_min = None
                semi_bad_alpha_max = None
                opq_r = opq_g = opq_b = 0

                for r, g, b, a in rgba:
                    if a == 0:
                        n_transparent += 1
                        alpha_seen.add(0)
                    elif a == 255:
                        n_opaque += 1
                        alpha_seen.add(255)
                        opaque_colors.add((r, g, b))
                        opq_r += r
                        opq_g += g
                        opq_b += b
                    else:
                        n_semi += 1
                        alpha_seen.add(1)  # 只用哨兵值表示"存在中间值"
                        if (r, g, b) != shadow_rgb:
                            semi_bad_color[(r, g, b)] = semi_bad_color.get((r, g, b), 0) + 1
                        if not (alpha_lo <= a <= alpha_hi):
                            semi_bad_alpha[a] = semi_bad_alpha.get(a, 0) + 1
                            semi_bad_alpha_min = a if semi_bad_alpha_min is None else min(semi_bad_alpha_min, a)
                            semi_bad_alpha_max = a if semi_bad_alpha_max is None else max(semi_bad_alpha_max, a)

                result["stats"] = {
                    "total_pixels": width * height,
                    "transparent_pixels": n_transparent,
                    "opaque_pixels": n_opaque,
                    "semi_transparent_pixels": n_semi,
                    "unique_opaque_colors": len(opaque_colors),
                }
                if n_opaque:
                    result["stats"]["avg_opaque_rgb"] = [
                        round(opq_r / n_opaque, 2),
                        round(opq_g / n_opaque, 2),
                        round(opq_b / n_opaque, 2),
                    ]

                # ---- R3 透明背景存在 ----
                if 0 not in alpha_seen:
                    result["issues"].append(
                        issue("R3", SEVERITY_ERROR, "alpha_no_transparent", "不存在 alpha=0 的像素 (缺少透明背景)")
                    )
                if 255 not in alpha_seen:
                    result["issues"].append(
                        issue("R3", SEVERITY_ERROR, "alpha_no_opaque", "不存在 alpha=255 的像素 (画面全透明或全部半透明)")
                    )

                # ---- R4 硬边 / 抗锯齿 ----
                if semi_bad_color:
                    top = sorted(semi_bad_color.items(), key=lambda kv: -kv[1])[:5]
                    shown = ", ".join(
                        "#%02X%02X%02X x%d" % (c[0], c[1], c[2], cnt) for c, cnt in top
                    )
                    result["issues"].append(
                        issue(
                            "R4",
                            SEVERITY_ERROR,
                            "antialias_stray_color",
                            "半透明像素出现非阴影色 (期望 #%02X%02X%02X)，疑似抗锯齿/边缘杂点: %d 个像素, top: %s"
                            % (shadow_rgb[0], shadow_rgb[1], shadow_rgb[2], sum(semi_bad_color.values()), shown),
                            total=sum(semi_bad_color.values()),
                            sample_colors=shown,
                        )
                    )
                if semi_bad_alpha:
                    result["issues"].append(
                        issue(
                            "R4",
                            SEVERITY_ERROR,
                            "antialias_alpha_out_of_band",
                            "半透明像素 alpha 超出 [%d,%d] 区间: %d 个像素, 实测范围 %s..%s"
                            % (
                                alpha_lo,
                                alpha_hi,
                                sum(semi_bad_alpha.values()),
                                semi_bad_alpha_min,
                                semi_bad_alpha_max,
                            ),
                            total=sum(semi_bad_alpha.values()),
                            observed_min=semi_bad_alpha_min,
                            observed_max=semi_bad_alpha_max,
                        )
                    )

                # ---- R5 受控调色板 ----
                if len(opaque_colors) > max_colors:
                    result["issues"].append(
                        issue(
                            "R5",
                            SEVERITY_WARNING,
                            "palette_too_many_colors",
                            "不透明像素唯一颜色数 %d > %d (像素植物瓦片应少色)"
                            % (len(opaque_colors), max_colors),
                            unique_colors=len(opaque_colors),
                            limit=max_colors,
                        )
                    )

    except Exception as exc:  # 单张坏图不应炸掉整轮
        result["issues"].append(issue("-", SEVERITY_ERROR, "unreadable", "无法读取/解析 PNG: %s" % exc))

    if any(i["level"] == SEVERITY_ERROR for i in result["issues"]):
        result["status"] = "fail"
    return result


# --------------------------------------------------------------------------
# 报告
# --------------------------------------------------------------------------
def render_text_report(report: dict, shadow_rgb, alpha_lo, alpha_hi, max_colors) -> str:
    lines = []
    add = lines.append
    add("=" * 78)
    add("像素素材校验报告 (pixel-plant asset verifier)")
    add("=" * 78)
    add("素材目录 : %s" % report["assets_dir"])
    add("manifest : %s" % (report["manifest"] or "(未提供)"))
    add("生成时间 : %s" % report["generated_at"])
    add(
        "阈值     : 阴影色 #%02X%02X%02X | 半透明 alpha 允许区间 [%d,%d] | 不透明颜色上限 %d"
        % (shadow_rgb[0], shadow_rgb[1], shadow_rgb[2], alpha_lo, alpha_hi, max_colors)
    )
    add("")

    files = report["files"]
    if not files:
        add("!! 目录下未找到任何 .png 文件")
        add("")
    for f in files:
        tag = "PASS" if f["status"] == "pass" else "FAIL"
        warn_only = f["status"] == "pass" and any(i["level"] == SEVERITY_WARNING for i in f["issues"])
        if warn_only:
            tag = "PASS*"
        size = f["actual_size"]
        size_txt = "%dx%d" % (size[0], size[1]) if size else "?"
        add("[%s] %s  (%s, mode=%s)" % (tag, f["path"], size_txt, f["mode"]))
        st = f.get("stats") or {}
        if st:
            add(
                "       px: 透明 %s / 不透明 %s / 半透明 %s | 不透明唯一色 %s"
                % (
                    st.get("transparent_pixels", "-"),
                    st.get("opaque_pixels", "-"),
                    st.get("semi_transparent_pixels", "-"),
                    st.get("unique_opaque_colors", "-"),
                )
            )
        for i in f["issues"]:
            mark = "x" if i["level"] == SEVERITY_ERROR else "!"
            add("       %s [%s] %s" % (mark, i["rule"], i["message"]))
    add("")

    # manifest 对账
    mc = report.get("manifest_check")
    if mc:
        add("-" * 78)
        add("R7 manifest 对账: 磁盘 PNG %d 个 / manifest 条目 %d 条" % (mc["png_on_disk"], mc["manifest_entries"]))
        if mc.get("missing_on_disk"):
            add("  空指向 (manifest 有/磁盘无) %d 个:" % len(mc["missing_on_disk"]))
            for p in mc["missing_on_disk"]:
                add("    - %s" % p)
        if mc.get("orphans"):
            add("  孤立文件 (磁盘有/manifest 无) %d 个:" % len(mc["orphans"]))
            for p in mc["orphans"]:
                add("    - %s" % p)
        if mc.get("skipped_duplicates"):
            add("  重复条目 %d 个: %s" % (len(mc["skipped_duplicates"]), ", ".join(mc["skipped_duplicates"][:8])))
        if not mc.get("missing_on_disk") and not mc.get("orphans"):
            add("  一致 (无空指向 / 无孤立文件)")
        if mc.get("error"):
            add("  !! %s" % mc["error"])
        add("")

    s = report["summary"]
    add("-" * 78)
    add(
        "汇总: 文件 %d | 通过 %d | 失败 %d | error %d | warning %d"
        % (s["total"], s["passed"], s["failed"], s["errors"], s["warnings"])
    )
    if s.get("rule_counts"):
        add("按规则: %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(s["rule_counts"].items())))
    add("结论: %s" % ("全部通过" if s["errors"] == 0 else "存在 %d 项 error, 需修复" % s["errors"]))
    add("=" * 78)
    return "\n".join(lines)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="verify_assets.py",
        description="逐张校验像素素材 PNG 导出图是否符合规格 (尺寸/RGBA/透明背景/硬边/调色板/命名/manifest)。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("assets_dir", help="素材目录 (递归扫描 *.png)")
    p.add_argument("--manifest", default=None, help="可选: assets.manifest.json 路径 (用于尺寸与文件对账)")
    p.add_argument("--json-out", default=None, help="可选: 把 JSON 报告写到该路径")
    p.add_argument("--shadow-hex", default=DEFAULT_SHADOW_HEX, help="阴影色, 默认 #1A1A20")
    p.add_argument("--alpha-min", type=int, default=DEFAULT_ALPHA_MIN, help="半透明 alpha 下限, 默认 64")
    p.add_argument("--alpha-max", type=int, default=DEFAULT_ALPHA_MAX, help="半透明 alpha 上限, 默认 102")
    p.add_argument("--alpha-tol", type=int, default=DEFAULT_ALPHA_TOL, help="alpha 容差, 默认 8")
    p.add_argument("--max-colors", type=int, default=DEFAULT_MAX_COLORS, help="不透明唯一颜色上限, 默认 12")
    p.add_argument(
        "--allow-suffix",
        default="_strip",
        help="文件名特殊后缀白名单(逗号分隔), 默认 _strip —— 对应项目既有约定"
             " game/pixel-anim 的 <name>_strip.png, 含下划线故需显式放行",
    )
    p.add_argument("--no-json-stdout", action="store_true", help="不把 JSON 打印到 stdout")
    return p


def main(argv: list[str]) -> int:
    args = build_arg_parser().parse_args(argv)

    try:
        shadow_rgb = parse_hex_color(args.shadow_hex)
    except ValueError as exc:
        sys.stderr.write("参数错误: %s\n" % exc)
        return 2

    alpha_lo = max(0, args.alpha_min - abs(args.alpha_tol))
    alpha_hi = min(255, args.alpha_max + abs(args.alpha_tol))

    assets_dir = Path(args.assets_dir).expanduser()
    if not assets_dir.exists():
        sys.stderr.write("错误: 素材目录不存在: %s\n" % assets_dir)
        return 2
    if not assets_dir.is_dir():
        sys.stderr.write("错误: 不是目录: %s\n" % assets_dir)
        return 2

    # manifest
    manifest_path = Path(args.manifest).expanduser() if args.manifest else None
    manifest_error = None
    entries: list[dict] = []
    if manifest_path is not None:
        if not manifest_path.exists():
            sys.stderr.write("错误: manifest 不存在: %s\n" % manifest_path)
            return 2
        entries, manifest_error = load_manifest(manifest_path)
    else:
        auto = assets_dir / "assets.manifest.json"
        if auto.exists():
            manifest_path = auto
            entries, manifest_error = load_manifest(auto)

    # manifest 索引: 相对路径 -> 条目
    manifest_index: dict[str, dict] = {}
    duplicate_entries: list[str] = []
    for e in entries:
        key = norm_rel(Path(e["path"]))
        if key in manifest_index:
            duplicate_entries.append(key)
            continue
        manifest_index[key] = e

    pngs = collect_pngs(assets_dir)

    results = []
    for p in pngs:
        rel = norm_rel(p.relative_to(assets_dir))
        entry = manifest_index.get(rel)
        expected = None
        source = None
        if entry is not None and entry.get("w") and entry.get("h"):
            expected = (entry["w"], entry["h"])
            source = "manifest"
        if expected is None:
            expected = size_from_name(p.name)
            source = "filename" if expected else None
        kind = entry.get("kind") if isinstance(entry, dict) else None
        results.append(
            check_file(
                p,
                assets_dir,
                expected,
                source or "n/a",
                shadow_rgb,
                alpha_lo,
                alpha_hi,
                args.max_colors,
                tuple(s for s in (args.allow_suffix or "").split(",") if s),
                kind,
            )
        )

    # ---- R7 manifest 对账 ----
    manifest_check = None
    if manifest_path is not None:
        disk_set = {norm_rel(p.relative_to(assets_dir)) for p in pngs}
        missing_on_disk = []
        for key, e in manifest_index.items():
            if key.lower() not in {k.lower() for k in disk_set}:
                missing_on_disk.append(key)
        lower_disk = {k.lower(): k for k in disk_set}
        orphans = []
        for key in manifest_index:
            lower_disk.pop(key.lower(), None)
        orphans = sorted(lower_disk.values())
        manifest_check = {
            "manifest": str(manifest_path),
            "manifest_entries": len(manifest_index),
            "png_on_disk": len(pngs),
            "missing_on_disk": sorted(missing_on_disk),
            "orphans": orphans,
            "skipped_duplicates": sorted(set(duplicate_entries)),
            "error": manifest_error,
        }
        if manifest_error:
            results.append(
                {
                    "path": "(manifest)",
                    "status": "fail",
                    "expected_size": None,
                    "expected_size_source": None,
                    "actual_size": None,
                    "mode": None,
                    "stats": {},
                    "issues": [issue("R7", SEVERITY_ERROR, "manifest_unparsable", manifest_error)],
                }
            )
        for path in sorted(missing_on_disk):
            results.append(
                {
                    "path": path,
                    "status": "fail",
                    "expected_size": None,
                    "expected_size_source": None,
                    "actual_size": None,
                    "mode": None,
                    "stats": {},
                    "issues": [
                        issue("R7", SEVERITY_ERROR, "manifest_missing_file", "manifest 指向的文件在磁盘上不存在")
                    ],
                }
            )
        for path in orphans:
            hit = next((r for r in results if r["path"].lower() == path.lower()), None)
            target = hit if hit is not None else None
            if target is None:
                results.append(
                    {
                        "path": path,
                        "status": "fail",
                        "expected_size": None,
                        "expected_size_source": None,
                        "actual_size": None,
                        "mode": None,
                        "stats": {},
                        "issues": [],
                    }
                )
                target = results[-1]
            target["issues"].append(
                issue("R7", SEVERITY_ERROR, "manifest_orphan", "磁盘上的 PNG 未出现在 manifest 中")
            )
            if target["status"] == "pass" and any(
                i["level"] == SEVERITY_ERROR for i in target["issues"]
            ):
                target["status"] = "fail"

    # ---- 汇总 ----
    errors = sum(1 for r in results for i in r["issues"] if i["level"] == SEVERITY_ERROR)
    warnings = sum(1 for r in results for i in r["issues"] if i["level"] == SEVERITY_WARNING)
    failed = sum(1 for r in results if r["status"] == "fail")
    passed = sum(1 for r in results if r["status"] == "pass")
    rule_counts: dict[str, int] = {}
    for r in results:
        for i in r["issues"]:
            rule_counts[i["rule"]] = rule_counts.get(i["rule"], 0) + 1

    report = {
        "tool": "verify_assets.py",
        "version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "assets_dir": str(assets_dir),
        "manifest": str(manifest_path) if manifest_path else None,
        "thresholds": {
            "shadow_hex": "#%02X%02X%02X" % shadow_rgb,
            "semi_alpha_range": [alpha_lo, alpha_hi],
            "alpha_base_range": [args.alpha_min, args.alpha_max],
            "alpha_tolerance": args.alpha_tol,
            "max_opaque_colors": args.max_colors,
        },
        "summary": {
            "total": len(results),
            "passed": passed,
            "failed": failed,
            "errors": errors,
            "warnings": warnings,
            "rule_counts": rule_counts,
        },
        "files": results,
        "manifest_check": manifest_check,
    }

    text = render_text_report(report, shadow_rgb, alpha_lo, alpha_hi, args.max_colors)
    print(text)

    payload = json.dumps(report, ensure_ascii=False, indent=2)
    if args.json_out:
        out = Path(args.json_out).expanduser()
        try:
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(payload + "\n", encoding="utf-8")
            print("[json] 已写入: %s" % out)
        except OSError as exc:
            sys.stderr.write("错误: 无法写入 JSON 报告: %s\n" % exc)
            return 2

    if not args.no_json_stdout:
        print("--- JSON ---")
        print(payload)

    if not pngs and manifest_check is None:
        sys.stderr.write("错误: 目录下没有 .png 文件: %s\n" % assets_dir)
        return 2

    return 1 if errors > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
