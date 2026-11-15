// Prop_samurai_castle_ArmorStand: samurai armour on a display stand. Horned helmet (gold
// kuwagata), red lacquer plates with white lacing lines, ink helmet bowl and mask, wood armour box.
// Target (Roblox studs, x/y/z): 5 x 8 x 4, standing on y = 0, front -Z.
// Kiln: width along Kiln Z, depth along Kiln X, the armour faces +X.

const meta = { name: 'Prop_samurai_castle_ArmorStand', category: 'prop' };

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

async function build() {
  const root = createRoot('Prop_samurai_castle_ArmorStand');

  const red = mat('ZoneRed', 0xe0453c);
  const ink = mat('Ink', 0x0d0f2b);
  const gold = mat('Gold', 0xffc83d);
  const wood = mat('Wood', 0x8a5a2b);
  const white = mat('LaceWhite', 0xffffff);

  const RD = [], IN = [], GD = [], WD = [], WH = [];

  // armour box (dark wood, the base) with gold corner fittings
  WD.push(M(await cbox(3.6, 1.6, 4.2, 0.25), wood, [0, 0.8, 0]));
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) GD.push(M(await cbox(0.5, 0.5, 0.5, 0.12), gold, [sx * 1.6, 1.4, sz * 1.9]));
  IN.push(M(cylinderGeo(0.3, 0.3, 1.2, 8), ink, [0, 2.1, 0]));

  // skirt (kusazuri): flared hexagonal frustum of red plates with white lace rings
  RD.push(M(await revolveProfile([[0, 0], [2.05, 0], [1.6, 1.9], [0, 1.9]], { segments: 6, bevel: 0.15, bevelSegments: 1 }), red, [0, 2.3, 0], [0, 30, 0], [0.85, 1, 1]));
  for (const [y, r] of [[2.85, 1.94], [3.5, 1.72]]) WH.push(M(await revolveProfile([[0, 0], [r, 0], [r, 0.18], [0, 0.18]], { segments: 6 }), white, [0, y, 0], [0, 30, 0], [0.85, 1, 1]));
  // torso (do)
  RD.push(M(await cbox(2.3, 2.5, 3.0, 0.5), red, [0, 5.4, 0]));
  for (const y of [4.6, 5.3]) WH.push(M(await cbox(2.4, 0.2, 3.1, 0.08), white, [0, y, 0]));
  GD.push(M(ico(1), gold, [1.18, 5.95, 0], null, [0.2, 0.45, 0.45]));
  // shoulder guards (sode): big plates hanging off both sides, lace stripes
  for (const s of [-1, 1]) {
    RD.push(M(await cbox(1.9, 2.2, 0.42, 0.15), red, [0, 5.4, s * 1.95], [s * 16, 0, 0]));
    for (const dy of [-0.45, 0.25]) WH.push(M(await cbox(1.95, 0.18, 0.46, 0.06), white, [0, 5.4 + dy, s * (1.95 + dy * Math.sin(16 * D) * 0.5)], [s * 16, 0, 0]));
  }
  // helmet: red neck-flare (shikoro), ink bowl, ink mask, gold horns and crest
  RD.push(M(await revolveProfile([[0, 0], [1.45, 0], [0.95, 0.65], [0, 0.65]], { segments: 8, bevel: 0.1, bevelSegments: 1 }), red, [0, 6.55, 0], [0, 22.5, 0]));
  IN.push(M(await revolveProfile([[0, 0], [0.95, 0], [0.85, 0.45], [0.55, 0.8], [0, 0.9]], { segments: 8 }), ink, [0, 7.1, 0], [0, 22.5, 0]));
  IN.push(M(await cbox(0.45, 0.6, 0.9, 0.12), ink, [0.75, 6.7, 0]));
  for (const s of [-1, 1]) GD.push(M(await cbox(0.25, 1.35, 0.42, 0.08), gold, [0.7, 7.55, s * 0.55], [s * 26, 0, -12]));
  GD.push(M(await cbox(0.35, 0.45, 0.45, 0.1), gold, [0.85, 7.3, 0], [45, 0, 0]));

  await fuse(root, 'Wood', WD);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'Gold', GD);
  await fuse(root, 'LaceWhite', WH);
  return finish(root);
}
