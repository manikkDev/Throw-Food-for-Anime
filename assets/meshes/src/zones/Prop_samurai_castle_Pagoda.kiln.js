// Prop_samurai_castle_Pagoda: five-tier pagoda, red pillars, dark curved roofs, gold spire.
// Target (Roblox studs, x/y/z): 16 x 34 x 16, standing on y = 0, front -Z. Budget 6000 tris.
// Same flared hip-roof construction as the CastleKeep, so the two read as one zone.

const meta = { name: 'Prop_samurai_castle_Pagoda', category: 'prop' };

// UNITS: authored in STUDS, converted with `kiln_to_roblox.mjs --studs-per-m 1`.
// Kiln frame: +X forward (becomes Roblox -Z, the front), +Y up, +Z right (becomes Roblox +X).
// So a Roblox size [sx, sy, sz] is Kiln extent Z = sx, Y = sy, X = sz.
// Each colour is unioned into ONE closed mesh (bible: one clean piece per colour),
// and the material name carries the hex the converter names the MeshPart after.

function mat(label, hex) {
  const m = gameMaterial(hex, { roughness: 0.8 });
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
const D = Math.PI / 180;
// raw mesh operand: position, Euler XYZ degrees, scale
function M(geo, m, pos, rot, scl) {
  const o = new THREE.Mesh(geo, m);
  o.position.set(pos[0], pos[1], pos[2]);
  if (rot) o.rotation.set(rot[0] * D, rot[1] * D, rot[2] * D);
  if (scl) o.scale.set(scl[0], scl[1], scl[2]);
  o.updateMatrixWorld(true);
  return o;
}
// chamfered box (bible: 0.15-0.3 stud chamfers, never razor-sharp)
async function cbox(w, h, d, r) {
  return roundedBoxGeo(w, h, d, Math.min(r === undefined ? 0.25 : r, Math.min(w, h, d) * 0.45), { style: 'chamfer' });
}
// faceted low-poly lobe / gem
function ico(detail) {
  return mergeVertices(new THREE.IcosahedronGeometry(1, detail || 0), { positionOnly: true });
}
function octa() {
  return mergeVertices(new THREE.OctahedronGeometry(1, 0), { positionOnly: true });
}
async function fuse(root, name, parts) {
  if (parts.length === 1) { parts[0].name = name; root.add(parts[0]); return; }
  const u = await boolUnion(name, ...parts);
  root.add(u);
}
function finish(root) {
  // centre on x and z, stand on y = 0 (the converter does not re-centre).
  // Manual bounds: THREE.Box3.setFromObject is rejected by the Kiln sandbox.
  root.updateMatrixWorld(true);
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const ch of root.children) {
    const pos = ch.geometry.attributes.position, e = ch.matrixWorld.elements;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
      const w = [e[0] * x + e[4] * y + e[8] * z + e[12], e[1] * x + e[5] * y + e[9] * z + e[13], e[2] * x + e[6] * y + e[10] * z + e[14]];
      for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], w[k]); hi[k] = Math.max(hi[k], w[k]); }
    }
  }
  const cx = (lo[0] + hi[0]) / 2, cz = (lo[2] + hi[2]) / 2;
  for (const ch of root.children) { ch.position.x -= cx; ch.position.z -= cz; ch.position.y -= lo[1]; }
  root.updateMatrixWorld(true);
  return root;
}

async function hipRoof(m, y, half, h, topRatio, thick) {
  const R = Math.SQRT2;
  const prof = [[0, 0], [R, 0], [R, thick]];
  for (const f of [0.2, 0.45, 0.72]) prof.push([R * (1 - (1 - topRatio) * Math.pow(f, 0.55)), thick + h * f]);
  prof.push([R * topRatio, thick + h], [0, thick + h]);
  const g = await revolveProfile(prof, { segments: 4 });
  g.rotateY(Math.PI / 4);
  return M(g, m, [0, y, 0], null, [half, 1, half]);
}

async function build() {
  const root = createRoot('Prop_samurai_castle_Pagoda');

  const red = mat('ZoneRed', 0xe0453c);
  const roofM = mat('RoofInk', 0x0d0f2b);
  const white = mat('PlasterWhite', 0xffffff);
  const gold = mat('Gold', 0xffc83d);
  const dark = mat('StoneDark', 0x6b7686);

  const RD = [], RF = [], WH = [], GD = [], DK = [];

  // stone platform: darker base lip and a step, with a front stair
  DK.push(M(await cbox(15.0, 1.0, 15.0, 0.3), dark, [0, 0.5, 0]));
  DK.push(M(await cbox(12.0, 1.0, 12.0, 0.3), dark, [0, 1.5, 0]));
  DK.push(M(await cbox(2.2, 0.5, 4.0, 0.15), dark, [7.3, 0.75, 0]));

  // five tiers: white walls, red corner pillars and red rail band, ink flared roof, gold bells
  let y = 2.0;
  const n = 5;
  for (let i = 0; i < n; i++) {
    const s = 8.6 - i * 1.1;          // wall footprint
    const h = 3.2 - i * 0.12;         // wall height
    const eave = s / 2 + 3.4 - i * 0.35;
    WH.push(M(await cbox(s, h, s, 0.25), white, [0, y + h / 2, 0]));
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) RD.push(M(await cbox(0.85, h, 0.85, 0.2), red, [sx * (s / 2 - 0.25), y + h / 2, sz * (s / 2 - 0.25)]));
    // red door panel front + back, red rail band around the base of each tier
    RD.push(M(await cbox(s + 0.4, 0.5, s + 0.4, 0.15), red, [0, y + 0.25, 0]));
    RD.push(M(await cbox(s + 0.2, 1.8, 1.6, 0.15), red, [0, y + 1.5, 0]));
    const ry = y + h - 0.25;
    const nextHalf = (8.6 - (i + 1) * 1.1) / 2 + 0.2;
    RF.push(await hipRoof(roofM, ry, eave, 1.9, i === n - 1 ? 0.12 : nextHalf / eave, 0.45));
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) GD.push(M(ico(0), gold, [sx * eave * 0.97, ry + 0.2, sz * eave * 0.97], null, [0.42, 0.55, 0.42]));
    y = ry + 0.45 + 1.9 - 0.15;
  }
  // gold spire (sorin): pole, nine rings, flame jewel
  const top = y;
  GD.push(M(cylinderGeo(0.32, 0.4, 34 - top - 0.8, 8), gold, [0, top + (34 - top - 0.8) / 2, 0]));
  for (let k = 0; k < 7; k++) GD.push(M(cylinderGeo(0.85 - k * 0.06, 0.85 - k * 0.06, 0.4, 10), gold, [0, top + 1.0 + k * 0.85, 0]));
  GD.push(M(ico(1), gold, [0, 33.4, 0], null, [0.55, 0.65, 0.55]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'PlasterWhite', WH);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'RoofInk', RF);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
