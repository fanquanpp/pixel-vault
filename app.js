/* Pixel Vault v2 — manifest-driven gallery
   operations: sort / density / theme / filters / search
   interaction: swipe, zoom, focus trap, preloading
   animation: skeletons, stagger, count-up (reduced-motion aware) */
"use strict";

const $ = (id) => document.getElementById(id);
let MANIFEST = null;
const view = {
  sub: null, filter: "all", q: "", sort: "name",
  density: localStorage.getItem("pv-density") || "m",
};
let currentList = [];
let currentIdx = -1;
let searchTimer = 0;
let lbPushed = false;
let drawerPushed = false;

/* ---------- helpers ---------- */
const human = (b) => b < 1024 ? b + " B" : b < 1048576 ? Math.round(b / 1024) + " KB" : (b / 1048576).toFixed(2) + " MB";
const encodePath = (p) => p.split("/").map(encodeURIComponent).join("/");
/* 目录中文名，缺失时回退为路径段 */
const SUB_LABELS = {
  "avatars/01-computing-software": "计算机软件",
  "avatars/02-electronics": "电子信息",
  "avatars/03-mechatronics": "机械自动化",
  "avatars/04-civil-architecture": "土木建筑",
  "avatars/05-medical-health": "医学健康",
  "avatars/06-econ-management": "经济管理",
  "avatars/07-humanities-law": "人文法学",
  "avatars/08-education-sports": "教育体育",
  "avatars/09-natural-science": "理学",
  "avatars/10-art-design": "艺术设计",
  "avatars/11-public-service": "公共服务",
  "avatars/legacy-black": "旧版黑白",
  "game/bianqv": "bianqv 素材",
  "game/pixel-tiles": "像素地贴",
  "game/pixel-ui-pack": "像素 UI 包",
  "game/pixel-ui-pack-hd": "高清 UI 包",
  "game/pixel-anim": "动画帧条",
  "game/speed-rouge": "平台跳跃素材",
  "icons/file-icons": "文件图标",
  "icons/speed-rouge": "平台跳跃图标",
  "icons/vector": "矢量图标",
  "branding/bianqv": "bianqv 品牌",
  "branding/site": "站点品牌",
};
const subLabel = (id) => SUB_LABELS[id] || id.split("/").slice(1).join("/");

/* ---------- boot ---------- */
async function boot() {
  // a reload while an overlay was open leaves a stale history state behind
  if (history.state && history.state.pv) history.replaceState(null, "");
  buildSkeleton(16);
  applyDensity();
  const res = await fetch("manifest.json");
  MANIFEST = await res.json();
  removeSkeleton();
  countUpStats();
  buildTree();
  bind();
  render();
}

function buildSkeleton(n) {
  const sk = $("skeleton");
  sk.innerHTML = Array.from({ length: n }, () => '<div class="sk"></div>').join("");
}
function removeSkeleton() { $("skeleton").remove(); }

/* animated stat counters */
function countUpStats() {
  const targets = [
    [MANIFEST.total, "可见素材"],
    [MANIFEST.sourceCount, "Aseprite 源文件"],
    [MANIFEST.counts.avatars, "专业头像"],
    [null, "总大小", human(MANIFEST.totalBytes)],
  ];
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  $("stats").innerHTML = targets.map(([v, l, fixed]) => {
    if (fixed) return `<div class="stat"><b>${fixed}</b><span>${l}</span></div>`;
    return `<div class="stat"><b data-target="${v}">0</b><span>${l}</span></div>`;
  }).join("");
  if (reduce) {
    document.querySelectorAll(".stat b[data-target]").forEach((b) => (b.textContent = b.dataset.target));
    return;
  }
  document.querySelectorAll(".stat b[data-target]").forEach((b) => {
    const t = +b.dataset.target, t0 = performance.now();
    (function tick(now) {
      const p = Math.min((now - t0) / 700, 1);
      b.textContent = Math.round(t * (1 - Math.pow(1 - p, 3)));
      if (p < 1) requestAnimationFrame(tick);
    })(t0);
  });
}

/* ---------- sidebar tree ---------- */
function buildTree() {
  const tree = $("tree");
  let html = "";
  for (const cat of Object.keys(MANIFEST.subs)) {
    html += `<div class="tcat">${MANIFEST.catLabels[cat] || cat}</div>`;
    for (const s of MANIFEST.subs[cat]) {
      html += `<button class="tsub" data-sub="${s.id}"><span>${subLabel(s.id)}</span><span class="n">${s.count}</span></button>`;
    }
  }
  tree.innerHTML = html;
  tree.addEventListener("click", (e) => {
    const item = e.target.closest(".tsub");
    if (!item) return;
    const wasActive = item.classList.contains("active");
    document.querySelectorAll(".tsub").forEach((n) => n.classList.remove("active"));
    view.sub = wasActive ? null : item.dataset.sub;
    if (!wasActive) item.classList.add("active");
    closeDrawer();
    render();
  });
}

/* ---------- filtering / sorting ---------- */
function matches(a) {
  if (view.sub && a.sub !== view.sub) return false;
  if (view.filter === "png" && a.type !== "png") return false;
  if (view.filter === "svg" && a.type !== "svg") return false;
  if (view.filter === "src" && !a.source) return false;
  if (view.q && !((a.name + " " + a.path + " " + (SUB_LABELS[a.sub] || "")).toLowerCase().includes(view.q))) return false;
  return true;
}
function sorted(list) {
  const s = view.sort;
  return [...list].sort((a, b) => {
    if (s === "size") return b.bytes - a.bytes;
    if (s === "dim") return (b.w || 0) * (b.h || 0) - (a.w || 0) * (a.h || 0);
    if (s === "cat") return a.sub.localeCompare(b.sub) || a.name.localeCompare(b.name);
    return a.name.localeCompare(b.name);
  });
}

function render() {
  currentList = sorted(MANIFEST.assets.filter(matches));
  const head = $("cat-head");
  if (view.sub) {
    const cat = view.sub.split("/")[0];
    head.innerHTML = `<h2>${subLabel(view.sub)}</h2><p>${MANIFEST.catLabels[cat] || cat} · ${currentList.length} 项</p>`;
  } else if (view.q) {
    head.innerHTML = `<h2>搜索 “${view.q}”</h2><p>${currentList.length} 项匹配</p>`;
  } else {
    head.innerHTML = `<h2>全部素材</h2><p>${currentList.length} 项 · MIT 协议 · 可自由使用</p>`;
  }
  const grid = $("grid");
  grid.innerHTML = currentList.map((a, i) => {
    const dims = a.w ? `${a.w}×${a.h}` : "矢量";
    const svgAttr = a.type === "svg" ? ' data-svg="1"' : "";
    return `<div class="card" data-i="${i}" style="animation-delay:${Math.min(i * 10, 200)}ms" tabindex="0" role="button" aria-label="${a.name}">
      <div class="prev ${a.type === "png" && a.w <= 512 ? "checker" : ""}">
        <img loading="lazy" decoding="async" src="${encodePath(a.path)}" alt="${a.name}"${svgAttr}>
        <a class="quick-dl" href="${encodePath(a.path)}" download title="快速下载">↓</a>
      </div>
      <div class="bar">
        <span class="nm">${a.name}</span>
        <span class="dm">${dims}</span>
        ${a.source ? '<span class="src-badge" title="含 Aseprite 源文件"></span>' : ""}
      </div>
    </div>`;
  }).join("");
  $("empty").hidden = currentList.length > 0;
}

/* ---------- theme / density ---------- */
function applyDensity() {
  document.documentElement.dataset.density = view.density;
  document.querySelectorAll("#density button").forEach((b) =>
    b.classList.toggle("active", b.dataset.d === view.density));
}

/* ---------- lightbox ---------- */
function openLightbox(i) {
  currentIdx = i;
  const a = currentList[i];
  if (!a) return;
  const img = $("lb-img");
  img.src = encodePath(a.path);
  img.classList.remove("zoomed");
  // small pixel art: upscale for visibility
  if (a.w && a.w <= 64) img.style.width = `min(78%, ${a.w * 7}px)`;
  else img.style.width = "";
  if (a.type === "svg") img.setAttribute("data-svg", "1"); else img.removeAttribute("data-svg");
  $("lb-name").textContent = a.name;
  $("lb-badge").textContent = a.type.toUpperCase();
  $("lb-badge").style.background = { png: "var(--green)", svg: "var(--gold)", ico: "var(--muted)" }[a.type] || "var(--muted)";
  $("lb-path").textContent = a.path;
  $("lb-dims").textContent = a.w ? `${a.w} × ${a.h} px` : "矢量";
  $("lb-size").textContent = human(a.bytes);
  $("lb-counter").textContent = `${i + 1} / ${currentList.length}`;
  $("lb-download").href = encodePath(a.path);
  const src = $("lb-src");
  if (a.source) { src.hidden = false; src.href = encodePath(a.source); } else src.hidden = true;
  $("lightbox").hidden = false;
  document.body.style.overflow = "hidden";
  $("lb-close").focus();
  // back gesture / Esc share one history entry per open
  if (!lbPushed) { history.pushState({ pv: "lightbox" }, ""); lbPushed = true; }
  // preload neighbors
  [i - 1, i + 1].forEach((j) => {
    const n = currentList[(j + currentList.length) % currentList.length];
    if (n) new Image().src = encodePath(n.path);
  });
}
function closeLightbox(fromPop) {
  $("lightbox").hidden = true;
  document.body.style.overflow = "";
  if (lbPushed && !fromPop) { lbPushed = false; history.back(); return; }
  lbPushed = false;
}
function step(d) {
  if (currentIdx < 0 || !currentList.length) return;
  openLightbox((currentIdx + d + currentList.length) % currentList.length);
}

/* focus trap inside a container (lightbox / mobile drawer) */
function trapFocusIn(container, e) {
  const focusables = container.querySelectorAll("button, a[href], input, select");
  if (!focusables.length) return;
  const first = focusables[0], last = focusables[focusables.length - 1];
  if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); }
  else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); }
}

/* ---------- bindings ---------- */
function bind() {
  // grid interactions
  $("grid").addEventListener("click", (e) => {
    const dl = e.target.closest(".quick-dl");
    if (dl) return; // let download proceed
    const card = e.target.closest(".card");
    if (card) openLightbox(+card.dataset.i);
  });
  $("grid").addEventListener("keydown", (e) => {
    if (e.key !== "Enter" && e.key !== " ") return;
    const card = e.target.closest(".card");
    if (card) { e.preventDefault(); openLightbox(+card.dataset.i); }
  });

  // filters / search / sort
  document.querySelectorAll(".fbtn").forEach((b) =>
    b.addEventListener("click", () => {
      document.querySelectorAll(".fbtn").forEach((n) => n.classList.toggle("active", n === b));
      view.filter = b.dataset.f;
      render();
    }));
  $("search").addEventListener("input", (e) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { view.q = e.target.value.trim().toLowerCase(); render(); }, 150);
  });
  $("sort").addEventListener("change", (e) => { view.sort = e.target.value; render(); });

  // density
  $("density").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    view.density = b.dataset.d;
    localStorage.setItem("pv-density", view.density);
    applyDensity();
  });

  // theme
  $("theme-toggle").addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem("pv-theme", next); } catch (e) {}
  });

  // mobile drawer
  $("navtoggle").addEventListener("click", openDrawer);
  $("scrim").addEventListener("click", () => closeDrawer());

  // lightbox controls
  document.querySelectorAll("[data-close]").forEach((n) => n.addEventListener("click", () => closeLightbox()));
  $("lb-prev").addEventListener("click", () => step(-1));
  $("lb-next").addEventListener("click", () => step(1));
  $("lb-img").addEventListener("click", () => $("lb-img").classList.toggle("zoomed"));
  $("lb-zoom").addEventListener("click", () => $("lb-img").classList.toggle("zoomed"));
  $("lb-copy").addEventListener("click", async () => {
    const a = currentList[currentIdx];
    try {
      await navigator.clipboard.writeText(a.path);
      $("lb-copy").textContent = "已复制";
      setTimeout(() => ($("lb-copy").textContent = "复制路径"), 1200);
    } catch { $("lb-copy").textContent = a.path; }
  });
  document.addEventListener("keydown", (e) => {
    const lbOpen = !$("lightbox").hidden;
    const drawerOpen = $("sidebar").classList.contains("open");
    if (lbOpen) {
      if (e.key === "Escape") closeLightbox();
      else if (e.key === "ArrowLeft") step(-1);
      else if (e.key === "ArrowRight") step(1);
      else if (e.key === "Tab") trapFocusIn($("lightbox"), e);
    } else if (drawerOpen) {
      if (e.key === "Escape") closeDrawer();
      else if (e.key === "Tab") trapFocusIn($("sidebar"), e);
    }
  });

  // hardware / browser back closes the lightbox or drawer instead of leaving the page
  window.addEventListener("popstate", () => {
    if (!$("lightbox").hidden) closeLightbox(true);
    else if ($("sidebar").classList.contains("open")) closeDrawer(true);
  });

  // touch swipe on stage
  let sx = 0, sy = 0;
  $("lb-stage").addEventListener("touchstart", (e) => { sx = e.touches[0].clientX; sy = e.touches[0].clientY; }, { passive: true });
  $("lb-stage").addEventListener("touchend", (e) => {
    const dx = e.changedTouches[0].clientX - sx;
    const dy = e.changedTouches[0].clientY - sy;
    if (Math.abs(dx) > 48 && Math.abs(dx) > Math.abs(dy)) step(dx > 0 ? -1 : 1);
  }, { passive: true });
}

function openDrawer() {
  $("sidebar").classList.add("open");
  $("scrim").hidden = false;
  $("navtoggle").setAttribute("aria-expanded", "true");
  if (!drawerPushed) { history.pushState({ pv: "drawer" }, ""); drawerPushed = true; }
  $("sidebar").focus();
}

function closeDrawer(fromPop) {
  $("sidebar").classList.remove("open");
  $("scrim").hidden = true;
  $("navtoggle").setAttribute("aria-expanded", "false");
  if (drawerPushed && !fromPop) { drawerPushed = false; history.back(); return; }
  drawerPushed = false;
}

boot();
