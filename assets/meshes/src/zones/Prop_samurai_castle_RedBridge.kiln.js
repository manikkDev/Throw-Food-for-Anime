// Prop_samurai_castle_RedBridge: arched red bridge with railings.
// Target (Roblox studs, x/y/z): 10 x 7 x 26, standing on y = 0, front -Z.
// Kiln: the 26-stud span runs along Kiln X (Roblox z), the 10-stud width along Kiln Z.

const meta = { name: 'Prop_samurai_castle_RedBridge', category: 'prop' };

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

// arch height of the deck top at x
const SPAN = 13.0;
function archY(x) { return 1.5 + 2.7 * (1 - Math.pow(x / SPAN, 2)); }
// closed side-view band between archY+lo and archY+hi, x in [x0, x1], extruded along Kiln Z
async function archBand(m, x0, x1, lo, hi, depth, z, bev) {
  const N = 10, a = [], b = [];
  for (let i = 0; i <= N; i++) {
    const x = x0 + ((x1 - x0) * i) / N;
    a.push([x, archY(x) + lo]);
    b.push([x, archY(x) + hi]);
  }
  const g = await extrudeProfile([...a, ...b.reverse()], bev ? { depth, axis: 'z', bevel: bev, bevelStyle: 'chamfer' } : { depth, axis: 'z' });
  return M(g, m, [0, 0, z]);
}

async function build() {
  const root = createRoot('Prop_samurai_castle_RedBridge');

  const red = mat('ZoneRed', 0xe0453c);
  const wood = mat('Wood', 0xb5793f);
  const dark = mat('StoneDark', 0x6b7686);
  const gold = mat('Gold', 0xffc83d);

  const RD = [], WD = [], DK = [], GD = [];

  // stone abutments at both ends (darker base lip)
  for (const s of [-1, 1]) DK.push(M(await cbox(3.2, 1.6, 9.0, 0.3), dark, [s * 11.4, 0.8, 0]));

  // plank deck (wood), and red fascia beams along both edges
  WD.push(await archBand(wood, -SPAN, SPAN, -0.9, 0, 7.6, 0, 0.12));
  for (const s of [-1, 1]) RD.push(await archBand(red, -SPAN + 0.2, SPAN - 0.2, -1.3, 0.25, 0.7, s * 4.0, 0.12));

  // red support piers under the arch
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const x = sx * 5.5;
    const h = archY(x) - 0.9;
    RD.push(M(cylinderGeo(0.45, 0.55, h, 8), red, [x, h / 2, sz * 3.0]));
  }
  // cross beam joining each pier pair
  for (const sx of [-1, 1]) RD.push(M(await cbox(0.8, 0.7, 6.8, 0.2), red, [sx * 5.5, 1.5, 0]));

  // railings: posts along the arch, a mid rail and a top rail on each side
  const RZ = 4.55, posts = [-12.2, -8.2, -4.1, 0, 4.1, 8.2, 12.2];
  for (const s of [-1, 1]) {
    for (const x of posts) {
      const y = archY(x);
      RD.push(M(await cbox(0.7, 2.4, 0.7, 0.15), red, [x, y + 1.1, s * RZ]));
      // gold giboshi caps on the end and centre posts
      if (Math.abs(x) > 12 || x === 0) GD.push(M(ico(1), gold, [x, y + 2.65, s * RZ], null, [0.48, 0.6, 0.48]));
    }
    RD.push(await archBand(red, -12.2, 12.2, 1.75, 2.3, 0.55, s * RZ));
    RD.push(await archBand(red, -12.2, 12.2, 0.75, 1.2, 0.45, s * RZ));
  }

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Wood', WD);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
