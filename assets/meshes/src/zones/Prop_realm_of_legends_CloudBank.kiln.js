// Prop_realm_of_legends_CloudBank: flat-bottomed puffy cloud of six rounded lobes.
// Target (Roblox studs, x/y/z): 26 x 8 x 16, standing on y = 0, front -Z.
// Kiln: the 26-stud length runs along Kiln Z, the 16-stud depth along Kiln X.
// Violet base lip (zone trim) under white lobes, lilac lower puffs between them.

const meta = { name: 'Prop_realm_of_legends_CloudBank', category: 'prop' };

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

// low-poly flat-bottomed dome, unit radius / unit height
async function dome() {
  return revolveProfile([[0, 0], [1, 0], [0.96, 0.3], [0.84, 0.58], [0.62, 0.82], [0.32, 0.97], [0, 1]], { segments: 10 });
}

async function build() {
  const root = createRoot('Prop_realm_of_legends_CloudBank');

  const white = mat('CloudWhite', 0xffffff);
  const lilac = mat('CloudLilac', 0xd9c2ff);
  const violet = mat('ZoneViolet', 0xa66bff);

  const WH = [], LI = [], VI = [];
  const d = await dome();
  const BASE = 0.7;
  // [x (depth), z (length), radius x, height, radius z]
  const lobes = [
    [0.0, 0.0, 6.4, 7.3, 6.6],
    [-0.6, -6.4, 5.0, 5.4, 5.0],
    [0.4, 6.4, 5.2, 5.8, 5.0],
    [0.2, -9.6, 3.4, 3.4, 3.4],
    [-0.4, 9.8, 3.2, 3.2, 3.2],
    [-3.6, 2.6, 4.2, 5.0, 4.6],
  ];
  for (const [x, z, rx, h, rz] of lobes) WH.push(M(d, white, [x, BASE, z], [0, x * 13 + z * 7, 0], [rx, h, rz]));
  // lilac lower puffs along the front and back
  const puffs = [[4.4, -3.8, 2.8, 2.6, 3.0], [4.6, 3.8, 2.6, 2.4, 2.8], [-4.6, -4.0, 2.6, 2.4, 2.8], [4.2, 8.2, 2.2, 2.0, 2.4]];
  for (const [x, z, rx, h, rz] of puffs) LI.push(M(d, lilac, [x, BASE, z], [0, 17, 0], [rx, h, rz]));
  // violet base lip: flat slabs under every lobe, slightly wider than the lobe
  for (const [x, z, rx, , rz] of [...lobes, ...puffs]) {
    VI.push(M(await revolveProfile([[0, 0], [1, 0], [1, 1], [0, 1]], { segments: 10 }), violet, [x, 0, z], [0, x * 13 + z * 7, 0], [rx + 0.3, BASE + 0.05, rz + 0.3]));
  }

  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'CloudLilac', LI);
  await fuse(root, 'CloudWhite', WH);
  return finish(root);
}
