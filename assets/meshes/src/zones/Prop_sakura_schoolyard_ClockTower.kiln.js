// School clock tower, sakura schoolyard LANDMARK. Target 12 x 34 x 12 studs. Slate plinth,
// cream shaft with stone corner pilasters, pink bands, a big clock on every side, belfry,
// pink pyramid roof with a yellow finial.
const meta = { name: 'Prop_sakura_schoolyard_ClockTower', category: 'prop' };

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

// Rotate a point about Y by deg (used to repeat a front-face detail on all four sides).
function rotY(p, deg) {
  const a = deg * D2R, c = Math.cos(a), s = Math.sin(a);
  return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
}

async function build() {
  const root = createRoot(meta.name);
  const slate = C('StoneDark', 0x6b7686);
  const cream = C('Wall', 0xfff1dc);
  const stone = C('Stone', 0x9aa4b2);
  const pink = C('Sakura', 0xff8fc0); // zone key colour
  const yellow = C('Yellow', 0xffd23f);

  put(slate, await bx(12, 1.4, 12, 0.3), [0, 0.7, 0]); // darker base lip
  put(cream, await bx(10, 16.4, 10, 0.25), [0, 9.4, 0]); // shaft
  put(pink, await bx(11, 1.0, 11, 0.25), [0, 17.6, 0]); // band
  put(cream, await bx(10.6, 7.2, 10.6, 0.25), [0, 21.6, 0]); // clock stage
  put(pink, await bx(11.6, 1.1, 11.6, 0.3), [0, 25.6, 0]); // cornice
  put(cream, await bx(8.6, 3.6, 8.6, 0.25), [0, 27.9, 0]); // belfry
  put(pink, await bx(10.4, 0.7, 10.4, 0.2), [0, 29.6, 0]); // eave lip
  put(pink, await cy(8.45, 0.6, 6.6, 4, 0.2), [0, 33.1, 0], [0, 45, 0]); // square pyramid roof
  put(yellow, lobe(0.75), [0, 37.2, 0], [0, 0, 0], [1, 1.1, 1]); // finial
  put(yellow, await cy(0.6, 0.6, 0.6, 8, 0.15), [0, 36.5, 0]);

  // Corner pilasters, lower shaft and clock stage.
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    put(stone, await bx(1.5, 16.0, 1.5, 0.25), [sx * 4.75, 9.4, sz * 4.75]);
    put(stone, await bx(1.5, 7.0, 1.5, 0.25), [sx * 5.05, 21.6, sz * 5.05]);
  }

  for (const deg of [0, 90, 180, 270]) {
    const R = (p) => rotY(p, deg);
    const rr = [0, deg, 0];
    // Clock: yellow rim ring, cream face, slate hands and ticks.
    const fz = -5.3;
    put(yellow, (await ring(3.4, 2.7, 0.8, 12)).rotateX(Math.PI / 2), R([0, 21.6, fz - 0.2]), rr);
    put(cream, (await cy(2.8, 2.8, 0.5, 12, 0.1)).rotateX(Math.PI / 2), R([0, 21.6, fz - 0.05]), rr);
    put(slate, await bx(0.55, 2.1, 0.45, 0.12), R([0, 22.5, fz - 0.4]), rr); // hour... minute hand up
    put(slate, await bx(0.55, 1.6, 0.45, 0.12), R([0.65, 21.2, fz - 0.4]), [0, deg, 55]);
    put(yellow, (await cy(0.45, 0.45, 0.6, 8, 0.1)).rotateX(Math.PI / 2), R([0, 21.6, fz - 0.55]), rr);
    for (const [tx, ty] of [[0, 2.15], [2.15, 0], [0, -2.15], [-2.15, 0]]) {
      put(slate, await bx(0.45, 0.45, 0.4, 0.12), R([tx, 21.6 + ty, fz - 0.3]), rr);
    }
    // Belfry opening and two shaft windows per side.
    put(slate, await bx(3.2, 2.4, 0.5, 0.2), R([0, 27.8, -4.2]), rr);
    for (const wx of [-2.2, 2.2]) {
      put(slate, await bx(1.6, 2.6, 0.5, 0.18), R([wx, 12.5, -4.9]), rr);
      put(pink, await bx(2.1, 0.45, 0.7, 0.15), R([wx, 11.05, -4.95]), rr); // sill
    }
  }
  // Front door with pink frame.
  put(pink, await bx(3.8, 5.0, 0.6, 0.2), [0, 3.9, -4.85]);
  put(slate, await bx(3.0, 4.4, 0.6, 0.2), [0, 3.6, -5.0]);

  return finish(root);
}
