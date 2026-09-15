/**
 * Integration check for the Pixel Vault site: launch headless Chrome, load the
 * site, click the "像素植物" sidebar entry, then read back what actually
 * rendered and capture a screenshot as evidence.
 *
 * Usage: node integration_shot.mjs <url> <outPng> <profileDir>
 */
import { spawn } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";

const URL_ = process.argv[2] || "http://127.0.0.1:8765/index.html";
const OUT = process.argv[3] || "integration.png";
const PROFILE = process.argv[4] || ".openclaw/tmp/chrome-profile";
const CHROME = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const PORT = 9222;

mkdirSync(PROFILE, { recursive: true });

const chrome = process.env.SKIP_LAUNCH
  ? null
  : spawn(CHROME, [
      "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
      "--disable-extensions", "--hide-scrollbars", "--mute-audio",
      `--remote-debugging-port=${PORT}`, `--user-data-dir=${PROFILE}`,
      "--window-size=1500,1250", "about:blank",
    ], { stdio: "ignore" });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function targetWs() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const list = await res.json();
      const page = list.find((t) => t.type === "page");
      if (page && page.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
    } catch { /* not up yet */ }
    await sleep(500);
  }
  throw new Error("chrome devtools endpoint never came up");
}

class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.pending = new Map(); this.events = []; 
    ws.addEventListener("message", (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id && this.pending.has(m.id)) { this.pending.get(m.id)(m); this.pending.delete(m.id); }
      else this.events.push(m);
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((res) => this.pending.set(id, res));
  }
}

const wsUrl = await targetWs();
const ws = new WebSocket(wsUrl);
await new Promise((r, j) => { ws.addEventListener("open", r); ws.addEventListener("error", j); });
const cdp = new CDP(ws);

await cdp.send("Page.enable");
await cdp.send("Runtime.enable");
await cdp.send("Page.navigate", { url: URL_ });
await sleep(3500);

const evalJs = async (expr) => {
  const r = await cdp.send("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
};

const report = {};
report.title = await evalJs("document.title");
report.heroLine = await evalJs("(document.getElementById('hero-line')||{}).textContent");
report.stats = await evalJs("[...document.querySelectorAll('#stats .stat')].map(e=>e.innerText.replace(/\\n/g,' '))");
report.hasPlantsEntry = await evalJs(`!!document.querySelector('[data-sub="game/pixel-plants"]')`);
report.subEntries = await evalJs(`[...document.querySelectorAll('[data-sub]')].map(e=>e.dataset.sub)`);

// click into the plants category
await evalJs(`(()=>{const el=document.querySelector('[data-sub="game/pixel-plants"]'); if(el){el.click(); return true;} return false;})()`);
await sleep(2500);

report.afterClick_activeSub = await evalJs(`(document.querySelector('[data-sub="game/pixel-plants"]')||{}).className`);
report.renderedPlantImgs = await evalJs(`[...document.images].filter(i=>i.src.includes('game/pixel-plants')).length`);
report.loadedPlantImgs = await evalJs(`[...document.images].filter(i=>i.src.includes('game/pixel-plants') && i.complete && i.naturalWidth>0).length`);
report.brokenPlantImgs = await evalJs(`[...document.images].filter(i=>i.src.includes('game/pixel-plants') && i.complete && i.naturalWidth===0).length`);
report.gridCount = await evalJs(`document.querySelectorAll('#grid > *').length`);

const shot = await cdp.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: true });
writeFileSync(OUT, Buffer.from(shot.result.data, "base64"));
report.screenshot = OUT;

console.log(JSON.stringify(report, null, 2));
ws.close();
if (chrome) chrome.kill();
