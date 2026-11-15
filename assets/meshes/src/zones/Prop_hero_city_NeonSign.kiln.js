// Prop_hero_city_NeonSign: big neon ramen-bowl sign on a pole, with chopsticks and steam.
// Cyan tubes (zone key) for the bowl and steam, pink tubes (#FF8FC0, as the kit asks) for the
// noodles and frame, gold chopsticks, on an ink board. Tubes are 0.44 studs thick.
// Target (Roblox studs, x/y/z): 12 x 9 x 2, standing on y = 0, front -Z.
// Kiln: board in the Kiln Z-Y plane, tubes on its +X face. Board-local u maps to Kiln -Z.

const meta = { name: 'Prop_hero_city_NeonSign', category: 'prop' };

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

const HEX = [];
for (let i = 0; i < 6; i++) HEX.push([Math.cos((i / 6) * Math.PI * 2), Math.sin((i / 6) * Math.PI * 2)]);
const BY = 5.95, FX = 0.42, R = 0.22;
const P = (u, v) => [FX, BY + v, -u];
function tube(m, uv) {
  const pts = uv.map(([u, v]) => P(u, v));
  const g = sweepProfile(HEX, pts, { cap: true, scale: pts.map(() => [R, R]) });
  return M(mergeVertices(g, { positionOnly: true }), m, [0, 0, 0]);
}

async function build() {
  const root = createRoot('Prop_hero_city_NeonSign');

  const dark = mat('StoneDark', 0x6b7686);
  const ink = mat('BoardInk', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const pink = mat('NeonPink', 0xff8fc0);
  const gold = mat('Gold', 0xffc83d);

  const DK = [], IN = [], CY = [], PK = [], GD = [];

  // base, pole, bracket
  DK.push(M(await cbox(2.0, 0.5, 3.0, 0.2), dark, [0, 0.25, 0]));
  DK.push(M(cylinderGeo(0.4, 0.45, 3.0, 8), dark, [0, 1.9, 0]));
  DK.push(M(await cbox(0.9, 0.4, 4.0, 0.15), dark, [-0.2, 3.1, 0]));
  // board
  IN.push(M(await cbox(0.6, 5.8, 11.6, 0.3), ink, [-0.05, BY, 0]));
  // pink frame (four tubes)
  PK.push(tube(pink, [[-5.5, -2.6], [5.5, -2.6]]));
  PK.push(tube(pink, [[-5.5, 2.6], [5.5, 2.6]]));
  PK.push(tube(pink, [[-5.5, -2.6], [-5.5, 2.6]]));
  PK.push(tube(pink, [[5.5, -2.6], [5.5, 2.6]]));

  // cyan bowl: rim line, lower semicircle, foot
  const C = [-0.9, -0.1], RB = 2.45;
  CY.push(tube(cyan, [[C[0] - RB - 0.3, C[1]], [C[0] + RB + 0.3, C[1]]]));
  const arc = [];
  for (let i = 0; i <= 10; i++) { const a = Math.PI + (i / 10) * Math.PI; arc.push([C[0] + Math.cos(a) * RB, C[1] + Math.sin(a) * RB]); }
  CY.push(tube(cyan, arc));
  CY.push(tube(cyan, [[C[0] - 1.0, C[1] - RB - 0.05], [C[0] + 1.0, C[1] - RB - 0.05]]));
  // pink noodles: two wavy strands lifted out of the bowl toward the chopsticks
  for (const du of [0.0, 0.55]) {
    const w = [];
    for (let i = 0; i <= 8; i++) { const v = 0.1 + i * 0.22; w.push([C[0] + 0.9 + du + Math.sin(i * 1.4) * 0.22, C[1] + v]); }
    PK.push(tube(pink, w));
  }
  // gold chopsticks rising out to the right
  for (const dv of [0, 0.55]) GD.push(tube(gold, [[C[0] + 0.6, C[1] + 1.3 + dv], [C[0] + 3.9, C[1] + 1.95 + dv]]));
  // cyan steam: three S-curls above the rim
  for (const u0 of [-2.4, -1.4]) {
    const s = [];
    for (let i = 0; i <= 8; i++) { const v = 0.55 + i * 0.22; s.push([C[0] + u0 + Math.sin(i * 0.9) * 0.3, C[1] + v]); }
    CY.push(tube(cyan, s));
  }
  // pink "open" dot cluster on the right side of the board
  for (const [u, v] of [[4.3, -1.6], [4.3, -0.6], [4.3, 0.4]]) PK.push(M(ico(1), pink, P(u, v), null, [0.38, 0.38, 0.38]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'BoardInk', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'NeonPink', PK);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
