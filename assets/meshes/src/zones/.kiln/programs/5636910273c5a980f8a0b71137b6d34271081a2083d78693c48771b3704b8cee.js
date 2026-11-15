// Koinobori pole, shared SET PIECE. Target 6 x 18 x 2 studs. White pole on a red foot block,
// yellow four-blade pinwheel and ball on top, three carp streamers flying toward +X
// (blue, red, pink) with white mouth rings, white eyes and forked tails.
// Shared trim: yellow + white.
const meta = { name: 'Prop_shared_KoiFlagPole', category: 'prop' };

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
    let u = null;
    if (solids.length > 1) {
      try {
        u = await boolUnion(mat.name, ...solids);
      } catch (e) {
        // Coincident faces/vertices between operands can make Manifold reject the set
        // ("Not manifold"). Fold operands in one at a time; any that break it stay loose
        // (the converter still joins by colour) and the root name records it.
        u = solids[0];
        for (let i = 1; i < solids.length; i++) {
          try {
            u = await boolUnion(mat.name, u, solids[i]);
          } catch (e2) {
            loose.push(solids[i]);
            root.name += `__loose_${mat.name}_${i}`;
          }
        }
      }
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

async function carp(mat, white, x0, y, len, r) {
  const N = 8, pts = [], sc = [];
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    pts.push([x0 + t * len, y + 0.3 * Math.sin(t * Math.PI * 1.6) - 0.4 * t, 0]);
    const s = r * (1 - 0.55 * t);
    sc.push([s, s]);
  }
  const prof = [];
  for (let i = 0; i < 10; i++) { const a = (i / 10) * Math.PI * 2; prof.push([Math.cos(a), Math.sin(a)]); }
  put(mat, sweepProfile(prof, pts, { cap: true, scale: sc }));
  put(white, (await ring(r + 0.12, r - 0.35, 0.45, 10)).rotateZ(Math.PI / 2), [x0 + 0.1, y, 0]);
  for (const sz of [-1, 1]) put(white, lobe(0.3, 1), [x0 + 0.65, y + 0.25, sz * r * 0.82]);
  const e = pts[N];
  put(mat, await extrudeProfile([[0, 0], [1.3, 0.85], [0.85, 0], [1.3, -0.85]], { depth: 0.4, axis: 'z', center: true }), [e[0] - 0.3, e[1], 0]);
}

async function build() {
  const root = createRoot(meta.name);
  const white = C('White', 0xffffff);
  const red = C('Red', 0xf04848);
  const blue = C('Blue', 0x38bdf8);
  const pink = C('Pink', 0xff8fc0);
  const yellow = C('Yellow', 0xffd23f);

  const PX = -2.2;
  put(red, await bx(2.0, 0.8, 2.0, 0.22), [PX, 0.4, 0]);
  put(white, await cy(0.3, 0.25, 16.6, 8, 0.08), [PX, 8.9, 0]);
  put(yellow, lobe(0.5, 1), [PX, 17.3, 0]);
  for (let i = 0; i < 4; i++) {
    put(yellow, await extrudeProfile([[0, 0], [1.25, 0.25], [0.35, 1.1]], { depth: 0.4, axis: 'z', center: true }), [PX, 16.4, -0.55], [0, 0, i * 90]);
  }
  put(white, (await cy(0.35, 0.35, 0.6, 8, 0.08)).rotateX(Math.PI / 2), [PX, 16.4, -0.45]);
  await carp(blue, white, PX + 0.25, 14.6, 3.9, 0.95);
  await carp(red, white, PX + 0.25, 11.6, 3.5, 0.85);
  await carp(pink, white, PX + 0.25, 8.8, 3.1, 0.78);
  return finish(root);
}
