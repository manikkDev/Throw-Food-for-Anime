// Replace the block between the shared-header markers in every program with
// tools/header.js, so all gear/food programs carry the identical helpers.
//   node assets/meshes/src/tools/sync_header.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const header = fs.readFileSync(path.join(HERE, 'header.js'), 'utf8').trimEnd();
const re = /\/\/ ---- shared header[\s\S]*?\/\/ ---- end shared header -*\r?\n/;
for (const sub of ['gear', 'foods']) {
  const dir = path.join(HERE, '..', sub);
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.kiln.js'))) {
    const p = path.join(dir, f);
    const s = fs.readFileSync(p, 'utf8');
    if (!re.test(s)) {
      console.log(`no header markers: ${f}`);
      continue;
    }
    const t = s.replace(re, header + '\n');
    if (t !== s) {
      fs.writeFileSync(p, t);
      console.log(`synced ${f}`);
    }
  }
}
