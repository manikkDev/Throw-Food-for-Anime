// Cherry tree, sakura schoolyard. Target 11 x 14 x 11 studs. Toy-diorama: tapered trunk,
// crown of five chunky faceted lobes, grass mound as the darker base lip.
const meta = { name: 'Prop_sakura_schoolyard_CherryTree', category: 'prop' };

// ---- PRELUDE BEGIN (shared by every zone prop; edit _prelude.js and run sync_prelude.py) ----
// Authoring frame: ROBLOX studs, +Y up, front = -Z, x = width. finish() wraps everything in
// a group rotated -90 deg about Y and scaled to metres, which kiln_to_roblox.mjs undoes
// (+90 about Y, x3.571). Measured on a probe: a marker placed at z=-4.5 exported at -Z.
const STUD_M = 0.28;
const D2R = Math.PI / 180;
const MIN_T = 0.4; // art bible: nothing thinner than 0.4 studs
const BUCKETS = new Map(); // material -> [{mesh, union}]
const MATS = new Map();

function C(label, hex) {
  if (MATS.has(hex)) return MATS.get(hex);
  const m = gameMaterial(hex, { roughness: 0.85 });
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  MATS.set(hex, m);
  return m;
}

function guard(what, ...dims) {
  for (const d of dims) if (d < MIN_T - 1e-6) throw new Error(`${what}: dimension ${d} < ${MIN_T} studs`);
}

// put(material, geometry, position, rotationDeg, scale, union=true)
function put(mat, geo, pos = [0, 0, 0], rot = [0, 0, 0], scl = null, union = true) {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(pos[0], pos[1], pos[2]);
  m.rotation.set(rot[0] * D2R, rot[1] * D2R, rot[2] * D2R);
  if (scl) m.scale.set(scl[0], scl[1], scl[2]);
  m.updateMatrixWorld(true);
  if (!BUCKETS.has(mat)) BUCKETS.set(mat, []);
  BUCKETS.get(mat).push({ mesh: m, union });
  return m;
}

// Chamfered box (bible: 0.15-0.3 stud chamfers). Centered.
async function bx(w, h, d, c = 0.22) {
  guard('bx', w, h, d);
  const r = Math.min(c, 0.45 * Math.min(w, h, d));
  return roundedBoxGeo(w, h, d, r, { style: 'chamfer' });
}

// Chamfered (optionally tapered) cylinder along Y, centered. rb/rt radii.
async function cy(rb, rt, h, seg = 10, c = 0.2) {
  guard('cy', 2 * Math.min(rb, rt), h);
  const cc = Math.min(c, 0.3 * Math.min(rb, rt), 0.3 * h);
  const y0 = -h / 2, y1 = h / 2;
  const prof = [[0, y0], [rb - cc, y0], [rb, y0 + cc], [rt, y1 - cc], [rt - cc, y1], [0, y1]];
  return revolveProfile(prof, { segments: seg, smooth: false });
}

// Ring (washer) along Y: outer radius ro, inner ri, height h. Closed solid.
async function ring(ro, ri, h, seg = 12) {
  guard('ring', ro - ri, h);
  return revolveProfile([[ri, -h / 2], [ro, -h / 2], [ro, h / 2], [ri, h / 2]], { segments: seg, smooth: false });
}

// Low-poly lobe (faceted icosphere).
function lobe(r, detail = 1) {
  guard('lobe', 2 * r);
  return new THREE.IcosahedronGeometry(r, detail);
}

// Closed tube along a polyline: octagon profile swept with caps.
function tube(points, r, sides = 8) {
  guard('tube', 2 * r);
  const prof = [];
  for (let i = 0; i < sides; i++) {
    const a = (i / sides) * Math.PI * 2;
    prof.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  return sweepProfile(prof, points, { cap: true });
}

async function finish(root) {
  const g = new THREE.Group();
  g.name = 'RobloxFrame';
  g.rotation.y = -Math.PI / 2;
  g.scale.setScalar(STUD_M);
  root.add(g);
  const outs = [];
  for (const [mat, list] of BUCKETS) {
    const solids = list.filter((e) => e.union).map((e) => e.mesh);
    const loose = list.filter((e) => !e.union).map((e) => e.mesh);
    if (solids.length > 1) {
      const u = await boolUnion(mat.name, ...solids);
      u.material = mat;
      u.name = mat.name;
      outs.push(u);
    } else outs.push(...solids);
    outs.push(...loose);
  }
  // Recentre on x/z and stand on y = 0, measured from the geometry itself.
  const box = new THREE.Box3();
  for (const o of outs) {
    o.updateMatrixWorld(true);
    box.expandByObject(o);
  }
  const off = new THREE.Vector3(-(box.min.x + box.max.x) / 2, -box.min.y, -(box.min.z + box.max.z) / 2);
  const holder = new THREE.Group();
  holder.name = 'Centre';
  holder.position.copy(off);
  g.add(holder);
  for (const o of outs) holder.add(o);
  return root;
}
// ---- PRELUDE END ----

async function build() {
  const root = createRoot(meta.name);
  const bark = C('Bark', 0x8a5a2b);
  const grass = C('Grass', 0x46b82c);
  const pink = C('Sakura', 0xff8fc0); // zone key colour
  const blush = C('SakuraLight', 0xffc4dd); // lighter top band

  // Grass mound: darker base lip the tree stands in.
  put(grass, await cy(3.2, 2.6, 0.8, 12, 0.3), [0, 0.4, 0]);

  // Trunk: flared root, tapered bole, two branches into the crown.
  put(bark, await cy(1.5, 1.0, 1.4, 8, 0.3), [0, 0.9, 0]);
  put(bark, await cy(1.0, 0.7, 7.5, 8, 0.2), [0, 4.6, 0]);
  put(bark, await cy(0.6, 0.45, 3.6, 8, 0.15), [1.3, 8.1, 0.2], [0, 0, -38]);
  put(bark, await cy(0.6, 0.45, 3.4, 8, 0.15), [-1.2, 8.0, -0.4], [12, 0, 36]);

  // Crown: five lobes, squashed a little so they read chunky, not ball-like.
  const L = [
    [2.6, 9.4, 0.9, 2.9],
    [-2.5, 9.2, 1.1, 2.8],
    [0.4, 9.0, -2.5, 2.9],
    [-0.6, 9.5, 2.6, 2.6],
    [0.2, 10.6, 0.1, 3.2],
  ];
  for (const [x, y, z, r] of L) put(pink, lobe(r), [x, y, z], [0, (x * 37) % 60, 0], [1, 0.85, 1]);
  // Lighter top band: highlight lobes sitting on the crown's upper side.
  put(blush, lobe(2.0), [0.5, 12.0, 0.4], [0, 20, 0], [1, 0.8, 1]);
  put(blush, lobe(1.4), [2.6, 11.0, 0.6], [0, 50, 0], [1, 0.8, 1]);
  put(blush, lobe(1.4), [-2.3, 10.9, 1.2], [0, 10, 0], [1, 0.8, 1]);

  return finish(root);
}
