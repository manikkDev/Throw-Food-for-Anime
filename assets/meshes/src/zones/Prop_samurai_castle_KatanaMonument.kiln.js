// Prop_samurai_castle_KatanaMonument: giant katana plunged into a rock, red wrap on the hilt,
// gold guard. A red shimenawa rope with white paper streamers rings the rock.
// Target (Roblox studs, x/y/z): 6 x 20 x 6, standing on y = 0, front -Z.
// Kiln: the blade's flat faces look +X (front) so its curve and width read from the front.

const meta = { name: 'Prop_samurai_castle_KatanaMonument', category: 'prop' };

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
  const root = createRoot('Prop_samurai_castle_KatanaMonument');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const steel = mat('BladeWhite', 0xffffff);
  const red = mat('ZoneRed', 0xe0453c);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], WH = [], RD = [], GD = [];

  // dark base lip and a chunky faceted rock
  DK.push(M(await revolveProfile([[0, 0], [2.95, 0], [2.95, 0.5], [2.5, 0.65], [0, 0.65]], { segments: 8, bevel: 0.12, bevelSegments: 1 }), dark, [0, 0, 0], [0, 22.5, 0]));
  const rock = [[0, 2.2, 0, 2.5, 2.0, 2.4], [0.9, 1.6, 1.2, 1.6, 1.4, 1.6], [-1.0, 1.5, -1.0, 1.7, 1.3, 1.6], [-0.6, 1.4, 1.4, 1.4, 1.2, 1.4], [1.0, 1.5, -1.2, 1.4, 1.2, 1.3], [0.2, 3.5, -0.2, 1.5, 1.2, 1.5]];
  for (const [x, y, z, sx, sy, sz] of rock) S.push(M(ico(0), stone, [x, y, z], [x * 20, z * 30, 10], [sx, sy, sz]));
  // shimenawa: red rope ring round the rock, white zig-zag paper streamers hanging from it
  RD.push(M(await revolveProfile([[2.15, 0], [2.6, 0], [2.6, 0.55], [2.15, 0.55]], { segments: 10, bevel: 0.18, bevelSegments: 1 }), red, [0, 2.5, 0]));
  for (let k = 0; k < 4; k++) {
    const a = (k / 4) * Math.PI * 2 + Math.PI / 4;
    const x = Math.cos(a) * 2.62, z = Math.sin(a) * 2.62;
    WH.push(M(await extrudeProfile([[-0.35, 0], [0.35, 0], [0.35, -0.5], [0.0, -0.75], [0.35, -1.0], [0.35, -1.5], [-0.35, -1.5], [-0.35, -1.0], [0.0, -0.75], [-0.35, -0.5]].map(([u, v]) => [u, v]), { depth: 0.4, axis: 'x' }), steel, [x, 2.55, z], [0, -a / D, 0]));
  }

  // blade: curved katana outline (u = width across, v = up), flat faces toward +X
  const blade = [];
  const L = 12.0;
  const curve = (v) => 0.6 * Math.pow(v / L, 2);
  for (let i = 0; i <= 6; i++) { const v = (L * i) / 6; blade.push([-0.75 + curve(v), v]); }
  blade.push([0.75 + curve(L), L]);
  for (let i = 5; i >= 0; i--) { const v = (L * i) / 6; blade.push([0.75 + curve(v) + (i === 0 ? -0.35 : 0), v]); }
  WH.push(M(await extrudeProfile(blade, { depth: 0.55, axis: 'x', bevel: 0.14, bevelStyle: 'chamfer' }), steel, [0, 2.4, 0]));
  // habaki collar (gold) and oval tsuba guard (gold)
  GD.push(M(await cbox(0.8, 0.6, 1.85, 0.12), gold, [0, 14.6, -0.6]));
  GD.push(M(cylinderGeo(1.5, 1.5, 0.5, 12), gold, [0, 15.1, -0.6], null, [0.75, 1, 1.1]));
  // hilt: red wrap with white diamond windows, gold pommel cap
  RD.push(M(await cbox(0.9, 4.2, 1.15, 0.3), red, [0, 17.45, -0.62]));
  for (let k = 0; k < 4; k++) WH.push(M(await cbox(0.95, 0.42, 0.42, 0.1), steel, [0, 15.95 + k * 1.0, -0.62], [45, 0, 0]));
  GD.push(M(await cbox(1.0, 0.6, 1.3, 0.2), gold, [0, 19.75, -0.62]));
  // red sageo cord tassel hanging from the guard
  RD.push(M(cylinderGeo(0.22, 0.22, 2.2, 6), red, [0, 13.9, 0.85], [0, 0, 0]));
  RD.push(M(octa(), red, [0, 12.6, 0.85], null, [0.4, 0.7, 0.4]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'BladeWhite', WH);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
