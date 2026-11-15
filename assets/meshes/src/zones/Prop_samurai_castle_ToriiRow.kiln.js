// Prop_samurai_castle_ToriiRow: tunnel of five red torii gates in a row over a stone path.
// Target (Roblox studs, x/y/z): 10 x 10 x 22, standing on y = 0, front -Z.
// Kiln: the 22-stud run goes along Kiln X (Roblox z, walk front to back), width along Kiln Z.

const meta = { name: 'Prop_samurai_castle_ToriiRow', category: 'prop' };

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
  const root = createRoot('Prop_samurai_castle_ToriiRow');

  const red = mat('ZoneRed', 0xe0453c);
  const ink = mat('Ink', 0x0d0f2b);
  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const gold = mat('Gold', 0xffc83d);

  const RD = [], IN = [], S = [], DK = [], GD = [];

  // dark gravel bed (base lip) and light stepping stones along it
  DK.push(M(await cbox(22.0, 0.35, 5.6, 0.15), dark, [0, 0.175, 0]));
  for (let i = 0; i < 6; i++) S.push(M(await cbox(2.8, 0.35, 3.6, 0.15), stone, [-9.2 + i * 3.68, 0.5, (i % 2 ? 0.25 : -0.25)], [0, i % 2 ? 6 : -6, 0]));

  // five torii, all the same, 4.4 studs apart
  const PZ = 3.5, HALF = 4.85, RISE = 0.6, T = 0.75;
  const top = [], bot = [];
  for (let i = 0; i <= 10; i++) {
    const u = -HALF + (2 * HALF * i) / 10;
    const lift = RISE * Math.pow(Math.abs(u) / HALF, 3);
    bot.push([u, lift]);
    top.push([u, lift + T]);
  }
  const kasagi = await extrudeProfile([...bot, ...top.reverse()], { depth: 1.0, axis: 'x', bevel: 0.12, bevelStyle: 'chamfer' });
  const foot = await cbox(1.3, 0.7, 1.3, 0.2);
  const nuki = await cbox(0.55, 0.55, 8.6, 0.15);
  const shimaki = await cbox(0.75, 0.6, 8.9, 0.18);
  for (let g = 0; g < 5; g++) {
    const x = -8.8 + g * 4.4;
    for (const s of [-1, 1]) {
      DK.push(M(foot, dark, [x, 0.35, s * PZ]));
      RD.push(M(cylinderGeo(0.42, 0.48, 8.2, 8), red, [x, 4.6, s * PZ]));
    }
    RD.push(M(nuki, red, [x, 7.1, 0]));
    RD.push(M(shimaki, red, [x, 8.85, 0]));
    IN.push(M(kasagi, ink, [x, 9.15, 0]));
  }
  // gold plaque on the front gate, and gold caps on the front gate's kasagi tips
  RD.push(M(await cbox(0.5, 1.2, 0.5, 0.1), red, [8.8, 7.95, 0]));
  GD.push(M(await cbox(0.45, 1.5, 1.2, 0.15), gold, [9.15, 7.95, 0]));
  for (const s of [-1, 1]) GD.push(M(await cbox(1.1, 0.95, 0.35, 0.1), gold, [8.8, 9.15 + RISE + T / 2, s * (HALF + 0.05)]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
