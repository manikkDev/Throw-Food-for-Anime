// Street ramen stall (yatai), shared SET PIECE. Target 10 x 9 x 7 studs. Dark wood cart with
// wheels, light counter, posts and roof, red noren curtain with white marks, giant red ramen bowl
// sign on the roof with yellow noodles, egg and chopsticks, white steam puffs, three stools.
// Shared trim: warm yellow + white.
const meta = { name: 'Prop_shared_RamenStand', category: 'prop' };

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

async function build() {
  const root = createRoot(meta.name);
  const dark = C('WoodDark', 0x8a5a2b);
  const wood = C('Wood', 0xb5793f);
  const red = C('Red', 0xf04848);
  const white = C('White', 0xffffff);
  const yellow = C('Yellow', 0xffd23f);

  // Cart body, counter, wheels.
  put(dark, await bx(8.8, 2.9, 4.0, 0.25), [0, 1.65, 0.5]);
  put(dark, await bx(9.2, 0.6, 4.4, 0.2), [0, 0.3, 0.5]); // base lip
  put(wood, await bx(9.6, 0.5, 2.8, 0.18), [0, 3.35, -1.1]);
  put(yellow, await bx(8.4, 0.5, 0.5, 0.12), [0, 2.2, -1.6]); // trim band on the cart front
  for (const sx of [-1, 1]) {
    put(dark, (await ring(1.25, 0.6, 0.6, 10)).rotateZ(Math.PI / 2), [sx * 4.75, 1.25, 1.2]);
    put(yellow, (await cy(0.45, 0.45, 0.8, 8, 0.1)).rotateZ(Math.PI / 2), [sx * 4.75, 1.25, 1.2]);
  }
  // Posts and roof.
  for (const sx of [-1, 1]) for (const z of [-0.9, 2.1]) put(dark, await bx(0.5, 2.9, 0.5, 0.12), [sx * 4.2, 4.55, z]);
  put(wood, await bx(10.0, 0.6, 4.8, 0.2), [0, 6.25, 0.55]);
  put(red, await bx(10.0, 0.55, 0.6, 0.15), [0, 6.2, -1.95]); // front eave
  // Noren: four red panels hanging from the eave, white marks on the middle two.
  for (let i = 0; i < 4; i++) {
    const x = -3.45 + i * 2.3;
    put(red, await bx(2.1, 1.7, 0.45, 0.12), [x, 5.15, -1.95]);
    if (i === 1 || i === 2) put(white, await bx(0.9, 0.9, 0.55, 0.12), [x, 5.05, -1.95]);
  }
  // Giant ramen bowl on the roof, tipped toward the front.
  const tilt = [-14, 0, 0];
  const bowl = await revolveProfile([[0, 0], [1.2, 0], [2.3, 1.45], [0, 1.45]], { segments: 12, smooth: false });
  put(red, bowl, [0, 6.55, 0.6], tilt);
  put(white, await ring(2.45, 1.95, 0.45, 12), [0, 7.92, 0.27], tilt);
  put(yellow, await cy(2.0, 2.0, 0.45, 12, 0.1), [0, 7.85, 0.3], tilt);
  put(white, lobe(0.6), [0.9, 8.15, 0.0], [0, 0, 0], [1, 0.6, 1]); // egg
  put(yellow, lobe(0.3, 1), [0.9, 8.3, -0.12]);
  for (const x of [-0.6, -0.1]) put(dark, await bx(0.4, 2.2, 0.4, 0.1), [x, 8.35, 0.9], [20, 0, -25]);
  // Steam puffs (white lobes) rising behind the chopsticks.
  // (Kept low so the stall holds the 9-stud height.)
  for (const [x, y, z, r] of [[-1.4, 8.45, 0.3, 0.55], [1.6, 8.55, 0.9, 0.5]]) put(white, lobe(r), [x, y, z]);
  // Stools.
  for (const x of [-2.8, 0, 2.8]) {
    put(dark, await cy(0.3, 0.3, 1.8, 6, 0.08), [x, 0.9, -3.0]);
    put(red, await cy(0.75, 0.75, 0.45, 10, 0.12), [x, 2.0, -3.0]);
  }
  return finish(root);
}
