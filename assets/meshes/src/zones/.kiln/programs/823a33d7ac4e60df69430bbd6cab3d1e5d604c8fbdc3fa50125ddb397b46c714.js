// School gate, sakura schoolyard. Target 26 x 12 x 4 studs. Two brick pillars with stone
// caps and base lips, a half-open sliding gate on a track, a name plate on a pink beam.
const meta = { name: 'Prop_sakura_schoolyard_SchoolGate', category: 'prop' };

// ---- PRELUDE BEGIN (shared by every zone prop; edit _prelude.js; build.py copies it in) ----
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
  const brick = C('Brick', 0xd0603f);
  const stoneDark = C('StoneDark', 0x6b7686);
  const stone = C('Stone', 0x9aa4b2);
  const pink = C('Sakura', 0xff8fc0); // zone key colour
  const white = C('Plate', 0xffffff);

  for (const sx of [-1, 1]) {
    const x = sx * 11.3;
    // darker base lip, brick shaft, brick courses (proud bands), stone cap, pink cap trim
    put(stoneDark, await bx(3.8, 1.0, 4.0, 0.25), [x, 0.5, 0]);
    put(brick, await bx(3.2, 8.6, 3.4, 0.25), [x, 5.2, 0]);
    for (const y of [3.0, 6.0]) put(stoneDark, await bx(3.4, 0.45, 3.6, 0.15), [x, y, 0]);
    put(stone, await bx(3.7, 0.8, 3.9, 0.25), [x, 9.85, 0]);
    put(pink, await bx(3.1, 0.6, 3.3, 0.22), [x, 10.5, 0]);
    put(stone, lobe(0.75), [x, 11.0, 0], [0, 0, 0], [1, 0.75, 1]);
  }

  // Pink beam between the pillar tops, white name plate on it with a pink frame.
  put(pink, await bx(19.2, 0.9, 1.2, 0.22), [0, 9.75, 0]);
  put(pink, await bx(8.2, 2.7, 0.8, 0.25), [0, 10.8, -0.1]);
  put(white, await bx(7.2, 1.9, 0.9, 0.2), [0, 10.8, -0.2]);
  // Two ink-dark "characters" on the plate (stone dark blocks read as lettering at distance).
  for (const x of [-2.2, -0.75, 0.75, 2.2]) put(stoneDark, await bx(0.9, 1.0, 0.4, 0.12), [x, 10.8, -0.62]);

  // Floor track between the pillars.
  put(stoneDark, await bx(19.2, 0.45, 1.6, 0.15), [0, 0.225, 0]);

  // Sliding gate, pulled half open toward +X (stacked in front of the right half).
  const g0 = -9.2, g1 = 3.0, gz = -0.15;
  put(stone, await bx(g1 - g0, 0.55, 0.7, 0.2), [(g0 + g1) / 2, 1.0, gz]);
  put(pink, await bx(g1 - g0 + 0.2, 0.6, 0.8, 0.2), [(g0 + g1) / 2, 4.6, gz]);
  for (let x = g0 + 0.3; x <= g1 - 0.25; x += 1.1) put(stone, await bx(0.45, 3.5, 0.5, 0.15), [x, 2.8, gz]);
  // diagonal brace makes it read as a gate, not a fence
  const dl = Math.hypot(g1 - g0 - 1, 3.0);
  put(stone, await bx(dl, 0.45, 0.6, 0.15), [(g0 + g1) / 2, 2.8, gz], [0, 0, (Math.atan2(3.0, g1 - g0 - 1) / D2R)]);
  // wheels in the track
  for (const x of [g0 + 1, g1 - 1]) put(stoneDark, await cy(0.4, 0.4, 0.5, 8, 0.1), [x, 0.6, gz], [90, 0, 0]);

  return finish(root);
}
