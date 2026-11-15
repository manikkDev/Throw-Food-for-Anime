// Collect every work/models/*/<name>.measure.json (numbers read from the exported GLB)
// plus the eyes-on review in src/review.json into assets/meshes/manifest_gear_foods.json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const HERE = path.dirname(fileURLToPath(import.meta.url));
const GAME = path.resolve(HERE, '../../../..');
const review = JSON.parse(fs.readFileSync(path.join(HERE, '..', 'review.json'), 'utf8'));
const assets = [];
for (const sub of ['gear', 'foods']) {
  const dir = path.join(GAME, 'work/models', sub);
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.measure.json')).sort()) {
    const m = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const r = review[m.name] || {};
    const icon = sub === 'foods' ? `assets/ui/food_icons/${m.name}.png` : null;
    assets.push({
      name: m.name, kind: sub, path: m.path, source: `assets/meshes/src/${sub}/${m.name}.kiln.js`, tier: 3, route: 'kiln',
      tris: m.tris, budget_tris: m.budget_tris, bounds_studs: m.bounds_studs, target_studs: m.target_studs, deviation_pct: m.deviation_pct,
      colour_parts: m.colour_parts, colours_read_back_match: m.colours_match_names,
      meshparts: m.parts.map((p) => ({ name: p.mesh, hex: p.hex_in_name, tris: p.tris })),
      icon: icon && fs.existsSync(path.join(GAME, icon)) ? icon : null,
      verified: r.verified === true, gates: r.gates || null, notes: r.notes || '',
      ids: { modelId: null, meshId: null, textureId: null },
    });
  }
}
const out = {
  generated: new Date().toISOString(),
  frame: 'Roblox: studs, +Y up, front -Z. Gear min y = 0 centred on x,z; foods centred on bounds centre (grip).',
  colour: 'No textures. One mesh per colour, named Label_RRGGBB; set MeshPart.Color from the hex. textureId is not applicable.',
  collision: 'Set CollisionFidelity on import: gear Box or Hull (default mesh collision is precise and expensive); foods CanCollide=false while held/thrown or Box.',
  ids_note: 'Nothing uploaded. modelId/meshId are filled by the publishing thread; CreateMeshPartAsync needs the meshId as a STRING.',
  assets,
};
fs.writeFileSync(path.join(GAME, 'assets/meshes/manifest_gear_foods.json'), JSON.stringify(out, null, 1));
console.log(`manifest: ${assets.length} assets, verified ${assets.filter((a) => a.verified).length}`);
