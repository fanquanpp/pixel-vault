#!/usr/bin/env node
/**
 * Regenerates manifest.json for the Pixel Vault static gallery.
 *
 * Rules (reverse-engineered from the checked-in manifest and verified against
 * the pre-change backup):
 *   - assets  = every .png / .svg under the repo, excluding .git/,
 *               node_modules/, gui-test-screenshots/ and any _meta/ dir
 *               (_meta/ holds pack documentation, not gallery assets)
 *   - type    = extension without the dot
 *   - name    = file stem
 *   - cat     = first path segment; sub = first two segments
 *   - w/h     = PNG IHDR dimensions (omitted for svg)
 *   - source  = sibling <stem>.aseprite, or for a "*_strip.png" animation
 *               strip the <stem without _strip>.aseprite; null otherwise
 *   - counts / subs are derived per category; totalBytes sums asset bytes;
 *               sourceCount counts .aseprite sources on disk
 *
 * Ordering is deterministic: category (avatars, branding, game, icons, then any
 * new category sorted), then sub id, then path. The gallery sorts client-side
 * (app.js view.sort defaults to "name"), so array order is presentational.
 *
 * Usage:
 *   node tools/build-manifest.mjs                       # write manifest.json
 *   node tools/build-manifest.mjs --stdout              # print, do not write
 *   node tools/build-manifest.mjs --exclude <prefix>    # skip a subtree
 *   node tools/build-manifest.mjs --check <ref.json>    # compare content to a reference
 */
import { existsSync, openSync, readSync, closeSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative, extname } from "node:path";

const REPO = process.cwd();
const SKIP_DIRS = new Set([".git", "node_modules", "gui-test-screenshots", "_meta"]);
const ASSET_EXTS = new Set([".png", ".svg"]);
const CAT_ORDER = ["avatars", "branding", "game", "icons"];
const CAT_LABELS = { avatars: "像素专业头像", game: "游戏素材", icons: "图标", branding: "品牌" };

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n, d = null) => {
  const i = args.indexOf(n);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : d;
};
const EXCLUDES = args.reduce((acc, a, i) => {
  if (a === "--exclude" && args[i + 1]) acc.push(args[i + 1].replace(/\\/g, "/"));
  return acc;
}, []);

const posix = (p) => p.split("\\").join("/");

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) {
      if (SKIP_DIRS.has(name)) continue;
      walk(full, out);
    } else if (ASSET_EXTS.has(extname(name).toLowerCase())) {
      out.push(posix(relative(REPO, full)));
    }
  }
  return out;
}

function pngSize(path) {
  const fd = openSync(path, "r");
  try {
    const buf = Buffer.alloc(24);
    if (readSync(fd, buf, 0, 24, 0) < 24) return null;
    if (buf.readUInt32BE(0) !== 0x89504e47) return null; // PNG signature
    return [buf.readUInt32BE(16), buf.readUInt32BE(20)];
  } finally {
    closeSync(fd);
  }
}

function findSource(type, stem, dir) {
  if (type !== "png") return null;
  // Exact <stem>.aseprite first, then progressively drop trailing _segments:
  // the library names derived exports with a suffix (collectibles_v2.png,
  // dash_c1_fast_map.png, run-cycle_strip.png) that all point back to the
  // unsuffixed .aseprite source.
  const names = [stem];
  let s = stem;
  while (s.includes("_")) {
    s = s.slice(0, s.lastIndexOf("_"));
    if (!s) break;
    names.push(s);
  }
  for (const n of names) {
    const rel = dir ? dir + "/" + n + ".aseprite" : n + ".aseprite";
    if (existsSync(join(REPO, rel))) return rel;
  }
  return null;
}

function countAseprite() {
  let n = 0;
  (function rec(dir) {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const st = statSync(full);
      if (st.isDirectory()) {
        if (!SKIP_DIRS.has(name)) rec(full);
      } else if (name.toLowerCase().endsWith(".aseprite")) {
        const rel = posix(relative(REPO, full));
        if (!EXCLUDES.some((ex) => rel === ex || rel.startsWith(ex + "/"))) n++;
      }
    }
  })(REPO);
  return n;
}

function build() {
  let files = walk(REPO);
  for (const ex of EXCLUDES) files = files.filter((f) => !(f === ex || f.startsWith(ex + "/")));
  files.sort();

  const assets = [];
  for (const path of files) {
    const parts = path.split("/");
    const base = parts[parts.length - 1];
    const ext = extname(base).toLowerCase();
    const stem = base.slice(0, -ext.length);
    const type = ext.slice(1);
    const rec = {
      path,
      name: stem,
      type,
      bytes: statSync(join(REPO, path)).size,
      cat: parts[0],
      sub: parts.slice(0, 2).join("/"),
    };
    const src = findSource(type, stem, parts.slice(0, -1).join("/"));
    if (type === "png") {
      const sz = pngSize(join(REPO, path));
      if (sz) {
        rec.w = sz[0];
        rec.h = sz[1];
      }
    }
    rec.source = src;
    assets.push(rec);
  }

  const catRank = (c) => (CAT_ORDER.indexOf(c) < 0 ? CAT_ORDER.length : CAT_ORDER.indexOf(c));
  assets.sort(
    (a, b) =>
      catRank(a.cat) - catRank(b.cat) ||
      a.cat.localeCompare(b.cat) ||
      a.sub.localeCompare(b.sub) ||
      a.path.localeCompare(b.path)
  );

  const cats = [...new Set(assets.map((a) => a.cat))].sort((x, y) => catRank(x) - catRank(y) || x.localeCompare(y));
  const counts = {};
  const subs = {};
  for (const c of cats) {
    counts[c] = assets.filter((a) => a.cat === c).length;
    const ids = [...new Set(assets.filter((a) => a.cat === c).map((a) => a.sub))].sort();
    subs[c] = ids.map((id) => ({ id, count: assets.filter((a) => a.sub === id).length }));
  }

  const catLabels = {};
  for (const c of cats) catLabels[c] = CAT_LABELS[c] || c;

  const distinctSources = new Set(assets.map((a) => a.source).filter(Boolean));
  const onDisk = countAseprite();

  return {
    generated: new Date().toISOString().slice(0, 10),
    license: "MIT",
    repo: "https://github.com/fanquanpp/pixel-vault",
    catLabels,
    total: assets.length,
    totalBytes: assets.reduce((s, a) => s + a.bytes, 0),
    counts,
    sourceCount: onDisk,
    subs,
    assets,
    _debug: { distinctSources: distinctSources.size, asepriteOnDisk: onDisk },
  };
}

const doc = build();
const debug = doc._debug;
delete doc._debug;

if (flag("--check")) {
  const refPath = opt("--check");
  const ref = JSON.parse(readFileSync(refPath, "utf8"));
  const key = (a) => a.path;
  const mine = new Map(doc.assets.map((a) => [key(a), a]));
  const theirs = new Map(ref.assets.map((a) => [key(a), a]));
  const problems = [];
  for (const [p, r] of theirs) {
    const m = mine.get(p);
    if (!m) { problems.push("MISSING-IN-NEW  " + p); continue; }
    for (const k of ["name", "type", "bytes", "cat", "sub", "source"]) {
      if (JSON.stringify(m[k]) !== JSON.stringify(r[k])) problems.push(`FIELD ${k} ${p}: new=${JSON.stringify(m[k])} ref=${JSON.stringify(r[k])}`);
    }
    if (!(m.w === r.w && m.h === r.h)) problems.push(`SIZE ${p}: new=${m.w}x${m.h} ref=${r.w}x${r.h}`);
    if (!("w" in r) !== !("w" in m)) problems.push(`WH-PRESENCE ${p}`);
  }
  for (const p of mine.keys()) if (!theirs.has(p)) problems.push("EXTRA-IN-NEW  " + p);
  for (const k of ["total", "totalBytes", "sourceCount"]) {
    if (doc[k] !== ref[k]) problems.push(`TOTAL ${k}: new=${doc[k]} ref=${ref[k]}`);
  }
  for (const c of new Set([...Object.keys(doc.counts), ...Object.keys(ref.counts)])) {
    if (doc.counts[c] !== ref.counts[c]) problems.push(`COUNT ${c}: new=${doc.counts[c]} ref=${ref.counts[c]}`);
  }
  for (const c of new Set([...Object.keys(doc.subs), ...Object.keys(ref.subs)])) {
    const a = JSON.stringify((doc.subs[c] || []).slice().sort((x, y) => x.id.localeCompare(y.id)));
    const b = JSON.stringify((ref.subs[c] || []).slice().sort((x, y) => x.id.localeCompare(y.id)));
    if (a !== b) problems.push(`SUBS ${c}\n  new=${a}\n  ref=${b}`);
  }
  console.log("check assets: new=%d ref=%d | distinctSources=%d asepriteOnDisk=%d",
    doc.total, ref.total, debug.distinctSources, debug.asepriteOnDisk);
  if (problems.length === 0) {
    console.log("CHECK OK: content identical to reference (order may differ)");
    process.exit(0);
  }
  console.log("CHECK FAILED: %d difference(s)", problems.length);
  for (const p of problems.slice(0, 40)) console.log("  " + p);
  process.exit(1);
}

const json = JSON.stringify(doc);
if (flag("--stdout")) {
  console.log(json);
} else {
  writeFileSync(join(REPO, "manifest.json"), json);
  console.log("wrote manifest.json: total=%d sourceCount=%d totalBytes=%d", doc.total, doc.sourceCount, doc.totalBytes);
  console.log("counts=%s", JSON.stringify(doc.counts));
  for (const c of Object.keys(doc.subs)) console.log("  subs.%s = %s", c, JSON.stringify(doc.subs[c].map((s) => s.id + ":" + s.count)));
}
