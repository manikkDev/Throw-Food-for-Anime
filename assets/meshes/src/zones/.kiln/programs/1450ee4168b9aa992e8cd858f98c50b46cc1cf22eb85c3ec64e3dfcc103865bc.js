// Treasure pile, pirate harbor SET PIECE. Target 9 x 6 x 9 studs. Heap of gold coins (faceted
// mound + scattered coins), open dark-wood chest with orange straps (zone key) brimming with
// gold, lid thrown back, gold crown with a pink gem, pink and blue gems in the heap.
const meta = { name: 'Prop_pirate_harbor_TreasurePile', category: 'prop' };

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
  const gold = C('Gold', 0xffd23f);
  const wood = C('WoodDark', 0x8a5a2b);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour
  const pink = C('GemPink', 0xff8fc0);
  const blue = C('GemBlue', 0x38bdf8);

  // Gold heap.
  put(gold, lobe(4.4), [0, 0.2, 0], [0, 15, 0], [1, 0.42, 1]);
  for (const [x, z, r] of [[-2.6, -1.9, 1.6], [2.4, -2.2, 1.5], [2.7, 2.0, 1.6], [-2.4, 2.4, 1.5]]) put(gold, lobe(r), [x, 0.4, z], [0, x * 20, 0], [1, 0.5, 1]);
  // Scattered coins on the slopes and the ground.
  const coins = [[-3.4, 0.55, -3.1, 20], [-1.2, 1.55, -2.9, -25], [1.6, 1.3, -3.3, 30], [3.7, 0.4, -1.0, 10], [-3.9, 0.35, 0.9, -15], [0.4, 1.9, -2.2, 40], [3.1, 1.0, 2.9, -30], [-1.0, 0.35, 4.1, 5]];
  for (const [x, y, z, t] of coins) put(gold, await cy(0.55, 0.55, 0.4, 8, 0.08), [x, y, z], [t, x * 30, t * 0.5]);

  // Chest on top of the heap, opening to the front (-Z).
  const CY = 1.2;
  put(wood, await bx(4.2, 2.0, 2.8, 0.25), [0, CY + 1.0, 0.3]);
  for (const x of [-1.4, 1.4]) put(orange, await bx(0.55, 2.1, 2.9, 0.12), [x, CY + 1.0, 0.3]);
  put(orange, await bx(4.3, 0.5, 2.9, 0.12), [0, CY + 0.3, 0.3]);
  put(gold, await bx(0.7, 0.8, 0.5, 0.12), [0, CY + 1.5, -1.15]); // lock
  put(gold, lobe(1.9), [0, CY + 2.05, 0.3], [0, 30, 0], [1.0, 0.45, 0.68]); // gold brimming out
  // Lid: half-cylinder thrown back on its hinge.
  const prof = [];
  for (let i = 0; i <= 8; i++) { const a = (i / 8) * Math.PI; prof.push([-Math.cos(a) * 1.4, Math.sin(a) * 1.1]); }
  const lid = (await extrudeProfile(prof, { depth: 4.2, axis: 'x', center: true, bevel: 0.12, bevelStyle: 'chamfer' })).translate(0, 0, -1.4);
  put(wood, lid, [0, CY + 2.0, 1.7], [128, 0, 0]);
  for (const x of [-1.4, 1.4]) put(orange, (await extrudeProfile(prof, { depth: 0.55, axis: 'x', center: true })).translate(0, 0, -1.4).scale(1, 1.06, 1.03), [x, CY + 2.0, 1.7], [128, 0, 0]);
  // Crown leaning on the heap, front right.
  const crown = await revolveProfile([[0.75, 0], [1.05, 0], [1.05, 0.7], [0.75, 0.7]], { segments: 10, smooth: false });
  put(gold, crown, [2.6, 1.15, -2.2], [-18, 0, 12]);
  for (let i = 0; i < 5; i++) { const a = (i / 5) * Math.PI * 2; put(gold, lobe(0.28, 1), [2.6 + Math.cos(a) * 0.9, 2.05, -2.2 + Math.sin(a) * 0.9 - 0.25]); }
  put(pink, lobe(0.35, 0), [2.4, 1.55, -3.2]);
  // Gems in the heap.
  for (const [m, x, y, z, r] of [[pink, -2.0, 1.4, -2.3, 0.55], [blue, 1.0, 1.7, -2.4, 0.5], [blue, -3.0, 0.9, 1.6, 0.5], [pink, 3.2, 1.0, 1.0, 0.45], [blue, 0.2, 3.2, -0.4, 0.45]]) put(m, lobe(r, 0), [x, y, z], [x * 30, 0, z * 20]);
  return finish(root);
}
