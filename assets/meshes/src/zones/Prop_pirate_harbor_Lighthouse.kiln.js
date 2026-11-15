// Lighthouse, pirate harbor. Target 12 x 40 x 12 studs. Octagonal slate plinth, tapered white
// tower with proud red bands, orange gallery and railing (zone key), yellow lamp room in a
// red frame, red cap roof, orange finial.
const meta = { name: 'Prop_pirate_harbor_Lighthouse', category: 'prop' };

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
  const slate = C('StoneDark', 0x6b7686);
  const white = C('White', 0xffffff);
  const red = C('LighthouseRed', 0xf04848);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour
  const yellow = C('Lamp', 0xffd23f);

  const Y0 = 2, Y1 = 31, R0 = 4.4, R1 = 3.0;
  const r = (y) => R0 - (R0 - R1) * ((y - Y0) / (Y1 - Y0));
  put(slate, await cy(6.4, 6.0, 2.0, 8, 0.3), [0, 1.0, 0], [0, 22.5, 0]); // base lip
  put(white, await cy(R0, R1, Y1 - Y0, 12, 0.15), [0, (Y0 + Y1) / 2, 0]);
  for (const [a, b] of [[6.5, 10.5], [15, 19], [23.5, 27.5]]) put(red, await cy(r(a) + 0.18, r(b) + 0.18, b - a, 12, 0.15), [0, (a + b) / 2, 0]);
  // Door and windows on the front (-Z).
  put(red, await bx(3.0, 4.2, 1.2, 0.25), [0, 4.0, -r(4) + 0.1]);
  put(slate, await bx(2.2, 3.4, 1.3, 0.2), [0, 3.7, -r(4) - 0.05]);
  for (const y of [12.7, 21.2]) put(slate, await bx(1.2, 1.7, 1.0, 0.2), [0, y, -r(y) + 0.15]);

  // Gallery deck + railing.
  put(orange, await cy(5.6, 5.6, 0.8, 12, 0.2), [0, Y1 + 0.4, 0]);
  put(orange, await ring(5.45, 4.95, 0.5, 12), [0, Y1 + 2.1, 0]);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    put(orange, await bx(0.45, 1.3, 0.45, 0.12), [Math.cos(a) * 5.2, Y1 + 1.3, Math.sin(a) * 5.2]);
  }
  // Lamp room with red frame bars.
  put(yellow, await cy(2.8, 2.8, 3.8, 8, 0.15), [0, Y1 + 2.7, 0], [0, 22.5, 0]);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    put(red, await bx(0.5, 3.8, 0.5, 0.12), [Math.cos(a) * 2.75, Y1 + 2.7, Math.sin(a) * 2.75], [0, -i * 45, 0]);
  }
  // Roof.
  put(red, await cy(3.7, 3.7, 0.55, 8, 0.15), [0, Y1 + 4.85, 0], [0, 22.5, 0]);
  put(red, await cy(3.5, 0.45, 3.4, 8, 0.15), [0, Y1 + 6.8, 0], [0, 22.5, 0]);
  put(orange, lobe(0.6), [0, Y1 + 8.7, 0]);

  return finish(root);
}
