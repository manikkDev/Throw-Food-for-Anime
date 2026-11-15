// Prop_samurai_castle_TaikoDrum: big festival taiko drum on a stand with two sticks,
// red body, ink mitsudomoe (tomoe) mark on the front head, gold tacks.
// Target (Roblox studs, x/y/z): 8 x 7 x 8, standing on y = 0, front -Z.
// Kiln: the drum axis runs along Kiln X so the marked head faces +X (Roblox -Z).

const meta = { name: 'Prop_samurai_castle_TaikoDrum', category: 'prop' };

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
  const root = createRoot('Prop_samurai_castle_TaikoDrum');

  const red = mat('ZoneRed', 0xe0453c);
  const white = mat('HeadWhite', 0xffffff);
  const gold = mat('Gold', 0xffc83d);
  const ink = mat('Ink', 0x0d0f2b);
  const wood = mat('Wood', 0x8a5a2b);

  const RD = [], WH = [], GD = [], IN = [], WD = [];
  const CY = 3.9, L = 3.6;

  // --- stand: dark wood base frame (base lip), legs up to a cradle on both sides ---
  for (const s of [-1, 1]) {
    WD.push(M(await cbox(7.6, 0.6, 0.9, 0.2), wood, [0, 0.3, s * 3.0]));
    WD.push(M(await cbox(0.9, 0.6, 6.9, 0.2), wood, [s * 3.35, 0.3, 0]));
    for (const sx of [-1, 1]) WD.push(M(await cbox(0.6, 3.4, 0.6, 0.15), wood, [sx * 1.4, 2.2, s * 2.9], [s * 12, 0, sx * 6]));
    WD.push(M(await cbox(3.6, 0.6, 0.8, 0.2), wood, [0, 3.6, s * 3.05]));
  }
  // --- drum body: barrel revolved around Kiln X -----------------------------------
  const prof = [[0, -L / 2], [2.6, -L / 2], [2.95, -L / 4], [3.05, 0], [2.95, L / 4], [2.6, L / 2], [0, L / 2]];
  RD.push(M(await revolveProfile(prof, { axis: 'x', segments: 18 }), red, [0, CY, 0]));
  // ink hoops just inside both heads
  for (const s of [-1, 1]) IN.push(M(cylinderXGeo(2.72, 2.72, 0.3, 18), ink, [s * (L / 2 - 0.15), CY, 0]));
  // white heads, proud of the body on both ends
  for (const s of [-1, 1]) WH.push(M(cylinderXGeo(2.5, 2.5, 0.3, 18), white, [s * (L / 2 + 0.05), CY, 0]));
  // gold tacks round both rims
  for (const s of [-1, 1]) for (let k = 0; k < 14; k++) {
    const a = (k / 14) * Math.PI * 2;
    GD.push(M(ico(0), gold, [s * (L / 2 - 0.35), CY + Math.sin(a) * 2.75, Math.cos(a) * 2.75], null, [0.24, 0.24, 0.24]));
  }
  // gold carry rings on the sides
  for (const s of [-1, 1]) GD.push(M(await revolveProfile([[0.35, -0.15], [0.7, -0.15], [0.7, 0.15], [0.35, 0.15]], { axis: 'z', segments: 10 }), gold, [0, CY + 1.2, s * 3.05]));

  // --- mitsudomoe on the front head: three commas (head disc + tail) ----------------
  const FX = L / 2 + 0.25;
  const tail = [[0, 0.55], [0.55, 0.15], [0.9, -0.6], [0.55, -1.25], [0.6, -0.55], [0.25, -0.1], [-0.3, 0.1]];
  for (let k = 0; k < 3; k++) {
    const a = (k * 2 * Math.PI) / 3 + Math.PI / 2;
    const cz = Math.cos(a) * 0.85, cy = Math.sin(a) * 0.85;
    IN.push(M(cylinderXGeo(0.55, 0.55, 0.25, 12), ink, [FX, CY + cy, -cz]));
    const t = await extrudeProfile(tail, { depth: 0.25, axis: 'x' });
    IN.push(M(t, ink, [FX, CY + cy, -cz], [-(a / D) + 90, 0, 0]));
  }

  // --- bachi sticks crossed on top of the drum ---------------------------------------
  for (const s of [-1, 1]) WD.push(M(cylinderZGeo(0.26, 0.3, 4.0, 8), wood, [s * 0.5, CY + 3.25, 0], [0, s * 28, 0]));
  for (const s of [-1, 1]) RD.push(M(cylinderZGeo(0.34, 0.34, 0.5, 8), red, [s * 0.5 - Math.sin(s * 28 * D) * 1.7, CY + 3.25, -Math.cos(s * 28 * D) * 1.7], [0, s * 28, 0]));

  await fuse(root, 'Wood', WD);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Ink', IN);
  await fuse(root, 'HeadWhite', WH);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
