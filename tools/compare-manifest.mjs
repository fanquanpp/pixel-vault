// Compares two manifest.json files field by field, ignoring "generated".
// Order-sensitive for the assets array and subs lists. Prints every
// difference it finds; exits 0 only when identical apart from generated.
import { readFileSync } from "node:fs";

const [aPath, bPath] = process.argv.slice(2);
const a = JSON.parse(readFileSync(aPath, "utf8"));
const b = JSON.parse(readFileSync(bPath, "utf8"));
delete a.generated;
delete b.generated;

function diff(x, y, at, out) {
  if (x === y) return;
  if (Array.isArray(x) && Array.isArray(y)) {
    if (x.length !== y.length) {
      out.push(`ARRAY-LEN ${at}: a=${x.length} b=${y.length}`);
      return;
    }
    for (let i = 0; i < x.length; i++) diff(x[i], y[i], `${at}[${i}]`, out);
    return;
  }
  if (x && y && typeof x === "object" && typeof y === "object") {
    for (const k of new Set([...Object.keys(x), ...Object.keys(y)])) {
      diff(x[k], y[k], `${at}.${k}`, out);
    }
    return;
  }
  out.push(`VALUE ${at}: a=${JSON.stringify(x)} b=${JSON.stringify(y)}`);
}

const problems = [];
diff(a, b, "root", problems);
if (problems.length === 0) {
  console.log(`IDENTICAL (apart from generated): ${bPath} vs ${aPath}`);
  console.log(`total=${b.total} totalBytes=${b.totalBytes} sourceCount=${b.sourceCount} assets=${b.assets.length}`);
  process.exit(0);
}
console.log(`DIFFERENCES: ${problems.length}`);
for (const p of problems.slice(0, 60)) console.log("  " + p);
process.exit(1);
