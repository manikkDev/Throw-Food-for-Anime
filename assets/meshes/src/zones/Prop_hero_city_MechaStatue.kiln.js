// Prop_hero_city_MechaStatue: giant hero robot statue in a heroic pose. White, blue and red
// armour, gold V crest, glowing cyan chest core (zone key colour, also the eyes and plinth stripe).
// Target (Roblox studs, x/y/z): 16 x 30 x 10, standing on y = 0, front -Z. Budget 6000 tris.
// Pose: right fist (Roblox +x) punched at the sky, left arm forward behind a red shield.
// Kiln: width along Kiln Z, depth along Kiln X, the robot faces +X (Roblox -Z).

const meta = { name: 'Prop_hero_city_MechaStatue', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_MechaStatue');

  const white = mat('ArmourWhite', 0xffffff);
  const blue = mat('ArmourBlue', 0x2f5bd8);
  const red = mat('ZoneRedArmour', 0xe0453c);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const gold = mat('Gold', 0xffc83d);

  const WH = [], BL = [], RD = [], CY = [], GD = [];
  const B = async (arr, m, w, h, d, pos, rot, r) => arr.push(M(await cbox(w, h, d, r === undefined ? 0.3 : r), m, pos, rot));

  // --- plinth: blue lip (darker base), white block, cyan stripe ----------
  await B(BL, blue, 10, 0.8, 16, [0, 0.4, 0]);
  await B(WH, white, 8.8, 2.2, 14.4, [0, 1.9, 0]);
  await B(CY, cyan, 0.4, 0.6, 12.0, [4.45, 1.9, 0], null, 0.15);

  // --- legs: wide heroic stance --------------------------------------------
  for (const s of [-1, 1]) {
    await B(BL, blue, 3.4, 1.5, 2.6, [0.5, 3.75, s * 3.3]);                         // foot
    await B(RD, red, 1.2, 1.0, 2.0, [2.1, 3.7, s * 3.3], null, 0.2);                 // toe cap
    await B(WH, white, 2.6, 5.2, 2.5, [0, 7.0, s * 2.95], [s * 7, 0, 0]);            // shin
    await B(RD, red, 0.9, 1.4, 1.6, [1.3, 9.0, s * 2.75], [s * 7, 0, 0], 0.2);       // knee guard
    await B(BL, blue, 2.3, 4.2, 2.3, [0, 11.4, s * 2.35], [s * 5, 0, 0]);             // thigh
  }
  // --- waist and torso -----------------------------------------------------
  await B(WH, white, 3.4, 2.4, 6.0, [0, 14.0, 0]);                                   // hip skirt
  await B(RD, red, 0.6, 1.6, 1.8, [1.75, 14.0, 0], null, 0.2);                       // buckle
  await B(RD, red, 2.8, 1.4, 3.8, [0, 15.8, 0]);                                     // abdomen
  await B(BL, blue, 4.4, 4.8, 7.4, [0, 18.8, 0], null, 0.45);                        // chest
  CY.push(M(cylinderXGeo(1.15, 1.15, 0.6, 6), cyan, [2.3, 18.9, 0], [30, 0, 0]));    // chest core
  for (const s of [-1, 1]) await B(GD, gold, 0.4, 1.4, 1.2, [2.25, 19.2, s * 2.2], null, 0.15); // vents
  await B(BL, blue, 3.0, 3.6, 5.0, [-3.2, 19.0, 0], null, 0.4);                       // backpack
  for (const s of [-1, 1]) WH.push(M(cylinderGeo(0.7, 0.9, 2.2, 8), white, [-3.6, 16.6, s * 1.4])); // thrusters

  // --- head with V crest -----------------------------------------------------
  await B(WH, white, 2.5, 2.5, 2.3, [0.1, 22.4, 0], null, 0.35);
  await B(CY, cyan, 0.4, 0.55, 1.7, [1.3, 22.6, 0], null, 0.12);                      // visor eyes
  await B(RD, red, 0.7, 0.7, 0.9, [1.15, 21.35, 0], null, 0.15);                      // chin
  await B(RD, red, 0.9, 0.8, 0.9, [1.0, 23.6, 0], null, 0.2);                         // forehead jewel base
  for (const s of [-1, 1]) await B(GD, gold, 0.5, 3.6, 0.7, [1.15, 25.2, s * 1.05], [s * 34, 0, 0], 0.15);
  await B(BL, blue, 1.0, 1.2, 0.6, [-0.4, 24.0, 0], null, 0.15);                      // head fin

  // --- shoulders ---------------------------------------------------------------
  for (const s of [-1, 1]) {
    await B(WH, white, 3.4, 2.8, 3.2, [0, 20.6, s * 5.1], null, 0.45);
    await B(RD, red, 3.0, 0.5, 2.6, [0, 22.15, s * 5.1], null, 0.15);
  }
  // --- right arm (+Z): fist to the sky -------------------------------------------
  await B(BL, blue, 1.9, 3.8, 1.9, [0, 23.6, 6.0], [-10, 0, 0]);
  await B(WH, white, 2.2, 3.4, 2.2, [0, 26.6, 6.45], [-6, 0, 0]);
  await B(RD, red, 2.3, 0.6, 2.3, [0, 25.0, 6.3], [-6, 0, 0], 0.15);                  // cuff
  await B(WH, white, 2.0, 2.0, 2.0, [0, 29.0, 6.7], null, 0.4);                        // fist
  // --- left arm (-Z): forward, holding the shield --------------------------------
  await B(BL, blue, 1.9, 3.4, 1.9, [0.4, 18.0, -6.1], [0, 0, -20]);
  await B(WH, white, 3.6, 2.0, 2.0, [2.2, 16.4, -6.1], null, 0.35);
  const shield = [[0, -3.4], [2.2, -1.2], [2.2, 2.8], [-2.2, 2.8], [-2.2, -1.2]];
  RD.push(M(await extrudeProfile(shield, { depth: 0.6, axis: 'x', bevel: 0.25, bevelStyle: 'chamfer' }), red, [4.2, 16.6, -6.4]));
  WH.push(M(await extrudeProfile(shield.map(([u, v]) => [u * 1.12, v * 1.1 + 0.05]), { depth: 0.4, axis: 'x', bevel: 0.2, bevelStyle: 'chamfer' }), white, [3.8, 16.6, -6.4]));
  GD.push(M(ico(0), gold, [4.6, 17.4, -6.4], null, [0.45, 1.0, 1.0]));                  // shield emblem

  await fuse(root, 'ArmourBlue', BL);
  await fuse(root, 'ArmourWhite', WH);
  await fuse(root, 'ZoneRedArmour', RD);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
