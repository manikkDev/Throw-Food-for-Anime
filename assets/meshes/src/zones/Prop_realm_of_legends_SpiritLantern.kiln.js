// Prop_realm_of_legends_SpiritLantern: stone lantern (toro) with a violet flame slab.
// Target (Roblox studs, x/y/z): 3 x 7 x 3, standing on y = 0, front -Z.
// The violet flame is its own part (ZoneViolet) so the game can make it Neon / add a light.

const meta = { name: 'Prop_realm_of_legends_SpiritLantern', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_SpiritLantern');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const violet = mat('ZoneViolet', 0xa66bff);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], VI = [], GD = [];

  // darker base lip
  DK.push(M(await cbox(3.0, 0.5, 3.0, 0.2), dark, [0, 0.25, 0]));
  // hexagonal foot, post, and platform
  S.push(M(await revolveProfile([[0, 0], [1.45, 0], [1.2, 0.6], [0, 0.6]], { segments: 6, bevel: 0.1, bevelSegments: 1 }), stone, [0, 0.5, 0], [0, 30, 0]));
  S.push(M(cylinderGeo(0.5, 0.6, 2.4, 6), stone, [0, 2.3, 0], [0, 30, 0]));
  S.push(M(await revolveProfile([[0, 0], [0.9, 0], [1.4, 0.45], [1.4, 0.6], [0, 0.6]], { segments: 6, bevel: 0.08, bevelSegments: 1 }), stone, [0, 3.4, 0], [0, 30, 0]));
  // firebox: four corner posts (openings between them show the flame)
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) S.push(M(await cbox(0.45, 1.4, 0.45, 0.1), stone, [sx * 0.68, 4.7, sz * 0.68]));
  // violet flame slab: two crossed teardrop slabs so it reads from every side
  const flame = [[0, 0], [0.42, 0.25], [0.5, 0.6], [0.3, 0.95], [0.05, 1.3], [-0.12, 0.95], [-0.42, 0.6], [-0.42, 0.25]];
  VI.push(M(await extrudeProfile(flame, { depth: 0.4, axis: 'x', bevel: 0.08, bevelStyle: 'chamfer' }), violet, [0, 4.05, 0]));
  VI.push(M(await extrudeProfile(flame, { depth: 0.4, axis: 'x', bevel: 0.08, bevelStyle: 'chamfer' }), violet, [0, 4.05, 0], [0, 90, 0]));
  // hexagonal flared roof with dark underside lip
  DK.push(M(await revolveProfile([[0, 0], [1.25, 0], [1.25, 0.2], [0, 0.2]], { segments: 6 }), dark, [0, 5.35, 0], [0, 30, 0]));
  const R = 1.5; // corner radius: 1.72 measured 3.44 wide (+14.7%)
  S.push(M(await revolveProfile([[0, 0], [R, 0], [R, 0.18], [R * 0.62, 0.45], [R * 0.32, 0.85], [R * 0.18, 1.05], [0, 1.05]], { segments: 6 }), stone, [0, 5.5, 0], [0, 30, 0]));
  // gold jewel finial (hoju)
  GD.push(M(cylinderGeo(0.22, 0.28, 0.25, 6), gold, [0, 6.6, 0]));
  GD.push(M(ico(1), gold, [0, 6.88, 0], null, [0.3, 0.36, 0.3]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
