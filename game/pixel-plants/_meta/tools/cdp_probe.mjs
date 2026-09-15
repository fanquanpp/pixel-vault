/**
 * Reusable CDP probe: navigate, evaluate an expression, print the value.
 * Usage: node cdp_probe.mjs <url> <exprFile> [waitMs]
 */
import { readFileSync } from "node:fs";

const URL_ = process.argv[2];
const EXPR = readFileSync(process.argv[3], "utf8");
const WAIT = Number(process.argv[4] || 3500);
const PORT = 9222;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = list.find((t) => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r, j) => { ws.addEventListener("open", r); ws.addEventListener("error", j); });

let id = 0;
const pending = new Map();
ws.addEventListener("message", (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
});
const send = (method, params = {}) => {
  const i = ++id;
  ws.send(JSON.stringify({ id: i, method, params }));
  return new Promise((res) => pending.set(i, res));
};

await send("Page.enable");
await send("Runtime.enable");
await send("Page.navigate", { url: URL_ });
await sleep(WAIT);
const r = await send("Runtime.evaluate", {
  expression: `(async()=>{${EXPR}})()`, returnByValue: true, awaitPromise: true,
});
console.log(JSON.stringify(r.result?.result?.value ?? r.result, null, 2));
ws.close();
