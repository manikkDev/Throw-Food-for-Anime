// Prop_hero_city_StreetLamp: street lamp with a cyan light.
// Target (Roblox studs, x/y/z): 2.5 x 12 x 2.5, standing on y = 0, front -Z.
// The cyan core is its own part (ZoneCyan) so the game can give it Neon / a PointLight.

const meta = { name: 'Prop_hero_city_StreetLamp', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_StreetLamp');

  const dark = mat('StoneDark', 0x6b7686);
  const ink = mat('Ink', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const gold = mat('Gold', 0xffc83d);

  const DK = [], IN = [], CY = [], GD = [];

  // darker base lip and an octagonal plinth
  DK.push(M(await cbox(2.5, 0.6, 2.5, 0.2), dark, [0, 0.3, 0]));
  IN.push(M(await revolveProfile([[0, 0], [0.95, 0], [0.75, 1.3], [0, 1.3]], { segments: 8, bevel: 0.12, bevelSegments: 1 }), ink, [0, 0.6, 0], [0, 22.5, 0]));
  // pole with a cyan band and a gold collar
  IN.push(M(cylinderGeo(0.32, 0.38, 8.4, 8), ink, [0, 6.0, 0]));
  CY.push(M(cylinderGeo(0.48, 0.48, 0.5, 8), cyan, [0, 2.6, 0]));
  GD.push(M(cylinderGeo(0.5, 0.5, 0.45, 8), gold, [0, 9.6, 0]));
  // lantern: ink tray, cyan glowing core, four ink corner posts, dark pyramid roof
  IN.push(M(await cbox(1.7, 0.35, 1.7, 0.12), ink, [0, 10.0, 0]));
  CY.push(M(await cbox(1.3, 1.5, 1.3, 0.2), cyan, [0, 10.9, 0]));
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) IN.push(M(await cbox(0.42, 1.6, 0.42, 0.1), ink, [sx * 0.66, 10.9, sz * 0.66]));
  const R = Math.SQRT2 * 1.25;
  const roof = await revolveProfile([[0, 0], [R, 0], [R, 0.2], [R * 0.25, 0.75], [0, 0.75]], { segments: 4 });
  roof.rotateY(Math.PI / 4);
  DK.push(M(roof, dark, [0, 11.65, 0]));
  GD.push(M(ico(1), gold, [0, 12.6, 0], null, [0.3, 0.3, 0.3]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
