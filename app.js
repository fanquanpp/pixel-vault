/* Pixel Vault — manifest-driven gallery (vanilla JS, no build) */
"use strict";

const $ = (id) => document.getElementById(id);
let MANIFEST = null;
let view = { sub: null, filter: "all", q: "" };
let currentList = [];
let currentIdx = -1;

function human(bytes) {
  if (bytes < 1024) return bytes + " B";
  if (bytes < 1048576) return Math.round(bytes / 1024) + " KB";
  return (bytes / 1048576).toFixed(2) + " MB";
}

function encodePath(p) {
  return p.split("/").map(encodeURIComponent).join("/");
}

async function boot() {
  const res = await fetch("manifest.json");
  MANIFEST = await res.json();

  // hero stats
  $("stats").innerHTML = [
    [MANIFEST.total, "可见素材 ASSETS"],
    [MANIFEST.sourceCount, "ASE 源文件 SOURCES"],
    [MANIFEST.counts.avatars, "专业头像 AVATARS"],
    [human(MANIFEST.totalBytes), "体积 SIZE"],
  ].map(([v, l]) => `<div class="stat"><b>${v}</b><span>${l}</span></div>`).join("");

  buildTree();
  render();
  bind();
}

function countType(t) {
  return MANIFEST.assets.filter((a) => a.type === t).length;
}

function subLabel(id) {
  const short = id.split("/").slice(1).join("/");
  return short;
}

function buildTree() {
  const tree = $("tree");
  let html = "";
  for (const cat of Object.keys(MANIFEST.subs)) {
    html += `<div class="tcat">${MANIFEST.catLabels[cat] || cat}</div>`;
    for (const s of MANIFEST.subs[cat]) {
      const label = subLabel(s.id);
      html += `<div class="tsub" data-sub="${s.id}"><span>${label}</span><span class="n">${s.count}</span></div>`;
    }
  }
  tree.innerHTML = html;
  tree.addEventListener("click", (e) => {
    const item = e.target.closest(".tsub");
    if (!item) return;
    document.querySelectorAll(".tsub").forEach((n) => n.classList.toggle("active", n === item));
    view.sub = item.dataset.sub;
    render();
  });
}

function matches(a) {
  if (view.sub && a.sub !== view.sub) return false;
  if (view.filter === "png" && a.type !== "png") return false;
  if (view.filter === "svg" && a.type !== "svg") return false;
  if (view.filter === "src" && !a.source) return false;
  if (view.q && !(a.name + " " + a.path).toLowerCase().includes(view.q)) return false;
  return true;
}

function render() {
  const list = MANIFEST.assets.filter(matches);
  currentList = list;

  // heading
  const head = $("cat-head");
  if (view.sub) {
    const cat = view.sub.split("/")[0];
    head.innerHTML = `<h2>${subLabel(view.sub).toUpperCase()}</h2>
      <p>${MANIFEST.catLabels[cat] || cat} · ${list.length} 项</p>`;
  } else if (view.q) {
    head.innerHTML = `<h2>搜索 “${view.q}”</h2><p>${list.length} 项匹配</p>`;
  } else {
    head.innerHTML = `<h2>全部素材 ALL ASSETS</h2><p>${list.length} 项 · MIT License · 可自由使用</p>`;
  }

  const grid = $("grid");
  grid.innerHTML = list
    .map((a, i) => {
      const dims = a.w ? `${a.w}×${a.h}` : "vector";
      const pixelCls = a.type === "svg" ? ' data-svg="1"' : "";
      return `<div class="card" data-i="${i}" style="animation-delay:${Math.min(i * 12, 240)}ms">
        <div class="prev ${a.type === "png" && a.w && a.w <= 512 ? "checker" : ""}">
          <img loading="lazy" src="${encodePath(a.path)}" alt="${a.name}"${pixelCls}>
        </div>
        <div class="bar">
          <span class="nm">${a.name}</span>
          <span class="dm">${dims}</span>
          ${a.source ? '<span class="src-badge" title="含 Aseprite 源文件"></span>' : ""}
        </div>
      </div>`;
    })
    .join("");
  $("empty").hidden = list.length > 0;
}

function openLightbox(i) {
  currentIdx = i;
  const a = currentList[i];
  if (!a) return;
  $("lb-img").src = encodePath(a.path);
  $("lb-img").removeAttribute("data-svg");
  if (a.type === "svg") $("lb-img").setAttribute("data-svg", "1");
  $("lb-name").textContent = a.name;
  $("lb-badge").textContent = a.type.toUpperCase();
  $("lb-badge").style.background = { png: "var(--green)", svg: "var(--gold)" }[a.type] || "var(--muted)";
  $("lb-path").textContent = a.path;
  $("lb-dims").textContent = a.w ? `${a.w} × ${a.h} px` : "vector";
  $("lb-size").textContent = human(a.bytes);
  $("lb-download").href = encodePath(a.path);
  const src = $("lb-src");
  if (a.source) {
    src.hidden = false;
    src.href = encodePath(a.source);
  } else {
    src.hidden = true;
  }
  $("lightbox").hidden = false;
  document.body.style.overflow = "hidden";
}

function closeLightbox() {
  $("lightbox").hidden = true;
  document.body.style.overflow = "";
}

function step(d) {
  if (currentIdx < 0 || !currentList.length) return;
  openLightbox((currentIdx + d + currentList.length) % currentList.length);
}

function bind() {
  $("grid").addEventListener("click", (e) => {
    const card = e.target.closest(".card");
    if (card) openLightbox(+card.dataset.i);
  });
  document.querySelectorAll("[data-close]").forEach((n) => n.addEventListener("click", closeLightbox));
  document.querySelectorAll(".fbtn").forEach((b) =>
    b.addEventListener("click", () => {
      document.querySelectorAll(".fbtn").forEach((n) => n.classList.toggle("active", n === b));
      view.filter = b.dataset.f;
      render();
    })
  );
  $("search").addEventListener("input", (e) => {
    view.q = e.target.value.trim().toLowerCase();
    render();
  });
  $("lb-copy").addEventListener("click", async () => {
    const a = currentList[currentIdx];
    try {
      await navigator.clipboard.writeText(a.path);
      $("lb-copy").textContent = "✓ 已复制";
      setTimeout(() => ($("lb-copy").textContent = "⧉ 复制路径"), 1200);
    } catch {
      $("lb-copy").textContent = a.path;
    }
  });
  $("lb-prev").addEventListener("click", () => step(-1));
  $("lb-next").addEventListener("click", () => step(1));
  document.addEventListener("keydown", (e) => {
    if ($("lightbox").hidden) return;
    if (e.key === "Escape") closeLightbox();
    if (e.key === "ArrowLeft") step(-1);
    if (e.key === "ArrowRight") step(1);
  });
}

boot();
