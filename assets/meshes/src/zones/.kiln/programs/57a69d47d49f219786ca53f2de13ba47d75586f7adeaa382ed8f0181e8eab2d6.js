// Seated fox guardian statue, ninja village SET PIECE. Target 7 x 10 x 8 studs. White fox on a
// slate plinth with a green top band (zone key), red bib, ink eyes and nose, five tails fanned
// behind with green tips.
const meta = { name: 'Prop_ninja_village_FoxStatue', category: 'prop' };

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
  const white = C('White', 0xffffff);
  const red = C('Red', 0xf04848);
  const slate = C('StoneDark', 0x6b7686);
  const green = C('LeafGreen', 0x3fbf6a); // zone key colour
  const ink = C('Ink', 0x0d0f2b);

  put(slate, await bx(6.4, 1.4, 6.0, 0.3), [0, 0.7, -0.6]);
  put(green, await bx(6.0, 0.5, 5.6, 0.18), [0, 1.6, -0.6]);

  // Body.
  put(white, lobe(2.1, 2), [0, 3.7, 0.3], [0, 0, 0], [1, 0.9, 1.1]); // haunches
  put(white, lobe(1.6, 2), [0, 5.6, -0.6], [0, 0, 0], [0.9, 1.3, 0.85]); // chest
  put(white, lobe(1.45, 2), [0, 7.9, -0.8]); // head
  put(white, (await cy(0.95, 0.32, 1.9, 8, 0.1)).rotateX(-Math.PI / 2), [0, 7.5, -2.6]); // snout
  put(ink, lobe(0.32, 1), [0, 7.5, -3.55]);
  for (const sx of [-1, 1]) {
    put(white, await cy(0.75, 0.25, 1.7, 6, 0.1), [sx * 0.85, 9.5, -0.7], [0, 0, -sx * 12]);
    put(ink, await bx(0.75, 0.4, 0.4, 0.1), [sx * 0.62, 8.25, -2.05], [0, sx * 20, sx * 20]);
    put(white, tube([[sx * 0.8, 5.4, -1.3], [sx * 0.85, 3.4, -1.9], [sx * 0.85, 2.2, -1.95]], 0.45, 8)); // front leg
    put(white, lobe(0.55, 1), [sx * 0.85, 2.25, -2.15], [0, 0, 0], [1, 0.7, 1.2]); // paw
  }
  // Red bib.
  put(red, await extrudeProfile([[-1.35, 0], [1.35, 0], [0, -1.7]], { depth: 0.5, axis: 'z', center: true, bevel: 0.15, bevelStyle: 'chamfer' }), [0, 6.95, -1.75], [12, 0, 0]);
  // Five tails fanned behind.
  for (const deg of [-62, -31, 0, 31, 62]) {
    const a = deg * D2R;
    const dir = [Math.sin(a), Math.cos(a), 0.25];
    const base = [0, 3.0, 2.0], mid = 2.1, tip = 4.1;
    put(white, lobe(0.95, 1), [base[0] + dir[0] * mid, base[1] + dir[1] * mid, base[2] + dir[2] * mid], [0, 0, -deg], [0.75, 2.3, 0.75]);
    put(green, lobe(0.62, 1), [dir[0] * tip, base[1] + dir[1] * tip, base[2] + dir[2] * tip]);
  }
  return finish(root);
}
