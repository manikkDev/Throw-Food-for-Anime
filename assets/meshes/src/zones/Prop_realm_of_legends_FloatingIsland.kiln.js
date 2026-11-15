// Prop_realm_of_legends_FloatingIsland: floating rock island, grass top, tapering rock
// underside, a small waterfall slab. The realm_of_legends zone landmark.
// Target (Roblox studs, x/y/z): 28 x 16 x 28. Its rock tip is y = 0 (the map floats it).
// Front -Z (Kiln +X) carries the waterfall.

const meta = { name: 'Prop_realm_of_legends_FloatingIsland', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_FloatingIsland');

  const grass = mat('Grass', 0x5bd43a);
  const rock = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const water = mat('Water', 0x38bdf8);
  const violet = mat('ZoneViolet', 0xa66bff);

  const GR = [], RK = [], DK = [], WA = [], VI = [];
  const lobe = ico(1);
  const lobe0 = ico(0);

  // --- grass top: lobed slab of chamfered 9-gon cylinders ---------------
  const grassLobes = [[0, 0, 9.6], [6.8, 3.2, 6.4], [-6.6, 3.6, 6.2], [-3.0, -7.2, 6.4], [4.4, -6.8, 6.0], [7.6, -2.6, 5.4]];
  for (const [x, z, r] of grassLobes) {
    GR.push(M(await revolveProfile([[0, 0], [r, 0], [r, 1.7], [0, 1.7]], { segments: 9, bevel: 0.35, bevelSegments: 1 }), grass, [x, 12.6, z], [0, x * 7 + z * 3, 0]));
  }

  // --- rock underside: chunky faceted lobes, light above, dark toward the tip
  const rockLobes = [
    // [x, y, z, sx, sy, sz]
    [0, 10.6, 0, 11.6, 3.4, 11.6],
    [6.0, 10.8, 2.8, 6.6, 2.6, 6.6],
    [-6.0, 10.8, 3.2, 6.4, 2.6, 6.4],
    [-2.6, 10.8, -6.4, 6.4, 2.6, 6.4],
    [4.0, 10.8, -6.0, 6.2, 2.6, 6.2],
    [0.5, 7.4, 0.5, 8.6, 3.6, 8.6],
    [3.6, 8.0, -2.6, 5.0, 2.6, 5.0],
    [-3.4, 8.0, 2.0, 5.2, 2.8, 5.2],
  ];
  for (const [x, y, z, sx, sy, sz] of rockLobes) RK.push(M(lobe, rock, [x, y, z], [0, x * 11 + z * 5, 0], [sx, sy, sz]));
  const darkLobes = [
    [0.8, 4.6, 0.2, 5.6, 3.2, 5.6],
    [-1.6, 5.2, -1.8, 3.6, 2.4, 3.6],
    [0.8, 2.2, 0.8, 3.0, 2.4, 3.0],
    [0.9, 0.9, 0.6, 1.4, 0.9, 1.4],
  ];
  for (const [x, y, z, sx, sy, sz] of darkLobes) DK.push(M(lobe0, dark, [x, y, z], [17, x * 13 + z * 7, 9], [sx, sy, sz]));

  // --- waterfall: pool on the grass, channel to the front lip, slab falling over it
  WA.push(M(await revolveProfile([[0, 0], [2.6, 0], [2.6, 0.5], [0, 0.5]], { segments: 10, bevel: 0.15, bevelSegments: 1 }), water, [7.2, 14.05, -1.0]));
  WA.push(M(await cbox(6.4, 0.5, 2.4, 0.15), water, [10.6, 14.3, -1.0]));
  WA.push(M(await cbox(0.8, 9.0, 2.6, 0.3), water, [13.55, 10.0, -1.0]));
  // splash: rounded lobe at the foot of the fall
  WA.push(M(lobe, water, [13.55, 5.5, -1.0], null, [0.9, 0.8, 1.6]));

  // --- violet crystal cluster on top (zone trim) + shards in the rock -----
  const gem = octa();
  const crystals = [
    [-5.2, 14.6, -4.0, 0, 0, 1.15, 1.7],
    [-3.8, 14.6, -5.2, 22, 15, 0.85, 1.9],
    [-6.6, 14.6, -2.8, -20, -10, 0.85, 1.9],
    [-4.0, 14.4, -2.6, 10, -25, 0.7, 1.5],
    [3.0, 14.4, 6.6, 15, 10, 0.7, 1.6],
    [4.2, 14.3, 7.4, -15, -20, 0.55, 1.2],
  ];
  for (const [x, y, z, ax, az, g, len] of crystals) VI.push(M(gem, violet, [x, y, z], [ax, 45, az], [g, len, g]));
  // shards sticking out of the rock flanks
  VI.push(M(gem, violet, [-7.6, 7.6, -1.0], [0, 45, 60], [0.7, 1.8, 0.7]));
  VI.push(M(gem, violet, [2.0, 6.6, 7.0], [-60, 45, 0], [0.7, 1.6, 0.7]));

  // widen across Roblox x (Kiln Z) to the 28-stud target: measured 25.05 before this
  for (const o of [...GR, ...RK, ...DK, ...WA, ...VI]) { o.position.z *= 1.12; o.scale.z *= 1.12; o.updateMatrixWorld(true); }
  await fuse(root, 'Grass', GR);
  await fuse(root, 'StoneLight', RK);
  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'Water', WA);
  await fuse(root, 'ZoneViolet', VI);
  return finish(root);
}
