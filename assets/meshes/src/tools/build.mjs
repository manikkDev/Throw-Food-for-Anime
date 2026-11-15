// Build gear/food models: Kiln program -> Kiln GLB -> Roblox GLB -> measurements.
//
//   node assets/meshes/src/tools/build.mjs gear Equip_wooden_dummy [more names...]
//   node assets/meshes/src/tools/build.mjs foods all
//
// Programs are authored in the Roblox frame in studs (see the header in every
// program), so the converter runs with --studs-per-m 1. Every number written to
// <name>.measure.json is read back from the exported GLB, never typed.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GAME = path.resolve(HERE, '../../../..');
const KILN_HOME = process.env.KILN_HOME;
const SKILL = path.join(process.env.USERPROFILE || process.env.HOME, '.claude/skills/roblox-3d-model/scripts/kiln_to_roblox.mjs');
const req = createRequire(path.join(KILN_HOME, 'package.json'));
const { NodeIO } = req('@gltf-transform/core');
const { KHRONOS_EXTENSIONS } = req('@gltf-transform/extensions');

const kit = JSON.parse(fs.readFileSync(path.join(GAME, 'design/kit.json'), 'utf8'));
const [kind, ...names0] = process.argv.slice(2);
const table = kind === 'gear' ? kit.gear : kit.foods;
const names = names0[0] === 'all' ? Object.keys(table).filter((k) => k !== 'note') : names0;

const lin2srgb = (c) => (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);
const hex = (rgb) => rgb.map((c) => Math.round(Math.min(1, Math.max(0, lin2srgb(c))) * 255).toString(16).padStart(2, '0')).join('').toUpperCase();

async function measure(glbPath) {
  const io = new NodeIO().registerExtensions(KHRONOS_EXTENSIONS);
  const doc = await io.read(glbPath);
  const parts = [];
  for (const node of doc.getRoot().listNodes()) {
    const mesh = node.getMesh();
    if (!mesh) continue;
    for (const p of mesh.listPrimitives()) {
      const m = p.getMaterial();
      const idx = p.getIndices();
      const tris = (idx ? idx.getCount() : p.getAttribute('POSITION').getCount()) / 3;
      const name = m?.getName() || '';
      const named = (name.match(/_([0-9A-F]{6})$/) || [])[1] || null;
      const factor = m ? hex(m.getBaseColorFactor().slice(0, 3)) : null;
      const em = m ? m.getEmissiveFactor() : [0, 0, 0];
      parts.push({ mesh: node.getName(), material: name, hex_in_name: named, hex_base_color_srgb: factor, colour_match: named === factor, emissive: em.some((v) => v > 0) ? hex(em) : null, tris, verts: p.getAttribute('POSITION').getCount() });
    }
  }
  return parts;
}

const out = [];
for (const name of names) {
  const sub = kind === 'gear' ? 'gear' : 'foods';
  const src = path.join(GAME, 'assets/meshes/src', sub, `${name}.kiln.js`);
  const work = path.join(GAME, 'work/models', sub);
  fs.mkdirSync(work, { recursive: true });
  const kglb = path.join(work, `${name}.kiln.glb`);
  const kpng = path.join(work, `${name}.kiln.png`);
  const rglb = path.join(GAME, 'assets/meshes', sub, `${name}.glb`);
  const t0 = Date.now();
  let receipt;
  try {
    const raw = execFileSync(process.execPath, [path.join(KILN_HOME, 'node_modules/@kiln/engine/dist/cli.mjs'), 'render', src, '--out', kglb, '--views', kpng, '--backdrop', 'light', '--render', 'cpu', '--json'], { cwd: work, encoding: 'utf8', maxBuffer: 64 << 20 });
    receipt = JSON.parse(raw);
  } catch (e) {
    console.error(`[${name}] KILN FAILED\n${e.stdout || ''}\n${e.stderr || e.message}`);
    process.exitCode = 1;
    continue;
  }
  fs.writeFileSync(path.join(work, `${name}.kiln.json`), JSON.stringify(receipt, null, 1));
  const qa = receipt.qaReport || {};
  const findings = [];
  for (const [dim, d] of Object.entries(qa.dimensions || {})) for (const f of d.findings || []) if (f.disposition !== 'observe') findings.push(`${dim}:${f.code}:${f.disposition}:${f.message}`);
  // The converter's flatten/prune step logs a line ("prune: Removed types...") before its JSON.
  const convRaw = execFileSync(process.execPath, [SKILL, kglb, rglb, '--studs-per-m', '1'], { encoding: 'utf8' });
  const conv = JSON.parse(convRaw.slice(convRaw.indexOf('{')));
  const parts = await measure(rglb);
  const target = table[name]?.size || null;
  const size = conv.sizeStuds;
  const dev = target ? size.map((v, i) => +(((v - target[i]) / target[i]) * 100).toFixed(1)) : null;
  const tris = parts.reduce((a, p) => a + p.tris, 0);
  const budget = kind === 'gear' ? kit.budgets_tris.gear : kit.budgets_tris.food;
  const rec = {
    name, kind: sub, path: path.relative(GAME, rglb).replaceAll('\\', '/'), tris, budget_tris: budget, within_budget: tris <= budget,
    bounds_studs: size, bounds_min: conv.boundsStuds.min, bounds_max: conv.boundsStuds.max, target_studs: target, deviation_pct: dev,
    within_10pct: dev ? dev.every((d) => Math.abs(d) <= 10) : null,
    colour_parts: parts.map((p) => p.hex_in_name), colours_match_names: parts.every((p) => p.colour_match), parts,
    kiln_qa: { acceptance: qa.acceptance, disposition: qa.disposition, non_observe_findings: findings, warnings: (receipt.warnings || []).length },
    seconds: +((Date.now() - t0) / 1000).toFixed(1),
  };
  fs.writeFileSync(path.join(work, `${name}.measure.json`), JSON.stringify(rec, null, 1));
  out.push(rec);
  console.log(`${name}: tris ${tris}/${budget} size [${size.join(', ')}] target [${target}] dev% [${dev}] min [${conv.boundsStuds.min}] colours ${parts.map((p) => p.hex_in_name + (p.colour_match ? '' : '!=' + p.hex_base_color_srgb)).join(' ')} qa ${qa.disposition}${findings.length ? ' FINDINGS ' + findings.join(' | ') : ''} (${rec.seconds}s)`);
}
