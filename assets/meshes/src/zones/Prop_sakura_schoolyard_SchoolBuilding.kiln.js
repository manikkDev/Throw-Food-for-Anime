// Anime high school, sakura schoolyard SET PIECE. Target 44 x 24 x 18 studs (budget 6000 tris).
// Three storeys of cream wall with rows of blue windows and pink floor bands, a raised central
// gable with a big clock and pink pediment, entrance canopy and steps, roof fence.
const meta = { name: 'Prop_sakura_schoolyard_SchoolBuilding', category: 'prop' };

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

function rotY(p, deg) {
  const a = deg * D2R, c = Math.cos(a), s = Math.sin(a);
  return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
}

async function build() {
  const root = createRoot(meta.name);
  const cream = C('Wall', 0xfff1dc);
  const blue = C('Window', 0x38bdf8);
  const pink = C('Sakura', 0xff8fc0); // zone key colour
  const slate = C('StoneDark', 0x6b7686);
  const yellow = C('Yellow', 0xffd23f);

  const W = 40, D = 14, H = 20;
  put(slate, await bx(W + 2, 1.2, D + 2, 0.3), [0, 0.6, 0]); // base lip
  put(cream, await bx(W, H - 1.2, D, 0.3), [0, 1.2 + (H - 1.2) / 2, 0]);
  for (const y of [7.3, 13.4]) put(pink, await bx(W + 0.6, 0.6, D + 0.6, 0.2), [0, y, 0]);
  put(pink, await bx(W + 1.0, 0.9, D + 1.0, 0.25), [0, H + 0.2, 0]); // cornice

  // Central gable block and pediment.
  put(cream, await bx(11, 22.2 - 1.2, D + 1.2, 0.3), [0, 1.2 + (22.2 - 1.2) / 2, 0]);
  put(pink, await bx(11.8, 0.8, D + 1.8, 0.25), [0, 22.4, 0]);
  put(pink, await extrudeProfile([[-5.9, 22.7], [5.9, 22.7], [0, 24.6]], { depth: D + 1.4, axis: 'z', center: true, bevel: 0.2, bevelStyle: 'chamfer' }));
  // Clock on the gable front.
  const fz = -(D + 1.2) / 2;
  put(yellow, (await ring(2.8, 2.15, 0.8, 12)).rotateX(Math.PI / 2), [0, 18.2, fz - 0.2]);
  put(cream, (await cy(2.25, 2.25, 0.5, 12, 0.1)).rotateX(Math.PI / 2), [0, 18.2, fz - 0.05]);
  put(slate, await bx(0.5, 1.8, 0.45, 0.12), [0, 19.0, fz - 0.4]);
  put(slate, await bx(0.5, 1.4, 0.45, 0.12), [0.55, 17.85, fz - 0.4], [0, 0, 55]);
  put(yellow, (await cy(0.4, 0.4, 0.6, 8, 0.1)).rotateX(Math.PI / 2), [0, 18.2, fz - 0.55]);

  // Windows: front and back rows on three floors, side windows.
  const rows = [4.4, 10.4, 16.5];
  for (const sgn of [-1, 1]) for (const y of rows) for (const x of [-16, -12, -8, 8, 12, 16]) {
    put(blue, await bx(3.0, 2.7, 0.5, 0.18), [x, y, sgn * (D / 2 + 0.05)]);
  }
  for (const sgn of [-1, 1]) put(blue, await bx(5.0, 2.7, 0.5, 0.18), [0, 10.4, sgn * ((D + 1.2) / 2 + 0.05)]);
  for (const deg of [90, 270]) for (const y of rows) for (const z of [-3.2, 3.2]) put(blue, await bx(3.0, 2.7, 0.5, 0.18), rotY([z, y, -(W / 2 + 0.05)], deg), [0, deg, 0]);

  // Entrance: slate doors, pink canopy, slate steps.
  put(slate, await bx(5.4, 4.2, 0.6, 0.2), [0, 3.3, fz - 0.1]);
  put(pink, await bx(9.0, 0.6, 3.2, 0.2), [0, 6.0, fz - 1.4]);
  for (const sx of [-1, 1]) put(pink, await bx(0.5, 4.8, 0.5, 0.15), [sx * 4.1, 3.6, fz - 2.6]);
  put(slate, await bx(8.0, 0.6, 2.4, 0.2), [0, 0.6, fz - 1.4]);

  // Roof fence round the wings (slate posts, pink top rail).
  for (const sx of [-1, 1]) {
    const x0 = sx * 5.9, x1 = sx * 20.0, xm = (x0 + x1) / 2, len = Math.abs(x1 - x0);
    for (const z of [-6.6, 6.6]) put(pink, await bx(len, 0.45, 0.5, 0.12), [xm, 22.4, z]);
    put(pink, await bx(0.5, 0.45, 13.0, 0.12), [x1 - sx * 0.25, 22.4, 0]);
    for (let x = 8; x <= 20; x += 3) for (const z of [-6.6, 6.6]) put(slate, await bx(0.45, 1.8, 0.45, 0.1), [sx * Math.min(x, 19.75), 21.5, z]);
  }
  return finish(root);
}
