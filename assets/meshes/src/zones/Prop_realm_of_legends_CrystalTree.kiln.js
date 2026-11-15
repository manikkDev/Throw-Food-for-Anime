// Prop_realm_of_legends_CrystalTree: tree with a white trunk and a faceted violet crystal crown.
// Target (Roblox studs, x/y/z): 10 x 16 x 10, standing on y = 0, front -Z.
// Zone key colour #A66BFF is the crown itself plus the shards at the foot.

const meta = { name: 'Prop_realm_of_legends_CrystalTree', category: 'prop' };

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
  const root = createRoot('Prop_realm_of_legends_CrystalTree');

  const lip = mat('StoneDark', 0x6b7686);
  const trunkM = mat('Trunk', 0xffffff);
  const violet = mat('ZoneViolet', 0xa66bff);
  const lilac = mat('CrystalLight', 0xd9c2ff);
  const gold = mat('Gold', 0xffc83d);

  // --- base lip: same octagonal stone ring as every zone tree -------------
  const base = [
    M(await revolveProfile([[0, 0], [2.6, 0], [2.6, 0.55], [2.2, 0.75], [0, 0.75]], { segments: 8, bevel: 0.15, bevelSegments: 2 }), lip, [0, 0, 0], [0, 22.5, 0]),
  ];

  // --- white trunk: chunky faceted prism, forks into three limbs ----------
  const trunk = [
    M(cylinderGeo(0.85, 1.3, 6.4, 6), trunkM, [0, 3.2, 0]),
    // root flares
    M(cylinderGeo(0.25, 0.75, 1.6, 5), trunkM, [0, 1.0, 1.0], [32, 0, 0]),
    M(cylinderGeo(0.25, 0.75, 1.6, 5), trunkM, [0.9, 1.0, -0.6], [-20, 0, -30]),
    M(cylinderGeo(0.25, 0.75, 1.6, 5), trunkM, [-0.9, 1.0, -0.5], [-20, 0, 30]),
    // fork
    M(cylinderGeo(0.5, 0.75, 4.2, 6), trunkM, [0, 7.6, 1.0], [26, 0, 0]),
    M(cylinderGeo(0.5, 0.75, 4.2, 6), trunkM, [0.9, 7.6, -0.6], [-14, 0, -24]),
    M(cylinderGeo(0.5, 0.75, 4.0, 6), trunkM, [-0.9, 7.6, -0.6], [-14, 0, 24]),
  ];

  // --- gold collar where the trunk forks (warm highlight) ----------------
  const goldParts = [M(await revolveProfile([[0.7, 0], [1.2, 0], [1.2, 0.55], [0.7, 0.55]], { segments: 6, bevel: 0.18, bevelSegments: 1 }), gold, [0, 5.6, 0], [0, 30, 0])];

  // --- crown: chunky faceted lobes (icosahedra), violet ------------------
  const lobe = ico(0);
  const crown = [
    M(lobe, violet, [0, 11.2, 0], [0, 10, 0], [3.6, 3.0, 3.6]),
    M(lobe, violet, [0, 10.3, 2.6], [10, 40, 0], [2.4, 2.1, 2.4]),
    M(lobe, violet, [2.3, 10.1, -1.4], [0, 70, 12], [2.4, 2.1, 2.4]),
    M(lobe, violet, [-2.3, 10.2, -1.3], [0, 15, -10], [2.4, 2.1, 2.4]),
    M(lobe, violet, [1.6, 12.4, 1.4], [0, 55, 0], [2.2, 2.0, 2.2]),
    M(lobe, violet, [-1.5, 12.6, 1.2], [20, 5, 0], [2.1, 1.9, 2.1]),
    M(lobe, violet, [0.2, 12.9, -1.7], [0, 35, 20], [2.2, 2.0, 2.2]),
    M(lobe, violet, [0, 13.8, 0], [0, 0, 0], [2.0, 1.8, 2.0]),
  ];
  // --- crystal spikes: light lilac gems jutting out of the crown top and sides
  const gem = octa();
  const spikes = [];
  const spikeSpec = [
    // [x, y, z, tilt toward (deg about x), tilt (deg about z), length, girth]
    [0, 15.0, 0, 0, 0, 1.8, 0.9],
    [1.5, 14.2, 1.2, 25, -25, 1.4, 0.75],
    [-1.6, 14.1, 1.0, 25, 25, 1.4, 0.75],
    [0.3, 14.0, -1.8, -30, -8, 1.4, 0.75],
    [3.8, 11.0, -0.2, 0, -70, 1.3, 0.7],
    [-3.7, 11.2, 0.4, 0, 70, 1.3, 0.7],
    [0.4, 11.0, 3.7, 70, 0, 1.3, 0.7],
    [-0.4, 11.3, -3.7, -70, 0, 1.3, 0.7],
  ];
  for (const [x, y, z, ax, az, len, g] of spikeSpec) spikes.push(M(gem, lilac, [x, y, z], [ax, 45, az], [g, len, g]));

  // --- violet shards at the foot (zone trim on the ground) ----------------
  const shardParts = [
    M(gem, violet, [1.9, 0.9, 1.3], [20, 30, -22], [0.55, 1.2, 0.55]),
    M(gem, violet, [-1.8, 0.8, -1.5], [-18, 10, 25], [0.5, 1.0, 0.5]),
  ];
  for (const p of shardParts) crown.push(p);

  await fuse(root, 'StoneDark', base);
  await fuse(root, 'Trunk', trunk);
  await fuse(root, 'Gold', goldParts);
  await fuse(root, 'ZoneViolet', crown);
  await fuse(root, 'CrystalLight', spikes);
  return finish(root);
}
