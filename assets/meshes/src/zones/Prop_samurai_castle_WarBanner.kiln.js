// Prop_samurai_castle_WarBanner: tall narrow nobori banner on a pole, red with a white crest.
// Target (Roblox studs, x/y/z): 3 x 13 x 1.5, standing on y = 0, front -Z.
// Kiln: the 3-stud width runs along Kiln Z, the 1.5-stud depth along Kiln X; the banner face looks +X.

const meta = { name: 'Prop_samurai_castle_WarBanner', category: 'prop' };

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
  const root = createRoot('Prop_samurai_castle_WarBanner');

  const red = mat('ZoneRed', 0xe0453c);
  const white = mat('CrestWhite', 0xffffff);
  const wood = mat('Wood', 0x8a5a2b);
  const gold = mat('Gold', 0xffc83d);
  const dark = mat('StoneDark', 0x6b7686);

  const RD = [], WH = [], WD = [], GD = [], DK = [];
  const PZ = -1.05; // pole at the left edge (Roblox -x), banner hangs to its right

  // weighted stone foot (darker base lip), stepped
  DK.push(M(await cbox(1.5, 0.6, 2.6, 0.2), dark, [0, 0.3, -0.2]));
  DK.push(M(await cbox(1.1, 0.7, 1.4, 0.2), dark, [0, 0.95, PZ + 0.1]));
  // pole and top crossbar
  WD.push(M(cylinderGeo(0.3, 0.34, 11.6, 8), wood, [0, 6.9, PZ]));
  WD.push(M(cylinderZGeo(0.24, 0.24, 2.5, 8), wood, [0, 11.95, PZ + 1.15]));
  // banner cloth
  RD.push(M(await cbox(0.45, 8.6, 2.2, 0.15), red, [0, 7.55, 0.2]));
  // white top band and white crest ring with a red dot visible inside
  WH.push(M(await cbox(0.55, 0.9, 2.2, 0.15), white, [0, 11.3, 0.2]));
  const ring = await extrudeProfile(circleProfile(0.85, 16), { depth: 0.6, axis: 'x', holes: [circleProfile(0.45, 12)] });
  WH.push(M(ring, white, [0, 9.0, 0.2]));
  // white tri-stripe lower down (a second crest mark, readable at 80 studs)
  for (let i = 0; i < 3; i++) WH.push(M(await cbox(0.55, 0.45, 1.5, 0.12), white, [0, 4.6 + i * 0.85, 0.2]));
  // gold ring clamps holding the banner to the pole, gold finial on top
  for (const y of [3.6, 7.5, 11.3]) GD.push(M(await revolveProfile([[0, 0], [0.48, 0], [0.48, 0.4], [0, 0.4]], { segments: 8, bevel: 0.1, bevelSegments: 1 }), gold, [0, y, PZ]));
  GD.push(M(ico(1), gold, [0, 12.75, PZ], null, [0.42, 0.55, 0.42]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Wood', WD);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'CrestWhite', WH);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
