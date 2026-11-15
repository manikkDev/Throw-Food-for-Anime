// Watch post, ninja village LANDMARK. Target 9 x 22 x 9 studs. Four splayed log legs on
// slate footings, X-braces, plank platform with green-railed balcony, hut with ink window
// openings, leaf-green pyramid roof, ladder up the front (-Z).
const meta = { name: 'Prop_ninja_village_WatchPost', category: 'prop' };

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
    let ok = solids;
    if (solids.length > 1) {
      // A non-manifold operand makes boolUnion throw "Not manifold". Find it, keep it loose
      // (the converter still joins by colour) and tag the root so the GLB records it.
      try {
        await boolUnion('probe', ...solids);
      } catch (e) {
        ok = [];
        for (let i = 0; i < solids.length; i++) {
          try {
            await boolUnion('probe', solids[i], solids[i].clone());
            ok.push(solids[i]);
          } catch (e2) {
            loose.push(solids[i]);
            root.name += `__loose_${mat.name}_${i}`;
          }
        }
      }
    }
    if (ok.length > 1) {
      const u = await boolUnion(mat.name, ...ok);
      u.material = mat;
      u.name = mat.name;
      outs.push(u);
    } else outs.push(...ok);
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
  const log = C('Log', 0x8a5a2b);
  const wood = C('Wood', 0xb5793f);
  const green = C('LeafGreen', 0x3fbf6a); // zone key colour
  const ink = C('Ink', 0x0d0f2b);
  const slate = C('StoneDark', 0x6b7686);

  const B = 3.75, T = 2.9, PH = 14; // leg half-spread at bottom/top, platform height
  const tilt = Math.atan((B - T) / PH) / D2R;
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    put(slate, await bx(1.7, 0.7, 1.7, 0.22), [sx * B, 0.35, sz * B]); // footing, base lip
    put(log, await cy(0.62, 0.52, PH + 0.6, 8, 0.15), [sx * (B + T) / 2, PH / 2 + 0.3, sz * (B + T) / 2], [-sz * tilt, 0, sx * tilt]);
  }
  // Braces on four sides: a ring beam and an X below it.
  for (const deg of [0, 90, 180, 270]) {
    const R = (p) => rotY(p, deg);
    const hb = (y) => B - (B - T) * (y / PH);
    put(wood, await bx(2 * hb(7.5) + 0.6, 0.55, 0.55, 0.15), R([0, 7.5, -hb(7.5)]), [0, deg, 0]);
    const dx = 2 * hb(4.2), dy = 5.4, len = Math.hypot(dx, dy);
    for (const s of [-1, 1]) put(wood, await bx(len, 0.5, 0.5, 0.15), R([0, 4.5, -hb(4.5) - 0.05 * s]), [0, deg, s * Math.atan2(dy, dx) / D2R]);
  }
  // Platform, railing posts, green rail.
  put(wood, await bx(9, 0.8, 9, 0.25), [0, PH + 0.4, 0]);
  put(log, await bx(8.2, 0.5, 8.2, 0.2), [0, PH - 0.15, 0]); // dark rim beam under the deck
  for (const deg of [0, 90, 180, 270]) {
    const R = (p) => rotY(p, deg);
    for (const x of [-4.1, 0, 4.1]) put(log, await bx(0.5, 1.7, 0.5, 0.15), R([x, PH + 1.65, -4.1]), [0, deg, 0]);
    put(green, await bx(8.8, 0.5, 0.6, 0.18), R([0, PH + 2.5, -4.1]), [0, deg, 0]);
  }
  // Hut with window openings on every side.
  put(wood, await bx(6, 4.4, 6, 0.25), [0, PH + 3.0, 0]);
  for (const deg of [0, 90, 180, 270]) put(ink, await bx(2.8, 1.7, 0.5, 0.2), rotY([0, PH + 3.4, -3.05], deg), [0, deg, 0]);
  // Roof: eave slab + square pyramid, ink cap.
  put(green, await bx(8.2, 0.55, 8.2, 0.22), [0, PH + 5.35, 0]);
  put(green, await cy(6.3, 0.5, 2.7, 4, 0.2), [0, PH + 6.9, 0], [0, 45, 0]);
  put(ink, lobe(0.5), [0, PH + 8.3, 0]);

  // Ladder up the front.
  const lb = -5.2, lt = -4.55, lean = Math.atan((lt - lb) / PH) / D2R;
  for (const x of [-0.95, 0.95]) put(wood, await bx(0.45, PH + 0.8, 0.45, 0.12), [x, PH / 2 + 0.4, (lb + lt) / 2], [-lean, 0, 0]);
  for (let y = 1.2; y < PH; y += 1.45) put(log, await bx(2.3, 0.4, 0.42, 0.1), [0, y, lb + (lt - lb) * (y / PH)]);

  return finish(root);
}
