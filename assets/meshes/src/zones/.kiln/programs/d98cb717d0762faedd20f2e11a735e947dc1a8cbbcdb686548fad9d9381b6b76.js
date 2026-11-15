// Fish market stall, pirate harbor SET PIECE. Target 12 x 9 x 8 studs. Dark wood table and
// posts, orange/white striped sloping awning with a valance (zone key), three crates of ice
// tipped toward the front holding blue and pink fish, a pink octopus and a blue fish hanging.
const meta = { name: 'Prop_pirate_harbor_FishStall', category: 'prop' };

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

async function fish(mat, x, y, z, rot, s = 1) {
  put(mat, lobe(0.55 * s, 1), [x, y, z], rot, [2.0, 0.85, 1.0]);
  put(mat, await cy(0.75 * s, 0.25, 0.9 * s, 4, 0.05), [x, y, z], [rot[0], rot[1], rot[2] + 90], null);
}

async function build() {
  const root = createRoot(meta.name);
  const dark = C('WoodDark', 0x8a5a2b);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour
  const white = C('White', 0xffffff);
  const blue = C('FishBlue', 0x38bdf8);
  const pink = C('Pink', 0xff8fc0);

  // Table.
  put(dark, await bx(11.0, 0.6, 4.6, 0.2), [0, 3.3, -0.3]);
  put(dark, await bx(10.6, 2.4, 0.5, 0.18), [0, 1.6, -2.3]); // kick board
  for (const sx of [-1, 1]) for (const z of [-2.3, 1.7]) put(dark, await bx(0.6, 3.3, 0.6, 0.15), [sx * 5.0, 1.65, z]);
  // Awning posts.
  for (const sx of [-1, 1]) {
    put(dark, await bx(0.6, 8.2, 0.6, 0.15), [sx * 5.4, 4.1, 2.6]);
    put(dark, await bx(0.6, 7.2, 0.6, 0.15), [sx * 5.4, 3.6, -3.0]);
  }
  // Striped sloped awning: back edge y 8.6 at z 3.2, front edge y 6.4 at z -3.7.
  const dz = 6.9, dy = 1.3, L = Math.hypot(dz, dy), ang = Math.atan2(dy, dz) / D2R;
  for (let i = 0; i < 6; i++) {
    const x = -4.9 + i * 1.96;
    put(i % 2 ? white : orange, await bx(2.0, 0.5, L, 0.12), [x, 8.05, -0.25], [-ang, 0, 0]);
    put(i % 2 ? orange : white, await bx(2.0, 0.9, 0.45, 0.12), [x, 7.1, -3.75]); // valance
  }
  // Crates of ice and fish, tipped toward the front.
  const tip = [-16, 0, 0];
  for (const [i, x] of [[0, -3.5], [1, 0], [2, 3.5]]) {
    put(dark, await bx(3.2, 1.0, 3.0, 0.2), [x, 4.1, -0.6], tip);
    put(white, await bx(2.7, 0.5, 2.5, 0.15), [x, 4.55, -0.73], tip);
    const m = i === 1 ? pink : blue;
    for (const [fx, fz] of [[-0.6, -0.3], [0.5, 0.5], [0.2, -1.0]]) await fish(i === 1 && fz > 0 ? blue : m, x + fx, 5.0 + fz * -0.28, -0.73 + fz, [-16, fz * 40, 0]);
  }
  // Hanging octopus (front right) and a hanging blue fish (front left).
  put(pink, lobe(0.85, 1), [3.6, 5.6, -3.75], [0, 0, 0], [1, 1.2, 1]);
  for (let k = 0; k < 4; k++) {
    const a = (k / 4) * Math.PI * 2 + 0.4;
    const ox = Math.cos(a) * 0.45, oz = Math.sin(a) * 0.45;
    put(pink, tube([[3.6 + ox, 5.0, -3.75 + oz], [3.6 + ox * 2, 4.1, -3.75 + oz * 2], [3.6 + ox * 1.6, 3.3, -3.75 + oz * 1.6]], 0.22, 6));
  }
  await fish(blue, -3.6, 5.4, -3.75, [0, 0, 90], 1.1);
  // Lines the octopus and fish hang from.
  for (const x of [-3.6, 3.6]) put(white, await bx(0.4, 0.9, 0.4, 0.1), [x, 6.55, -3.75]);
  return finish(root);
}
