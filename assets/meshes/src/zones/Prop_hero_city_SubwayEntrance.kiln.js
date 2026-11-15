// Prop_hero_city_SubwayEntrance: subway stairwell entrance with a canopy, a round metro sign
// and railings. Stands on y = 0: the stairs go DOWN into a raised plinth toward an ink tunnel
// mouth at the back (the model cannot go below y = 0).
// Target (Roblox studs, x/y/z): 12 x 7 x 10, standing on y = 0, front -Z.
// Kiln: width along Kiln Z, depth along Kiln X, stairs open toward +X.

const meta = { name: 'Prop_hero_city_SubwayEntrance', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_SubwayEntrance');

  const dark = mat('StoneDark', 0x6b7686);
  const stone = mat('StoneLight', 0x9aa4b2);
  const ink = mat('Ink', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const white = mat('CanopyWhite', 0xffffff);

  const DK = [], S = [], IN = [], CY = [], WH = [];
  const TOP = 1.6;

  // dark base lip, light plinth walls around the opening
  DK.push(M(await cbox(10.0, 0.4, 12.0, 0.2), dark, [0, 0.2, 0]));
  for (const s of [-1, 1]) S.push(M(await cbox(9.0, TOP - 0.4, 2.6, 0.25), stone, [-0.3, 0.4 + (TOP - 0.4) / 2, s * 4.2]));
  S.push(M(await cbox(1.6, TOP - 0.4, 5.8, 0.25), stone, [-4.0, 0.4 + (TOP - 0.4) / 2, 0]));
  // steps descending from the front lip toward the back
  for (let i = 0; i < 6; i++) S.push(M(await cbox(1.1, TOP - 0.4 - i * 0.2, 5.8, 0.08), stone, [3.6 - i * 1.05, 0.4 + (TOP - 0.4 - i * 0.2) / 2, 0]));
  // ink tunnel mouth at the back of the stairwell
  IN.push(M(await cbox(0.6, 3.4, 5.6, 0.2), ink, [-3.0, 0.4 + 1.7, 0]));
  WH.push(M(await cbox(0.8, 0.5, 6.4, 0.15), white, [-3.0, 4.3, 0]));

  // cyan railings along both sides of the opening
  for (const s of [-1, 1]) {
    const z = s * 3.15;
    for (const x of [-3.0, 0.0, 3.0]) CY.push(M(cylinderGeo(0.2, 0.2, 2.0, 6), cyan, [x, TOP + 1.0, z]));
    CY.push(M(await cbox(6.6, 0.4, 0.42, 0.12), cyan, [0, TOP + 2.0, z]));
    CY.push(M(await cbox(6.4, 0.3, 0.32, 0.1), cyan, [0, TOP + 1.0, z]));
  }
  // canopy: ink posts, white roof with a cyan fascia, slight front lift
  for (const sx of [-1, 1]) for (const s of [-1, 1]) IN.push(M(await cbox(0.45, 4.2, 0.45, 0.12), ink, [sx * 3.4 - 0.4, TOP + 2.1, s * 3.6]));
  WH.push(M(await cbox(9.0, 0.45, 8.6, 0.2), white, [-0.4, TOP + 4.45, 0], [0, 0, 4]));
  CY.push(M(await cbox(0.45, 0.55, 8.8, 0.15), cyan, [4.1, TOP + 4.75, 0]));
  for (const s of [-1, 1]) CY.push(M(await cbox(9.0, 0.5, 0.4, 0.12), cyan, [-0.4, TOP + 4.25, s * 4.35], [0, 0, 4]));

  // round metro sign on a pole at the front corner: cyan ring, white disc, ink M
  const SZ = 5.2, SX = 3.8, SY = 5.9;
  IN.push(M(cylinderGeo(0.22, 0.25, SY - 0.4, 8), ink, [SX, (SY - 0.4) / 2 + 0.4, SZ]));
  CY.push(M(await extrudeProfile(circleProfile(1.0, 18), { depth: 0.35, axis: 'x', holes: [circleProfile(0.72, 18)] }), cyan, [SX, SY, SZ]));
  WH.push(M(cylinderXGeo(0.74, 0.74, 0.3, 18), white, [SX, SY, SZ]));
  const Mletter = [[-0.45, -0.38], [-0.27, -0.38], [-0.27, 0.12], [0, -0.15], [0.27, 0.12], [0.27, -0.38], [0.45, -0.38], [0.45, 0.4], [0.28, 0.4], [0, 0.12], [-0.28, 0.4], [-0.45, 0.4]];
  IN.push(M(await extrudeProfile(Mletter, { depth: 0.42, axis: 'x' }), ink, [SX, SY, SZ]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'CanopyWhite', WH);
  return finish(root);
}
