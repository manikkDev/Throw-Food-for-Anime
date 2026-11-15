// Prop_realm_of_legends_StarAltar: round altar with a floating gold star above it, ringed by
// four violet crystal pillars. The star is unconnected (floats); it is part of the Gold mesh.
// Target (Roblox studs, x/y/z): 10 x 8 x 10, standing on y = 0, front -Z.
// Kiln: the star's face looks +X (Roblox -Z).

const meta = { name: 'Prop_realm_of_legends_StarAltar', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_StarAltar');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const violet = mat('ZoneViolet', 0xa66bff);
  const lilac = mat('CrystalLilac', 0xd9c2ff);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], VI = [], LI = [], GD = [];

  // round stepped altar
  DK.push(M(await revolveProfile([[0, 0], [5.0, 0], [5.0, 0.5], [4.6, 0.65], [0, 0.65]], { segments: 12, bevel: 0.12, bevelSegments: 1 }), dark, [0, 0, 0], [0, 15, 0]));
  S.push(M(await revolveProfile([[0, 0], [3.9, 0], [3.9, 0.75], [0, 0.75]], { segments: 12, bevel: 0.2, bevelSegments: 1 }), stone, [0, 0.6, 0], [0, 15, 0]));
  S.push(M(await revolveProfile([[0, 0], [2.9, 0], [2.9, 0.75], [0, 0.75]], { segments: 12, bevel: 0.2, bevelSegments: 1 }), stone, [0, 1.3, 0], [0, 15, 0]));
  S.push(M(await revolveProfile([[0, 0], [1.4, 0], [1.2, 1.2], [1.9, 1.5], [1.9, 1.9], [0, 1.9]], { segments: 10, bevel: 0.1, bevelSegments: 1 }), stone, [0, 2.0, 0]));
  VI.push(M(cylinderGeo(1.5, 1.5, 0.3, 10), violet, [0, 3.95, 0]));
  // gold band on the middle step
  GD.push(M(await revolveProfile([[2.85, 0], [3.0, 0], [3.0, 0.35], [2.85, 0.35]], { segments: 12 }), gold, [0, 1.55, 0], [0, 15, 0]));

  // four crystal pillars on dark footings, lilac tips
  for (let k = 0; k < 4; k++) {
    const a = Math.PI / 4 + (k * Math.PI) / 2;
    const x = Math.cos(a) * 4.0, z = Math.sin(a) * 4.0;
    DK.push(M(await cbox(1.5, 0.6, 1.5, 0.15), dark, [x, 0.9, z], [0, 45, 0]));
    VI.push(M(cylinderGeo(0.6, 0.7, 4.0, 6), violet, [x, 3.2, z]));
    LI.push(M(octa(), lilac, [x, 5.6, z], [0, 30, 0], [0.62, 1.2, 0.62]));
  }

  // floating gold star
  const star = [];
  for (let i = 0; i < 10; i++) {
    const a = Math.PI / 2 + (i * Math.PI) / 5;
    const r = i % 2 ? 0.8 : 1.85;
    star.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  GD.push(M(await extrudeProfile(star, { depth: 0.75, axis: 'x', bevel: 0.15, bevelStyle: 'chamfer' }), gold, [0, 6.15, 0]));
  // small gold orbs around the star
  for (const [y, z] of [[5.0, 2.6], [7.0, -2.5]]) GD.push(M(ico(1), gold, [0, y, z], null, [0.32, 0.32, 0.32]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'CrystalLilac', LI);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
