// Round village house, ninja village SET PIECE. Target 18 x 14 x 16 studs. Cream round wall on
// a slate base, leaf-green domed roof with eave (zone key), rooftop water tank, round ink
// windows in dark wood rings, front door with green awning and a round swirl sign.
const meta = { name: 'Prop_ninja_village_NinjaHouse', category: 'prop' };

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
  const green = C('LeafGreen', 0x3fbf6a); // zone key colour
  const dark = C('WoodDark', 0x8a5a2b);
  const ink = C('Ink', 0x0d0f2b);
  const slate = C('StoneDark', 0x6b7686);

  const R = 7.3;
  put(slate, await cy(R + 0.6, R + 0.6, 1.0, 16, 0.25), [0, 0.5, 0]);
  put(cream, await cy(R, R, 8.2, 16, 0.2), [0, 5.0, 0]);
  put(green, await cy(8.6, 8.6, 0.8, 16, 0.25), [0, 9.4, 0]); // eave
  const dome = [[0, 9.6]];
  for (let i = 0; i <= 5; i++) { const a = (i / 5) * Math.PI / 2; dome.push([Math.max(0.001, 8.0 * Math.cos(a)), 9.6 + 3.8 * Math.sin(a)]); }
  dome[dome.length - 1][0] = 0;
  put(green, await revolveProfile(dome, { segments: 16, smooth: false }));
  // Water tank on the roof.
  put(dark, await cy(1.4, 1.4, 2.2, 10, 0.2), [3.6, 13.3, 2.4]);
  put(green, await cy(1.6, 1.6, 0.5, 10, 0.15), [3.6, 14.5, 2.4]);

  // Round windows.
  for (const deg of [45, -45, 135, -135, 180]) {
    const p = rotY([0, 5.6, -R + 0.05], deg);
    put(dark, (await ring(1.55, 1.0, 0.8, 12)).rotateX(Math.PI / 2), p, [0, deg, 0]);
    put(ink, (await cy(1.1, 1.1, 0.6, 12, 0.1)).rotateX(Math.PI / 2), rotY([0, 5.6, -R + 0.15], deg), [0, deg, 0]);
  }
  // Door, awning, sign.
  put(dark, await bx(2.8, 4.2, 1.4, 0.25), [0, 3.1, -R + 0.25]);
  put(ink, await bx(0.45, 0.45, 0.5, 0.1), [0.8, 3.2, -R - 0.5]); // knob
  put(green, await bx(4.0, 0.5, 1.8, 0.18), [0, 5.55, -R - 0.4], [12, 0, 0]);
  put(dark, (await cy(1.45, 1.45, 0.7, 12, 0.15)).rotateX(Math.PI / 2), [0, 7.45, -R - 0.05]);
  put(cream, (await cy(1.1, 1.1, 0.6, 12, 0.1)).rotateX(Math.PI / 2), [0, 7.45, -R - 0.25]);
  const pts = [];
  for (let i = 0; i <= 20; i++) { const t = i / 20, a = t * Math.PI * 3, r = 0.2 + 0.6 * t; pts.push([Math.cos(a) * r, 7.45 + Math.sin(a) * r, -R - 0.6]); }
  put(ink, tube(pts, 0.2, 6));
  return finish(root);
}
