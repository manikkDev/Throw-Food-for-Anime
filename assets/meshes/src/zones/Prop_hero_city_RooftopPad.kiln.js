// Prop_hero_city_RooftopPad: low building top with a hero landing pad marked H.
// Target (Roblox studs, x/y/z): 16 x 5 x 16, standing on y = 0, front -Z.
// The H reads upright to a viewer standing at the front (-Z).

const meta = { name: 'Prop_hero_city_RooftopPad', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_RooftopPad');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const ink = mat('Ink', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const white = mat('MarkWhite', 0xffffff);

  const S = [], DK = [], IN = [], CY = [], WH = [];

  // darker base lip and the building block
  DK.push(M(await cbox(16, 0.8, 16, 0.3), dark, [0, 0.4, 0]));
  S.push(M(await cbox(15.0, 3.3, 15.0, 0.3), stone, [0, 2.45, 0]));
  // ink window strips on all four faces (stone corners stay)
  IN.push(M(await cbox(15.25, 1.3, 12.4, 0.2), ink, [0, 2.3, 0]));
  IN.push(M(await cbox(12.4, 1.3, 15.25, 0.2), ink, [0, 2.3, 0]));
  // parapet ring (dark) with cyan corner lights
  const sq = (h) => [[-h, -h], [h, -h], [h, h], [-h, h]];
  DK.push(M(await extrudeProfile(sq(7.7), { depth: 0.7, axis: 'y', holes: [sq(6.9)], bevel: 0.15, bevelStyle: 'chamfer' }), dark, [0, 4.4, 0]));
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) CY.push(M(await cbox(0.9, 0.5, 0.9, 0.15), cyan, [sx * 7.3, 4.95, sz * 7.3]));

  // landing pad: ink disc, cyan ring, white H
  IN.push(M(cylinderGeo(5.4, 5.4, 0.5, 20), ink, [0.4, 4.25, 0]));
  CY.push(M(await extrudeProfile(circleProfile(5.6, 20), { depth: 0.45, axis: 'y', holes: [circleProfile(4.8, 20)] }), cyan, [0.4, 4.35, 0]));
  // H: uprights run front-to-back (Kiln X) so it reads as H from the front.
  // profile (u, v) -> Kiln (X, -Z) on axis y; a = across, b = up the letter
  const H = [[-1.6, -2.0], [-0.7, -2.0], [-0.7, -0.4], [0.7, -0.4], [0.7, -2.0], [1.6, -2.0], [1.6, 2.0], [0.7, 2.0], [0.7, 0.4], [-0.7, 0.4], [-0.7, 2.0], [-1.6, 2.0]];
  WH.push(M(await extrudeProfile(H.map(([a, b]) => [b, a]), { depth: 0.4, axis: 'y' }), white, [0.4, 4.55, 0]));

  // rooftop AC unit and access hatch at the back corners
  S.push(M(await cbox(1.8, 1.2, 2.6, 0.25), stone, [-5.6, 4.6, 5.0]));
  DK.push(M(await cbox(1.2, 0.3, 1.8, 0.12), dark, [-5.6, 5.25, 5.0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'MarkWhite', WH);
  return finish(root);
}
