// Prop_realm_of_legends_SpiritGate: giant ring-shaped portal gate on a stepped base with a
// flat glowing violet disc inside. The violet disc is its own part (ZoneViolet) for Neon.
// Target (Roblox studs, x/y/z): 16 x 18 x 4, standing on y = 0, front -Z.
// Kiln: the ring stands in the Kiln Z-Y plane, facing +X.

const meta = { name: 'Prop_realm_of_legends_SpiritGate', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_SpiritGate');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const violet = mat('ZoneViolet', 0xa66bff);
  const lilac = mat('GlowLilac', 0xd9c2ff);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], VI = [], LI = [], GD = [];
  const CY = 9.9, RO = 7.5, RI = 6.0;

  // stepped base: dark lip, two light steps
  DK.push(M(await cbox(4.0, 0.7, 16.0, 0.25), dark, [0, 0.35, 0]));
  S.push(M(await cbox(3.6, 0.8, 13.0, 0.25), stone, [0, 1.1, 0]));
  S.push(M(await cbox(3.2, 0.8, 9.0, 0.25), stone, [0, 1.9, 0]));
  // ring: revolve a chamfered rectangle around the Kiln X axis
  const ring = await revolveProfile([[RI, -1.2], [RO, -1.2], [RO, 1.2], [RI, 1.2]], { axis: 'x', segments: 28, bevel: 0.3, bevelSegments: 1 });
  S.push(M(ring, stone, [0, CY, 0]));
  // side buttresses that seat the ring on the base
  for (const s of [-1, 1]) S.push(M(await cbox(2.8, 3.6, 1.6, 0.3), stone, [0, 3.6, s * 4.6], [s * 28, 0, 0]));
  // gold inlay ring on both faces, eight gold studs, gold crest on top
  const inlay = await revolveProfile([[RI + 0.45, -1.3], [RO - 0.45, -1.3], [RO - 0.45, 1.3], [RI + 0.45, 1.3]], { axis: 'x', segments: 28 });
  GD.push(M(inlay, gold, [0, CY, 0], null, [1, 1, 1]));
  for (let k = 0; k < 8; k++) {
    const a = (k / 8) * Math.PI * 2 + Math.PI / 8;
    GD.push(M(ico(0), gold, [0, CY + Math.sin(a) * RO, Math.cos(a) * RO], null, [0.55, 0.55, 0.55]));
  }
  GD.push(M(octa(), gold, [0, CY + RO + 0.35, 0], null, [0.9, 1.2, 0.9]));
  // violet portal disc and a lilac core, proud on both faces
  VI.push(M(cylinderXGeo(RI + 0.1, RI + 0.1, 0.5, 28), violet, [0, CY, 0]));
  LI.push(M(cylinderXGeo(3.2, 3.2, 0.62, 20), lilac, [0, CY, 0]));
  // violet runes on the steps (zone trim at eye level)
  for (const z of [-4.5, -1.5, 1.5, 4.5]) VI.push(M(await cbox(0.3, 0.5, 1.4, 0.1), violet, [1.65, 1.9, z]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'Gold', GD);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'GlowLilac', LI);
  return finish(root);
}
