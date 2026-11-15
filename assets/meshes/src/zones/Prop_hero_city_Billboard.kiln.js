// Prop_hero_city_Billboard: rooftop billboard on a frame, blank face, cyan light bars.
// Target (Roblox studs, x/y/z): 18 x 14 x 3, standing on y = 0, front -Z.
// Kiln: the 18-stud width runs along Kiln Z; the face looks +X (Roblox -Z).
// The white face is BLANK on purpose: the game can put a SurfaceGui / Decal on it.

const meta = { name: 'Prop_hero_city_Billboard', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_Billboard');

  const dark = mat('StoneDark', 0x6b7686);
  const ink = mat('Ink', 0x0d0f2b);
  const white = mat('FaceWhite', 0xffffff);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const gold = mat('Gold', 0xffc83d);

  const DK = [], IN = [], WH = [], CY = [], GD = [];

  for (const s of [-1, 1]) {
    const z = s * 6.0;
    // footing (darker base lip)
    DK.push(M(await cbox(2.8, 0.6, 2.2, 0.2), dark, [-0.2, 0.3, z]));
    // leg and back strut
    DK.push(M(await cbox(0.8, 6.8, 0.8, 0.2), dark, [-0.4, 3.9, z]));
    DK.push(M(await cbox(0.6, 6.0, 0.6, 0.18), dark, [-1.05, 3.4, z], [0, 0, -9]));
  }
  // X brace between the legs, and a walkway beam
  for (const a of [-1, 1]) DK.push(M(await cbox(0.5, 0.5, 13.4, 0.15), dark, [-0.4, 3.9, 0], [a * 22, 0, 0]));
  DK.push(M(await cbox(1.6, 0.5, 15.0, 0.18), dark, [0.2, 6.9, 0]));

  // board: ink frame with a white blank face proud of it
  IN.push(M(await cbox(0.8, 6.6, 18.0, 0.3), ink, [-0.4, 10.4, 0]));
  WH.push(M(await cbox(0.4, 5.4, 16.6, 0.15), white, [0.1, 10.4, 0]));

  // light bars on arms, top and bottom, cyan; gold lamp heads on the top arms
  for (const z of [-6, 0, 6]) {
    DK.push(M(await cbox(1.6, 0.4, 0.45, 0.12), dark, [0.6, 13.85, z]));
    GD.push(M(await cbox(0.6, 0.55, 0.9, 0.15), gold, [1.05, 13.6, z]));
  }
  CY.push(M(await cbox(0.55, 0.5, 16.8, 0.15), cyan, [1.15, 14.05, 0]));
  CY.push(M(await cbox(0.5, 0.45, 16.8, 0.15), cyan, [0.35, 7.3, 0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'FaceWhite', WH);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
