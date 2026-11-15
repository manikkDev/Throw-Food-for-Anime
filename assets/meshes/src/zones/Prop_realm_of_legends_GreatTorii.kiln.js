// Prop_realm_of_legends_GreatTorii: giant torii, violet and gold.
// Target (Roblox studs, x/y/z): 34 x 28 x 6, standing on y = 0, front -Z.
// Kiln: the 34-stud span runs along Kiln Z, the 6-stud depth along Kiln X.

const meta = { name: 'Prop_realm_of_legends_GreatTorii', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_GreatTorii');

  const violet = mat('ZoneViolet', 0xa66bff);
  const gold = mat('Gold', 0xffc83d);
  const ink = mat('Ink', 0x0d0f2b);
  const dark = mat('StoneDark', 0x6b7686);

  const VI = [], GD = [], IN = [], DK = [];
  const PZ = 11.0; // pillar centres at Kiln z = +-PZ

  for (const s of [-1, 1]) {
    // darker stone plinth (base lip)
    DK.push(M(await cbox(6.0, 1.4, 5.0, 0.3), dark, [0, 0.7, s * PZ]));
    // gold foot ring
    GD.push(M(await revolveProfile([[0, 0], [1.75, 0], [1.75, 1.1], [0, 1.1]], { segments: 10, bevel: 0.2, bevelSegments: 1 }), gold, [0, 1.4, s * (PZ + 0.42)]));  // pillar foot sits 0.42 outboard: 11 studs below the lean pivot x sin(2.2 deg)
    // leaning pillar (tops lean inward), 10-sided, tapering
    VI.push(M(cylinderGeo(1.15, 1.4, 22.4, 10), violet, [0, 12.4, s * PZ], [-s * 2.2, 0, 0]));
    // gold collar under the nuki
    GD.push(M(await revolveProfile([[0, 0], [1.62, 0], [1.62, 0.7], [0, 0.7]], { segments: 10, bevel: 0.15, bevelSegments: 1 }), gold, [0, 15.6, s * (PZ - 0.12)]));
  }
  // nuki tie beam (passes through the pillars and out past them)
  VI.push(M(await cbox(1.8, 1.6, 30.0, 0.3), violet, [0, 17.6, 0]));
  // shimaki (lower top beam)
  VI.push(M(await cbox(2.6, 1.6, 30.6, 0.3), violet, [0, 23.6, 0]));
  // gakuzuka centre strut and the gold plaque on it, front and back
  VI.push(M(await cbox(1.4, 4.6, 1.6, 0.25), violet, [0, 20.6, 0]));
  GD.push(M(await cbox(2.0, 3.8, 3.0, 0.3), gold, [0, 20.6, 0]));
  IN.push(M(await cbox(2.2, 2.6, 1.8, 0.2), ink, [0, 20.6, 0]));

  // kasagi: ink top beam with upswept ends, extruded across the depth
  const N = 14, HALF = 17.0, RISE = 1.6, T = 1.9;
  const top = [], bot = [];
  for (let i = 0; i <= N; i++) {
    const u = -HALF + (2 * HALF * i) / N;
    const lift = RISE * Math.pow(Math.abs(u) / HALF, 3);
    bot.push([u, lift]);
    top.push([u, lift + T + (Math.abs(u) > HALF - 0.01 ? 0.3 : 0)]);
  }
  const outline = [...bot, ...top.reverse()];
  IN.push(M(await extrudeProfile(outline, { depth: 3.4, axis: 'x', bevel: 0.25, bevelStyle: 'chamfer' }), ink, [0, 24.4, 0]));
  // gold end caps on the kasagi tips
  for (const s of [-1, 1]) GD.push(M(await cbox(3.7, 2.5, 0.5, 0.15), gold, [0, 24.4 + RISE + T / 2 + 0.1, s * 17.0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'Gold', GD);
  await fuse(root, 'Ink', IN);
  return finish(root);
}
