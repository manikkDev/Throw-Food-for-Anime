// Skull rock island, pirate harbor SET PIECE. Target 26 x 20 x 22 studs (budget 6000 tris).
// Friendly faceted stone skull on a sand island, big ink eye sockets, nose, a cave mouth with
// white teeth, boulders round the shore, pirate flag with an orange band on top.
const meta = { name: 'Prop_pirate_harbor_SkullRock', category: 'prop' };

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
  const stone = C('Stone', 0x9aa4b2);
  const sand = C('Sand', 0xf4d58a);
  const ink = C('Ink', 0x0d0f2b);
  const white = C('White', 0xffffff);
  const orange = C('HarborOrange', 0xff9a3d); // zone key colour

  put(sand, await cy(13, 12, 1.2, 14, 0.35), [0, 0.6, 0], [0, 0, 0], [1, 1, 0.84]); // island

  // Skull: cranium, jaw, cheekbones, merged into one stone mass.
  put(stone, lobe(8.2), [0, 9.0, 1.0], [0, 10, 0], [1, 0.92, 0.95]);
  put(stone, lobe(6.2), [0, 4.4, -1.6], [0, 0, 0], [1.12, 0.7, 1]);
  for (const sx of [-1, 1]) put(stone, lobe(3.6), [sx * 4.6, 6.2, -3.4], [0, 20, 0]);
  // Shore boulders.
  for (const [x, z, r] of [[-9, 4, 2.2], [9.5, 2, 2.6], [-7, -6.5, 1.6], [8, -6, 1.8], [2, 8.2, 2.0], [-4, 7.5, 1.5]]) {
    put(stone, lobe(r, 0), [x, 1.0 + r * 0.4, z], [x * 7, z * 11, 0], [1, 0.75, 1]);
  }
  // Face.
  for (const sx of [-1, 1]) put(ink, lobe(2.5), [sx * 3.4, 10.0, -5.8], [0, 0, sx * 12], [1, 1.15, 0.7]);
  put(ink, lobe(1.1, 0), [0, 7.3, -7.0], [0, 0, 0], [1, 1.2, 0.8]);
  put(ink, lobe(3.2), [0, 3.6, -6.4], [0, 0, 0], [1.45, 0.75, 0.62]); // cave mouth
  for (const x of [-2.3, -0.78, 0.78, 2.3]) put(white, await bx(1.2, 1.3, 0.9, 0.2), [x, 5.15, -7.95]);
  for (const x of [-1.5, 1.5]) put(white, await bx(1.1, 1.1, 0.9, 0.2), [x, 1.95, -7.7]);

  // Pirate flag on the crown.
  put(ink, await cy(0.34, 0.3, 5.5, 8, 0.1), [2.2, 16.6, 1.5]);
  put(orange, lobe(0.5), [2.2, 19.45, 1.5]);
  put(ink, await bx(3.8, 2.4, 0.45, 0.15), [4.2, 18.0, 1.5]);
  put(orange, await bx(3.9, 0.5, 0.55, 0.12), [4.2, 17.05, 1.5]);
  put(white, lobe(0.6), [4.3, 18.35, 1.5], [0, 0, 0], [1, 1, 0.55]);
  return finish(root);
}
