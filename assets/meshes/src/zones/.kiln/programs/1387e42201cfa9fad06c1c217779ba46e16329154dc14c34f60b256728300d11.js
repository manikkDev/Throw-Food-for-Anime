// Tree house, ninja village SET PIECE. Target 14 x 22 x 14 studs. Fat flared trunk, plank deck
// with a green rail, hut round the trunk with a green roof (zone key), chunky leaf canopy,
// sand rope ladder hanging to the ground at the front (-Z).
const meta = { name: 'Prop_ninja_village_TreeHouse', category: 'prop' };

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
  const bark = C('Bark', 0x8a5a2b);
  const wood = C('Wood', 0xb5793f);
  const green = C('LeafGreen', 0x3fbf6a); // zone key colour
  const leaf = C('Canopy', 0x5bd43a);
  const rope = C('Rope', 0xf4d58a);

  // Trunk with root flare and buttress roots.
  put(bark, await cy(3.4, 2.4, 2.0, 10, 0.3), [0, 1.0, 0]);
  put(bark, await cy(2.4, 1.9, 15.0, 10, 0.2), [0, 9.0, 0]);
  for (const deg of [20, 140, 260]) put(bark, await bx(1.0, 2.2, 3.6, 0.25), rotY([0, 1.0, 2.6], deg), [-25, deg, 0]);
  for (const [deg, tilt] of [[30, 35], [160, 38], [280, 32]]) put(bark, await cy(1.0, 0.7, 5.0, 8, 0.15), rotY([0, 16.5, 1.4], deg), [tilt, deg, 0]);

  // Deck + rail + posts.
  const DY = 9.0;
  put(wood, await bx(10.4, 0.7, 10.4, 0.25), [0, DY, 0]);
  for (const deg of [0, 90, 180, 270]) {
    const len = deg % 180 ? 9.4 : 10.2; // unequal so rail ends never coincide
    put(green, await bx(len, 0.5, 0.55, 0.15), rotY([0, DY + 1.9, -4.9], deg), [0, deg, 0]);
    for (const x of [-4.9, 4.9]) put(bark, await bx(0.5, 1.9, 0.5, 0.12), rotY([x, DY + 1.0, -4.9], deg), [0, deg, 0]);
  }
  // Brackets under the deck.
  for (const deg of [45, 135, 225, 315]) put(bark, await bx(0.6, 0.6, 4.4, 0.15), rotY([0, DY - 1.6, 3.2], deg), [-35, deg, 0]);
  // Hut on the back half of the deck, wrapped round the trunk.
  put(wood, await bx(7.0, 3.8, 5.0, 0.25), [0, DY + 2.25, 1.6]);
  put(bark, await bx(1.8, 2.6, 0.5, 0.18), [-1.6, DY + 1.65, -0.95]); // doorway
  put(bark, await bx(1.6, 1.3, 0.5, 0.15), [1.9, DY + 2.6, -0.95]); // window
  put(green, await extrudeProfile([[-4.6, 0], [4.6, 0], [4.6, 0.5], [0, 2.6], [-4.6, 0.5]], { depth: 6.6, axis: 'z', center: true, bevel: 0.2, bevelStyle: 'chamfer' }), [0, DY + 4.1, 1.6]);

  // Canopy.
  for (const [x, y, z, r] of [[0, 19.0, 0, 4.0], [3.4, 17.3, 1.2, 3.1], [-3.3, 17.5, 0.8, 3.2], [0.6, 17.0, -3.2, 3.0], [-0.8, 17.4, 3.4, 3.0]]) {
    put(leaf, lobe(r), [x, y, z], [0, x * 20, 0], [1, 0.8, 1]);
  }
  // Rope ladder at the front edge of the deck.
  const LZ = -5.0;
  for (const x of [-1.0, 1.0]) put(rope, tube([[x, DY - 0.2, LZ], [x, 0.4, LZ]], 0.22, 6));
  for (let y = 1.2; y < DY - 0.6; y += 1.3) put(wood, await bx(2.6, 0.4, 0.45, 0.1), [0, y, LZ]);
  return finish(root);
}
