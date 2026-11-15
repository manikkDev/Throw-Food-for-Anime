// Hidden village gate, ninja village. Target 22 x 16 x 5 studs. Dark wood pillars on slate
// footings, light tie beam, dark lintel, thick leaf-green gable roof (zone key), green-framed
// plaque with an ink swirl emblem on the front (-Z).
const meta = { name: 'Prop_ninja_village_HiddenGate', category: 'prop' };

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
  const green = C('LeafGreen', 0x3fbf6a); // zone key colour
  const ink = C('Ink', 0x0d0f2b);
  const slate = C('StoneDark', 0x6b7686);

  for (const sx of [-1, 1]) {
    put(slate, await bx(3.2, 1.0, 3.2, 0.25), [sx * 8.4, 0.5, 0]);
    put(dark, await bx(2.2, 12.0, 2.2, 0.25), [sx * 8.4, 6.6, 0]);
    put(green, await bx(2.6, 0.7, 2.6, 0.2), [sx * 8.4, 3.0, 0]); // cloth band
  }
  put(wood, await bx(15.0, 1.3, 1.7, 0.25), [0, 9.4, 0]); // tie beam
  put(dark, await bx(21.0, 1.4, 2.8, 0.3), [0, 12.3, 0]); // lintel
  // Gable roof along X, cross-section in (u=-z, v=y).
  const roof = await extrudeProfile([[-2.5, 12.9], [2.5, 12.9], [2.5, 13.6], [0, 15.6], [-2.5, 13.6]], { depth: 21.6, axis: 'x', center: true, bevel: 0.25, bevelStyle: 'chamfer' });
  put(green, roof);
  put(dark, await bx(22.0, 0.7, 0.9, 0.2), [0, 15.55, 0]); // ridge cap

  // Plaque hanging on the tie beam, swirl emblem.
  put(green, await bx(4.6, 4.6, 0.7, 0.25), [0, 9.0, -1.05]);
  put(wood, await bx(3.8, 3.8, 0.8, 0.22), [0, 9.0, -1.2]);
  const pts = [];
  for (let i = 0; i <= 26; i++) {
    const t = i / 26, a = t * Math.PI * 3.4, r = 0.25 + 1.25 * t;
    pts.push([Math.cos(a) * r, 9.0 + Math.sin(a) * r, -1.62]);
  }
  pts.push([1.75, 7.75, -1.62]); // tail
  put(ink, tube(pts, 0.22, 6));
  put(ink, lobe(0.32, 0), [pts[0][0], pts[0][1], -1.62]);
  return finish(root);
}
