const el = document.querySelector('[data-sub="game/pixel-plants"]');
if (el) el.click();
await new Promise(r => setTimeout(r, 2000));

for (let y = 0; y < document.body.scrollHeight; y += 700) {
  window.scrollTo(0, y);
  await new Promise(r => setTimeout(r, 260));
}
window.scrollTo(0, 0);
await new Promise(r => setTimeout(r, 2500));

const all = [...document.images].filter(i => i.src.includes('game/pixel-plants'));
const hist = {};
for (const i of all) {
  const k = i.naturalWidth + 'x' + i.naturalHeight;
  hist[k] = (hist[k] || 0) + 1;
}
return {
  total: all.length,
  loaded: all.filter(i => i.complete && i.naturalWidth > 0).length,
  broken: all.filter(i => i.complete && i.naturalWidth === 0).length,
  stillPending: all.filter(i => !i.complete).length,
  naturalSizeHistogram: hist,
};
