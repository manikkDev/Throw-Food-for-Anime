// Prop_hero_city_ArcadeMachine: arcade cabinet with a glowing cyan screen, red joystick,
// gold marquee and buttons, cyan neon side art. Screen and side art share ZoneCyan (Neon).
// Target (Roblox studs, x/y/z): 3 x 6.5 x 3, standing on y = 0, front -Z.
// Kiln: the cabinet's side profile is extruded across Kiln Z; the screen faces +X.

const meta = { name: 'Prop_hero_city_ArcadeMachine', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_ArcadeMachine');

  const ink = mat('CabinetInk', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const gold = mat('Gold', 0xffc83d);
  const red = mat('StickRed', 0xe0453c);
  const dark = mat('StoneDark', 0x6b7686);

  const IN = [], CY = [], GD = [], RD = [], DK = [];

  DK.push(M(await cbox(3.0, 0.4, 3.0, 0.15), dark, [0, 0.2, 0]));
  // side profile (u = Kiln X, v = Y): kick plate, control panel ledge, slanted screen, marquee hood
  const side = [[-1.35, 0.4], [1.15, 0.4], [1.15, 2.7], [1.45, 3.05], [1.45, 3.35], [0.75, 3.35], [0.55, 5.15], [1.1, 5.4], [1.1, 6.4], [-1.35, 6.4]];
  IN.push(M(await extrudeProfile(side, { depth: 2.6, axis: 'z', bevel: 0.12, bevelStyle: 'chamfer' }), ink, [0, 0, 0]));
  // glowing screen on the slanted face (normal tilts up toward +X)
  const ang = Math.atan2(0.2, 1.8) / D;
  CY.push(M(await cbox(0.2, 1.55, 2.0, 0.08), cyan, [0.72, 4.25, 0], [0, 0, ang]));
  // gold marquee on the hood front
  GD.push(M(await cbox(0.2, 0.75, 2.2, 0.08), gold, [1.17, 5.9, 0]));
  // control panel: red ball-top joystick and gold buttons
  IN.push(M(cylinderGeo(0.1, 0.1, 0.5, 6), ink, [1.05, 3.6, -0.55]));
  RD.push(M(ico(1), red, [1.05, 3.9, -0.55], null, [0.26, 0.26, 0.26]));
  for (const z of [0.25, 0.65]) for (const dx of [-0.2, 0.2]) GD.push(M(cylinderGeo(0.14, 0.14, 0.14, 8), gold, [1.05 + dx, 3.4, z]));
  // coin door
  GD.push(M(await cbox(0.15, 0.7, 0.9, 0.06), gold, [1.18, 1.6, 0]));
  // neon side art: cyan lightning zig-zag on both sides
  const zig = [[-0.9, 1.0], [0.1, 2.6], [-0.4, 2.7], [0.6, 4.6], [-0.1, 3.0], [0.3, 2.9], [-0.6, 1.1]];
  for (const s of [-1, 1]) CY.push(M(await extrudeProfile(zig, { depth: 0.15, axis: 'z' }), cyan, [-0.2, 0.6, s * 1.35]));
  // cyan trim line along the hood edge
  for (const s of [-1, 1]) CY.push(M(await cbox(2.4, 0.18, 0.15, 0.05), cyan, [-0.1, 6.25, s * 1.35]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'CabinetInk', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'Gold', GD);
  await fuse(root, 'StickRed', RD);
  return finish(root);
}
