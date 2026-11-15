// Prop_realm_of_legends_FloatingShrine: small shrine on a floating rock with hanging vines and
// two stone lanterns. Violet roof and lantern flames are the zone trim.
// Target (Roblox studs, x/y/z): 18 x 16 x 18. Lowest point is the rock tip at y = 0 (the map lifts it).
// Kiln: the shrine faces +X (Roblox -Z).

const meta = { name: 'Prop_realm_of_legends_FloatingShrine', category: 'prop' };

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

const OCT = [];
for (let i = 0; i < 6; i++) OCT.push([Math.cos((i / 6) * Math.PI * 2), Math.sin((i / 6) * Math.PI * 2)]);
function tube(m, pts, r) {
  const g = sweepProfile(OCT, pts, { cap: true, scale: pts.map(() => [r, r]) });
  return M(mergeVertices(g, { positionOnly: true }), m, [0, 0, 0]);
}

async function build() {
  const root = createRoot('Prop_realm_of_legends_FloatingShrine');

  const grass = mat('Grass', 0x5bd43a);
  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const wood = mat('Wood', 0xb5793f);
  const violet = mat('ZoneViolet', 0xa66bff);

  const GR = [], S = [], DK = [], WD = [], VI = [];
  const lobe = ico(1), lobe0 = ico(0);

  // --- grass top --------------------------------------------------------------
  for (const [x, z, r] of [[0, 0, 6.6], [4.6, 2.4, 4.4], [-4.4, 2.6, 4.2], [-2.0, -5.0, 4.4], [3.0, -4.6, 4.2]]) {
    GR.push(M(await revolveProfile([[0, 0], [r, 0], [r, 1.3], [0, 1.3]], { segments: 9, bevel: 0.3, bevelSegments: 1 }), grass, [x, 8.0, z], [0, x * 7 + z * 3, 0]));
  }
  // --- rock underside: light lobes above, dark toward the tip ------------------
  for (const [x, y, z, sx, sy, sz] of [[0, 6.9, 0, 8.0, 2.6, 8.0], [4.0, 7.0, 2.0, 4.6, 2.0, 4.6], [-4.0, 7.0, 2.2, 4.4, 2.0, 4.4], [-1.8, 7.0, -4.4, 4.4, 2.0, 4.4], [2.8, 7.0, -4.2, 4.2, 2.0, 4.2], [0.3, 4.6, 0.3, 5.8, 2.8, 5.8]]) {
    S.push(M(lobe, stone, [x, y, z], [0, x * 11 + z * 5, 0], [sx, sy, sz]));
  }
  for (const [x, y, z, sx, sy, sz] of [[0.6, 2.9, 0.2, 3.8, 2.4, 3.8], [0.5, 1.1, 0.5, 1.6, 1.2, 1.6]]) {
    DK.push(M(lobe0, dark, [x, y, z], [17, x * 13, 9], [sx, sy, sz]));
  }
  // --- hanging vines with leaf tips (grass colour, merged with the top) --------
  const vines = [[7.4, 1.0, 4.2], [5.0, 6.0, 5.0], [-3.0, 7.2, 3.6], [-7.6, -1.0, 4.6], [-2.0, -8.0, 3.8], [4.6, -6.6, 5.2]];
  for (const [x, z, len] of vines) {
    const k = 0.94;
    GR.push(tube(grass, [[x * k, 8.4, z * k], [x * 1.0, 7.0, z * 1.0], [x * 1.02, 7.0 - len * 0.6, z * 1.02], [x * 0.98, 7.0 - len, z * 0.98]], 0.28));
    GR.push(M(octa(), grass, [x * 0.98, 7.0 - len - 0.2, z * 0.98], [0, 45, 0], [0.6, 0.8, 0.6]));
  }

  // --- the shrine: dark stone plinth, wood body and porch, violet roof ---------
  DK.push(M(await cbox(6.4, 0.6, 7.0, 0.2), dark, [-0.6, 9.6, 0]));
  WD.push(M(await cbox(4.2, 3.0, 5.0, 0.25), wood, [-1.2, 11.4, 0]));
  for (const s of [-1, 1]) WD.push(M(cylinderGeo(0.3, 0.3, 3.0, 8), wood, [2.3, 11.4, s * 2.2]));
  for (let i = 0; i < 3; i++) WD.push(M(await cbox(0.8, 0.3, 2.4, 0.1), wood, [3.4 + i * 0.7, 9.75 - i * 0.3, 0]));
  // nagare roof: ridge along Kiln Z, long front slope over the porch
  const roof = await extrudeProfile([[-3.6, -0.1], [3.5, -0.5], [3.5, -0.05], [0, 2.3], [-0.6, 2.3], [-3.6, 0.35]], { depth: 6.6, axis: 'z', bevel: 0.15, bevelStyle: 'chamfer' });
  VI.push(M(roof, violet, [-0.9, 12.9, 0]));
  // crossed chigi on the ridge ends
  for (const s of [-1, 1]) for (const r of [-30, 30]) VI.push(M(await cbox(0.4, 1.8, 0.4, 0.1), violet, [-1.2, 15.3, s * 3.1], [0, 0, r]));
  // violet crystals in the rock flanks
  VI.push(M(octa(), violet, [-6.2, 5.6, -1.6], [0, 45, 55], [0.7, 1.7, 0.7]));
  VI.push(M(octa(), violet, [2.6, 4.2, 5.4], [-55, 45, 0], [0.7, 1.5, 0.7]));

  // --- two stone lanterns flanking the approach -------------------------------
  for (const s of [-1, 1]) {
    const x = 4.6, z = s * 3.6;
    DK.push(M(await cbox(1.2, 0.35, 1.2, 0.1), dark, [x, 9.55, z]));
    S.push(M(cylinderGeo(0.28, 0.32, 1.4, 6), stone, [x, 10.4, z]));
    S.push(M(await cbox(0.95, 0.25, 0.95, 0.08), stone, [x, 11.2, z]));
    VI.push(M(await cbox(0.65, 0.8, 0.65, 0.12), violet, [x, 11.7, z]));
    S.push(M(await revolveProfile([[0, 0], [0.95, 0], [0.95, 0.15], [0.2, 0.6], [0, 0.6]], { segments: 6 }), stone, [x, 12.1, z]));
  }

  await fuse(root, 'Grass', GR);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Wood', WD);
  await fuse(root, 'ZoneViolet', VI);
  return finish(root);
}
