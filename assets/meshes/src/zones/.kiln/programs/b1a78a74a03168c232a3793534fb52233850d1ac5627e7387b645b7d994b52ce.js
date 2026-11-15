// Palm tree, pirate harbor. Target 9 x 15 x 9 studs. Curved trunk of stacked cups with dark
// rings, five fat drooping fronds, coconut cluster, sand mound base, orange rope band (zone key).
const meta = { name: 'Prop_pirate_harbor_PalmTree', category: 'prop' };

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
  const sand = C('Sand', 0xf4d58a);
  const wood = C('Trunk', 0xb5793f);
  const dark = C('Ring', 0x8a5a2b);
  const leaf = C('Frond', 0x5bd43a);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour

  // Sand mound.
  put(sand, await cy(3.1, 2.5, 0.8, 12, 0.3), [0, 0.4, 0]);

  // Trunk: curve leaning +X, six cups, each wider at its top, with a dark ring on the lip.
  const N = 6, H0 = 0.6, H1 = 12.6, LEAN = 2.4;
  const P = (t) => [LEAN * t * t, H0 + (H1 - H0) * t, 0];
  for (let i = 0; i < N; i++) {
    const t0 = i / N, t1 = (i + 1) / N, tm = (t0 + t1) / 2;
    const a = P(t0), b = P(t1), m = P(tm);
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]) + 0.15;
    const ang = -Math.atan2(b[0] - a[0], b[1] - a[1]) / D2R;
    const r = 1.05 - 0.35 * tm;
    put(wood, await cy(r * 0.82, r, len, 8, 0.12), m, [0, 0, ang]);
    if (i < N - 1) put(dark, await cy(r + 0.12, r + 0.12, 0.45, 8, 0.1), [b[0], b[1] - 0.15, b[2]], [0, 0, ang]);
  }
  // Orange rope band near the base.
  put(orange, await cy(1.25, 1.25, 0.6, 10, 0.15), [P(0.12)[0], P(0.12)[1], 0]);

  // Crown hub.
  const T = P(1);
  put(dark, lobe(0.9), [T[0], T[1] + 0.2, 0], [0, 0, 0], [1, 0.8, 1]);

  // Five fronds: lens profile, arching up then drooping, widest a third of the way out.
  const prof = [[-1, 0], [-0.55, 0.25], [0.55, 0.25], [1, 0], [0.55, -0.25], [-0.55, -0.25]];
  for (let k = 0; k < 5; k++) {
    const az = (k / 5) * Math.PI * 2 + 0.3;
    const dx = Math.cos(az), dz = Math.sin(az);
    const pts = [], sc = [];
    const S = 6;
    for (let j = 0; j <= S; j++) {
      const s = (j / S) * 4.6;
      pts.push([T[0] + dx * s, T[1] + 0.3 + 0.95 * s - 0.24 * s * s, dz * s]);
      const w = j === 0 ? 0.45 : j === S ? 0.35 : 1.0 - 0.09 * Math.abs(j - 2);
      sc.push([w, 1]);
    }
    put(leaf, sweepProfile(prof, pts, { cap: true, up: [0, 1, 0], scale: sc }));
  }

  // Coconuts under the crown.
  for (const [ox, oz] of [[0.75, 0.2], [-0.35, 0.7], [-0.25, -0.75]]) put(dark, lobe(0.55), [T[0] + ox, T[1] - 0.5, oz]);

  return finish(root);
}
