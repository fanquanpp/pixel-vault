const el = document.querySelector('[data-sub="game/pixel-plants"]');
if (el) el.click();
await new Promise(r => setTimeout(r, 2500));

const pick = (frag) => [...document.images].find(i => i.src.endsWith(frag));
const info = (i) => i ? { src: i.src.split('/').slice(-1)[0], natural: i.naturalWidth + 'x' + i.naturalHeight,
                          css: Math.round(i.getBoundingClientRect().width) + 'x' + Math.round(i.getBoundingClientRect().height),
                          complete: i.complete, loading: i.loading } : null;

const all = [...document.images].filter(i => i.src.includes('game/pixel-plants'));
const byNatural = {};
for (const i of all) {
  const k = i.naturalWidth + 'x' + i.naturalHeight;
  byNatural[k] = (byNatural[k] || 0) + 1;
}

return {
  totalPlantImgs: all.length,
  broken: all.filter(i => i.complete && i.naturalWidth === 0).length,
  naturalSizeHistogram: byNatural,
  tile32: info(pick('/pu-ti-shu.png')),
  tile16: info(pick('/ling-lan.png')),
  strip: info(pick('/pu-ti-shu-sway_strip.png')),
  strip16: info(pick('/ling-lan-sway_strip.png')),
  sidebarLabel: (document.querySelector('[data-sub="game/pixel-plants"]') || {}).textContent,
  activeFilterText: (document.querySelector('#grid-count, .grid-count, [id*=count]') || {}).textContent || null,
};
