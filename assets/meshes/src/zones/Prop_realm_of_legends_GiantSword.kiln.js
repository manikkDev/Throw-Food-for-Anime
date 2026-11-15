// Prop_realm_of_legends_GiantSword: legendary greatsword standing in a crystal mound,
// violet gem in the guard, gold edge.
// Target (Roblox studs, x/y/z): 8 x 26 x 4, standing on y = 0, front -Z.
// Kiln: the flat of the blade faces +X; the 8-stud crossguard runs along Kiln Z.

const meta = { name: 'Prop_realm_of_legends_GiantSword', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_GiantSword');

  const steel = mat('BladeSteel', 0x9aa4b2);
  const gold = mat('Gold', 0xffc83d);
  const violet = mat('ZoneViolet', 0xa66bff);
  const lilac = mat('CrystalLilac', 0xd9c2ff);
  const dark = mat('StoneDark', 0x6b7686);

  const ST = [], GD = [], VI = [], LI = [], DK = [];

  // --- mound: dark rock lobes (base lip), violet and lilac crystals ---------
  DK.push(M(await cbox(4.0, 0.6, 7.6, 0.25), dark, [0, 0.3, 0]));
  for (const [x, y, z, sx, sy, sz] of [[0, 1.4, 0, 1.8, 1.5, 3.0], [0.2, 1.0, 2.4, 1.5, 1.1, 1.6], [-0.2, 1.0, -2.4, 1.5, 1.1, 1.6]]) DK.push(M(ico(0), dark, [x, y, z], [0, 20, 10], [sx, sy, sz]));
  const gem = octa();
  for (const [x, y, z, rx, rz, g, l, m] of [
    [0.3, 2.4, 1.6, 0, -25, 0.8, 2.2, 'v'], [-0.3, 2.3, -1.7, 0, 28, 0.8, 2.0, 'v'], [0.6, 1.8, 3.0, 0, -50, 0.6, 1.5, 'l'],
    [-0.5, 1.7, -3.1, 0, 52, 0.6, 1.5, 'l'], [1.2, 1.5, -0.6, 35, 0, 0.6, 1.4, 'l'], [-1.2, 1.6, 0.7, -35, 0, 0.6, 1.4, 'v'],
  ]) (m === 'v' ? VI : LI).push(M(gem, m === 'v' ? violet : lilac, [x, y, z], [rx, 45, rz], [g, l, g]));

  // --- blade: gold outline (edge) with a thicker steel core inset from it ----
  const outline = (w, tip, y0, y1) => [[0, y0], [w * 0.75, y0 + tip], [w, y0 + tip + 1.2], [w, y1], [-w, y1], [-w, y0 + tip + 1.2], [-w * 0.75, y0 + tip]];
  GD.push(M(await extrudeProfile(outline(1.45, 1.6, 1.6, 18.6), { depth: 0.5, axis: 'x', bevel: 0.12, bevelStyle: 'chamfer' }), gold, [0, 0, 0]));
  ST.push(M(await extrudeProfile(outline(1.05, 1.5, 2.1, 18.7), { depth: 0.75, axis: 'x', bevel: 0.15, bevelStyle: 'chamfer' }), steel, [0, 0, 0]));
  // fuller: steel ridge down the middle
  ST.push(M(await cbox(0.95, 12.0, 0.45, 0.15), steel, [0, 11.6, 0]));

  // --- crossguard (gold, flared ends), violet gem, grip, pommel --------------
  GD.push(M(await extrudeProfile([[-4.0, 0.2], [-3.4, -0.3], [-1.2, 0.1], [0, -0.4], [1.2, 0.1], [3.4, -0.3], [4.0, 0.2], [3.6, 1.0], [1.4, 1.0], [0, 1.4], [-1.4, 1.0], [-3.6, 1.0]], { depth: 1.2, axis: 'x', bevel: 0.15, bevelStyle: 'chamfer' }), gold, [0, 18.9, 0]));
  VI.push(M(octa(), violet, [0, 19.5, 0], [0, 0, 90], [0.9, 0.9, 0.9]));
  DK.push(M(cylinderGeo(0.45, 0.5, 4.4, 8), dark, [0, 22.4, 0]));
  for (const y of [20.9, 22.4, 23.9]) GD.push(M(cylinderGeo(0.58, 0.58, 0.3, 8), gold, [0, y, 0]));
  GD.push(M(await cbox(1.0, 1.4, 1.4, 0.3), gold, [0, 25.15, 0], [45, 0, 0]));
  VI.push(M(octa(), violet, [0, 25.15, 0], null, [0.65, 0.6, 0.6]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'BladeSteel', ST);
  await fuse(root, 'Gold', GD);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'CrystalLilac', LI);
  return finish(root);
}
