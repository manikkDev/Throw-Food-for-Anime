// Chunky pirate ship, pirate harbor LANDMARK. Target 20 x 30 x 44 studs, bow at -Z.
// Tapered extruded hull with an orange stripe, light gunwale ring and deck, stern castle,
// bowsprit, two masts with orange-striped white sails, crow's nest, ink flag with a skull.
const meta = { name: 'Prop_pirate_harbor_PirateShip', category: 'prop' };

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

// Plan outline (x, z) at the keel; extrudeProfile on axis y wants [x, -z].
const PLAN = [[0, -16], [3.6, -12], [5.2, -5], [5.2, 12], [4.4, 18], [-4.4, 18], [-5.2, 12], [-5.2, -5], [-3.6, -12]];
const TX = 1.3, TZ = 1.08, HH = 6; // taper at the hull top
const at = (sx, sz) => PLAN.map(([x, z]) => [x * sx, -z * sz]);
async function slab(sx, sz, y0, h, holes) {
  const g = await extrudeProfile(at(sx, sz), { depth: h, axis: 'y', center: false, bevel: 0.25, bevelStyle: 'chamfer', holes });
  return g.translate(0, y0, 0);
}

async function build() {
  const root = createRoot(meta.name);
  const hullC = C('Hull', 0x8a5a2b);
  const wood = C('Deck', 0xb5793f);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour
  const white = C('Sail', 0xffffff);
  const ink = C('Ink', 0x0d0f2b);

  // Hull: tapered solid, narrow keel, wide deck.
  put(hullC, await extrudeProfile(at(1, 1), { depth: HH, axis: 'y', center: false, bevel: 0.3, bevelStyle: 'chamfer', taper: [TX, TZ] }));
  // Orange stripe standing proud of the hull sides (scaled to the hull at its top height + margin).
  const k = (y) => [1 + (TX - 1) * (y / HH), 1 + (TZ - 1) * (y / HH)];
  { const [sx, sz] = k(4.3); put(orange, await slab(sx * 1.035, sz * 1.02, 3.4, 0.9)); }
  // Gunwale ring and deck.
  { const [sx, sz] = k(HH); put(wood, await slab(sx * 1.03, sz * 1.02, HH - 0.1, 1.0, [at(sx * 0.86, sz * 0.92)]));
    put(wood, await slab(sx * 0.9, sz * 0.95, HH - 0.4, 0.7)); }
  // Cannon ports on both sides, above the stripe.
  for (const s of [-1, 1]) for (const z of [-4, 1.5, 7]) put(ink, await bx(1.0, 1.0, 1.3, 0.2), [s * 6.45, 5.0, z], [0, 0, -s * 14]);

  // Stern castle with orange rail and ink windows on the transom.
  put(wood, await bx(11.2, 3.4, 7.0, 0.3), [0, 7.6, 15.6]);
  put(orange, await bx(11.6, 0.7, 7.4, 0.25), [0, 9.5, 15.6]);
  for (const x of [-3, 0, 3]) put(ink, await bx(1.4, 1.4, 0.6, 0.2), [x, 7.6, 19.15]);
  // Forecastle step at the bow.
  put(wood, await bx(6.0, 1.4, 4.0, 0.3), [0, 6.7, -11.5]);
  // Bowsprit.
  put(hullC, await cy(0.55, 0.42, 7.6, 8, 0.12), [0, 8.3, -19.4], [-62, 0, 0]);

  // Masts, yards, sails, stripes.
  const masts = [
    { z: -5, top: 23, sails: [[14, 12.0, 17.2], [10.5, 18.2, 21.6]] },
    { z: 5.5, top: 29.6, sails: [[17, 12.6, 20.0], [12.5, 21.0, 25.4]] },
  ];
  for (const m of masts) {
    put(hullC, await cy(0.65, 0.5, m.top - 6, 8, 0.15), [0, (m.top + 6) / 2, m.z]);
    for (const [w, y0, y1] of m.sails) {
      const sz = m.z - 0.75;
      put(hullC, await bx(w + 2.2, 0.55, 0.55, 0.15), [0, y1 + 0.35, m.z - 0.3]); // yard
      put(white, await bx(w, y1 - y0, 0.5, 0.2), [0, (y0 + y1) / 2, sz], [-6, 0, 0]);
      const h = y1 - y0;
      for (const f of [0.3, 0.7]) put(orange, await bx(w + 0.12, Math.min(1.2, h * 0.22), 0.75, 0.2), [0, y0 + h * f, sz - (0.5 - f) * h * 0.105], [-6, 0, 0]);
    }
  }
  // Crow's nest on the main mast.
  put(wood, await cy(1.4, 1.6, 1.2, 10, 0.2), [0, 26.6, 5.5]);
  put(orange, await cy(1.7, 1.7, 0.45, 10, 0.12), [0, 27.3, 5.5]);
  // Flag at the main masthead, skull standing proud of both faces.
  put(ink, await bx(3.6, 2.3, 0.45, 0.15), [1.95, 28.4, 5.5]);
  put(white, lobe(0.62), [2.1, 28.55, 5.5], [0, 0, 0], [1, 1, 0.55]);
  put(white, await bx(1.6, 0.42, 0.55, 0.1), [2.1, 27.75, 5.5], [0, 0, 28]);
  put(orange, lobe(0.5), [0, 29.7, 5.5]);

  return finish(root);
}
