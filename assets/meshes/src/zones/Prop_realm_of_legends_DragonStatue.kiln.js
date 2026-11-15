// Prop_realm_of_legends_DragonStatue: coiled eastern dragon rising from a cloud base.
// Violet scales (zone key), gold horns, whiskers and claws, lilac fins and mane, white pearl in claw.
// Target (Roblox studs, x/y/z): 20 x 24 x 14, standing on y = 0, front -Z. Budget 6000 tris.
// Kiln: width along Kiln Z, depth along Kiln X, the head faces +X (Roblox -Z).

const meta = { name: 'Prop_realm_of_legends_DragonStatue', category: 'prop' };

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
for (let i = 0; i < 8; i++) OCT.push([Math.cos((i / 8) * Math.PI * 2 + Math.PI / 8), Math.sin((i / 8) * Math.PI * 2 + Math.PI / 8)]);
// capped octagonal tube along points, radius per station (closed solid, so it can be unioned)
function tube(m, pts, radii) {
  const g = sweepProfile(OCT, pts, { cap: true, scale: radii.map((r) => [r, r]) });
  return M(mergeVertices(g, { positionOnly: true }), m, [0, 0, 0]);
}
async function dome() {
  return revolveProfile([[0, 0], [1, 0], [0.96, 0.3], [0.84, 0.58], [0.62, 0.82], [0.32, 0.97], [0, 1]], { segments: 10 });
}

async function build() {
  const root = createRoot('Prop_realm_of_legends_DragonStatue');

  const violet = mat('ZoneViolet', 0xa66bff);
  const gold = mat('Gold', 0xffc83d);
  const lilac = mat('FinLilac', 0xd9c2ff);
  const white = mat('CloudWhite', 0xffffff);
  const dark = mat('StoneDark', 0x6b7686);

  const VI = [], GD = [], LI = [], WH = [], DK = [];

  // --- cloud base on a dark stone lip --------------------------------------
  const d = await dome();
  const clouds = [[0, 0, 5.2, 3.6, 6.0], [-1.2, -5.6, 4.0, 3.0, 4.2], [0.8, 5.8, 4.2, 3.2, 4.0], [3.0, -1.5, 3.2, 2.6, 3.4], [-3.4, 2.2, 3.2, 2.8, 3.6], [1.6, 8.6, 2.4, 2.0, 2.4], [-0.4, -8.8, 2.4, 2.0, 2.4]];
  for (const [x, z, rx, h, rz] of clouds) {
    WH.push(M(d, white, [x, 0.6, z], [0, x * 13 + z * 7, 0], [rx, h, rz]));
    DK.push(M(await revolveProfile([[0, 0], [1, 0], [1, 1], [0, 1]], { segments: 10 }), dark, [x, 0, z], [0, x * 13 + z * 7, 0], [rx + 0.3, 0.65, rz + 0.3]));
  }

  // --- coiled body: elliptical helix rising out of the cloud, then the neck ---
  const pts = [], radii = [];
  const N = 26, A0 = Math.PI - 2.15 * Math.PI;
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    const a = A0 + t * 2.15 * Math.PI;
    const R = 5.2 - 1.6 * t;
    pts.push([R * Math.cos(a) * 0.95, 3.0 + 12.4 * t, R * Math.sin(a) * 1.45]);
    radii.push(t < 0.25 ? 0.4 + (1.9 - 0.4) * (t / 0.25) : 1.9); // was 1.45: read thin on the sheet
  }
  // neck: up from the back of the coil and forward to the head
  for (const [p, r] of [[[-2.2, 17.2, 0], 1.75], [[-0.8, 18.8, 0], 1.6], [[0.8, 19.6, 0], 1.45]]) { pts.push(p); radii.push(r); }
  VI.push(tube(violet, pts, radii));

  // tail flame (lilac) at the tail tip
  LI.push(M(octa(), lilac, pts[0], [0, 0, 35], [0.9, 1.8, 0.9]));
  // spine fins along the coil top
  for (let i = 4; i <= N; i += 2) {
    const [x, y, z] = pts[i];
    LI.push(M(octa(), lilac, [x, y + radii[i] * 0.95, z], [0, 45, 0], [0.6, 1.2, 0.6]));
  }

  // --- head ------------------------------------------------------------------
  const HX = 2.6, HY = 20.2, HS = 1.3; // head scaled 1.3x after the first sheet
  const H = (x, y, z) => [HX + (x - HX) * HS, HY + (y - HY) * HS, z * HS];
  const HM = (geo, m, p, rot, scl) => M(geo, m, H(...p), rot, (scl || [1, 1, 1]).map((v) => v * HS));
  VI.push(HM(await cbox(3.4, 2.1, 2.5, 0.45), violet, [HX, HY, 0]));                    // skull
  VI.push(HM(await cbox(2.4, 1.3, 1.9, 0.35), violet, [HX + 2.4, HY - 0.15, 0]));       // snout
  VI.push(HM(await cbox(2.4, 0.6, 1.6, 0.2), violet, [HX + 2.0, HY - 1.15, 0], [0, 0, -14])); // open jaw
  for (const s of [-1, 1]) {
    GD.push(HM(ico(0), gold, [HX + 1.1, HY + 0.5, s * 1.15], null, [0.4, 0.4, 0.4]));   // eyes
    GD.push(HM(cylinderGeo(0.08, 0.4, 3.4, 6), gold, [HX - 1.6, HY + 1.9, s * 0.8], [s * 14, 0, 52])); // horns
    // whiskers: long gold tubes swept back from the snout
    GD.push(tube(gold, [H(HX + 3.4, HY - 0.3, s * 0.9), H(HX + 3.0, HY - 0.6, s * 2.1), H(HX + 1.8, HY - 1.4, s * 3.2), H(HX + 0.4, HY - 2.4, s * 3.7)], [0.26, 0.26, 0.24, 0.22]));
  }
  // mane: lilac spikes behind the head
  for (const [y, z, rz] of [[HY + 0.6, 1.1, 30], [HY + 0.6, -1.1, -30], [HY - 0.3, 1.3, 60], [HY - 0.3, -1.3, -60], [HY + 1.2, 0, 0]]) {
    LI.push(HM(octa(), lilac, [HX - 2.0, y, z], [rz, 0, 60], [0.5, 1.5, 0.5]));
  }

  // --- front claw holding the pearl, back leg -------------------------------
  const a = pts[Math.round(N * 0.88)];
  VI.push(tube(violet, [a, [a[0] + 2.2, a[1] - 1.0, a[2] + 1.0], [5.0, 13.8, 3.0]], [0.75, 0.65, 0.55]));
  WH.push(M(ico(1), white, [5.7, 14.6, 3.3], null, [1.15, 1.15, 1.15]));                // pearl
  for (const [dy, dz] of [[-0.9, -0.7], [-0.9, 0.7], [0.0, -1.0]]) GD.push(M(cylinderGeo(0.05, 0.28, 1.2, 5), gold, [5.4, 14.6 + dy, 3.3 + dz], [dz * 40, 0, -30]));
  const b = pts[Math.round(N * 0.45)];
  VI.push(tube(violet, [b, [b[0] + 1.6, b[1] - 1.4, b[2]], [b[0] + 2.4, b[1] - 2.6, b[2]]], [0.7, 0.6, 0.5]));
  for (const dz of [-0.5, 0, 0.5]) GD.push(M(cylinderGeo(0.05, 0.25, 1.0, 5), gold, [b[0] + 2.8, b[1] - 3.0, b[2] + dz], [0, 0, -60]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'CloudWhite', WH);
  await fuse(root, 'ZoneViolet', VI);
  await fuse(root, 'FinLilac', LI);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
