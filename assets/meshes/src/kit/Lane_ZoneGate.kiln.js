// Lane_ZoneGate (v2, replaces the 40-wide gate): a GRAND anime shrine gate
// spanning the lane corridor. Two massive tapered vermilion pillars leaning in
// slightly on stepped ink plinths, a red lower beam (nuki) with gold wedges,
// two stacked curved upper beams (red shimaki under the ink kasagi) sweeping up
// to gold tips, a thick three-strand straw shimenawa rope with white paper
// shide and straw tufts, a banner board (Face_FFF6E0: ONE mesh, front quad
// facing -Z, 22 x 4.5) in an accent frame, a hanging lantern each side, a
// guardian fox on each plinth.
// Accent_FF00FF (ONE mesh): pillar bands, banner frame, lantern bodies, fox bibs.
// Opening: no geometry with |x| < 22 below y = 20 (checked numerically).
// Art bible: design/kit.json -> kit.Lane_ZoneGate, size [60, 32, 8], budget 6000.
//
// ---- shared kit prelude v2 (v1 in the first 13 kit files; v2 adds clean()) --
// Authored in the ROBLOX frame and in STUDS: +X right, +Y up, front faces -Z,
// standing on y = 0, centred on x and z. The `RF` group converts that to Kiln's
// frame (+X forward, metres); kiln_to_roblox.mjs converts it back. Never
// pre-rotate a part to compensate: the two conversions cancel exactly.
const STUD = 0.28;
const hexs = (h) => h.toString(16).toUpperCase().padStart(6, '0');
function mat(label, hex, opts = {}) {
  const m = gameMaterial(hex, { roughness: 0.8, metalness: 0, flatShading: false, ...opts });
  m.name = `${label}_${hexs(hex)}`;
  return m;
}
function rframe(root) {
  const g = new THREE.Group();
  g.name = 'RF';
  g.rotation.y = -Math.PI / 2;
  g.scale.setScalar(STUD);
  root.add(g);
  return g;
}
// Rounded rectangle outline in the XZ plane, fixed point count for any radius.
function rrect(w, d, r, seg) {
  r = Math.max(1e-3, Math.min(r, w / 2, d / 2));
  if (w / 2 - r < 1e-4) r = w / 2;
  if (d / 2 - r < 1e-4) r = Math.min(r, d / 2);
  const pts = [];
  const cs = [
    [w / 2 - r, d / 2 - r, 0],
    [-(w / 2 - r), d / 2 - r, 90],
    [-(w / 2 - r), -(d / 2 - r), 180],
    [w / 2 - r, -(d / 2 - r), 270],
  ];
  // Straight run after each corner; when it is zero (a circle or a stadium) the
  // corner's closing point would duplicate the next corner's first point, and
  // loftProfiles rejects duplicate points ("execution was rejected", no detail).
  const runs = [w / 2 - r, d / 2 - r, w / 2 - r, d / 2 - r];
  for (let k = 0; k < 4; k++) {
    const [cx, cz, a0] = cs[k];
    const last = runs[k] < 1e-4 ? seg - 1 : seg;
    for (let i = 0; i <= last; i++) {
      const a = ((a0 + (90 * i) / seg) * Math.PI) / 180;
      pts.push([cx + r * Math.cos(a), cz + r * Math.sin(a)]);
    }
  }
  return pts;
}
// The kit's workhorse: a chunky slab, bottom at y = 0, plan corner radius r,
// every top and bottom edge rounded by b. One closed lofted solid.
function slab(w, h, d, o = {}) {
  const r = o.r ?? 0.3;
  const b = Math.min(o.b ?? 0.2, h / 2 - 1e-3, w / 2 - 1e-3, d / 2 - 1e-3);
  const seg = o.seg ?? 3;
  const bseg = o.bseg ?? 2;
  const top = o.top ?? 1; // plan scale of the top ring (taper)
  const sections = [];
  const ring = (inset, y, s) =>
    sections.push({
      profile: rrect(w * s - 2 * inset, d * s - 2 * inset, Math.max(r * s - inset, 1e-3), seg),
      frame: { origin: [0, y, 0] },
    });
  const lerp = (y) => 1 + (top - 1) * (y / h);
  if (b <= 1e-3) {
    ring(0, 0, 1);
    ring(0, h, top);
  } else {
    for (let i = 0; i <= bseg; i++) {
      const t = ((i / bseg) * Math.PI) / 2;
      const y = b * (1 - Math.cos(t));
      ring(b * (1 - Math.sin(t)), y, lerp(y));
    }
    for (let i = bseg; i >= 0; i--) {
      const t = ((i / bseg) * Math.PI) / 2;
      const y = h - b * (1 - Math.cos(t));
      ring(b * (1 - Math.sin(t)), y, lerp(y));
    }
  }
  return creaseNormals(loftProfiles(sections, { cap: true }), { angle: 50 });
}
// Disc / cylinder along Y, bottom at y = 0.
const disc = (radius, h, o = {}) => slab(2 * radius, h, 2 * radius, { ...o, r: radius, seg: o.seg ?? 6 });
// Every part goes in as position + normal, non-indexed, no groups. Without
// this, extruded/swept parts and lofted parts carry different attribute sets,
// the converter's join() refuses to merge them, and Roblox imports a second
// mesh of the same colour renamed <Label>_<hex>2.
function clean(g) {
  const x = g.index ? g.toNonIndexed() : g.clone();
  for (const k of Object.keys(x.attributes)) if (k !== 'position' && k !== 'normal') x.deleteAttribute(k);
  x.clearGroups();
  for (const k of Object.keys(x.morphAttributes || {})) delete x.morphAttributes[k];
  return x;
}
const P = (name, geo, m, parent, position = [0, 0, 0], rotation = [0, 0, 0]) =>
  createPart(name, clean(geo), m, { position, rotation, parent });
// Upright panel facing -Z with rounded corners in the FRONT view: w wide,
// h tall centred on yc, t thick, front face at zFront (back at zFront + t).
const V = (name, w, h, t, m, parent, x, yc, zFront, o = {}) =>
  P(name, slab(w, t, h, o), m, parent, [x, yc, zFront + t], [-90, 0, 0]);
// ---- end prelude ----------------------------------------------------------

const meta = { name: 'Lane_ZoneGate', category: 'prop' };

const LEAN = 2.33; // degrees each pillar leans in (uchikorobi)
const PX0 = 25.6; // pillar axis x at its foot
const PY0 = 2.4; // pillar foot height (on the plinth)
const PH = 27.6; // pillar length
const R0 = 2.6; // pillar radius at the foot
const R1 = 2.2; // at the top
const pillarX = (y) => PX0 - (y - PY0) * Math.tan((LEAN * Math.PI) / 180);
const pillarR = (y) => R0 + ((R1 - R0) * (y - PY0)) / PH;

// Curved beam in the front view (x, y), extruded along Z. The upturn is
// concentrated at the ends (exponent) so the silhouette sweeps up.
function beam(x0, x1, base, thick, liftK, ex, grow = 0, n = 24) {
  const lift = (x) => liftK * Math.pow(Math.abs(x) / 30, ex);
  const top = [];
  const bot = [];
  for (let i = 0; i <= n; i++) {
    const x = x0 + ((x1 - x0) * i) / n;
    top.push([x, base + thick + lift(x) + grow]);
    bot.push([x, base + lift(x) * 0.92 - grow]);
  }
  return [...bot, ...top.reverse()];
}

async function build() {
  const root = createRoot('Lane_ZoneGate');
  const rf = rframe(root);

  const ink = mat('Ink', 0x0d0f2b);
  const red = mat('Red', 0xe0453c);
  const gold = mat('Gold', 0xffc21a);
  const accent = mat('Accent', 0xff00ff);
  const straw = mat('Rope', 0xf4d58a);
  const white = mat('White', 0xffffff);
  const face = mat('Face', 0xfff6e0);

  for (const s of [-1, 1]) {
    // Stepped ink plinth, outboard of the pillar: inner face |x| = 22.6, outer 30.
    P(`PlinthLow${s}`, slab(7.4, 1.4, 8, { r: 0.8, b: 0.3, seg: 2, bseg: 1 }), ink, rf, [s * 26.3, 0, 0]);
    P(`PlinthHigh${s}`, slab(6.6, 1.2, 7.4, { r: 0.6, b: 0.25, seg: 2, bseg: 1 }), ink, rf, [s * 26.3, 1.3, 0]);

    // Pillar: tapered, leaning in.
    const rot = [0, 0, s * LEAN];
    P(`Pillar${s}`, disc(R0, PH, { b: 0.15, seg: 4, bseg: 1, top: R1 / R0 }), red, rf, [s * PX0, PY0, 0], rot);
    // Accent bands: a fat foot band (nemaki) and a band under the nuki.
    for (const y0 of [2.6, 19.4]) {
      P(`Band${s}${y0}`, disc(pillarR(y0) + 0.25, 1.2, { b: 0.25, seg: 4, bseg: 1 }), accent, rf, [s * pillarX(y0), y0, 0], rot);
    }

    // Gold wedges (kusabi) through the nuki ends, outboard of the pillars.
    P(`Wedge${s}`, slab(0.8, 2.2, 2.6, { r: 0.15, b: 0.12, seg: 1, bseg: 1 }), gold, rf, [s * 27.9, 22.4, 0]);

    // Hanging lantern from the nuki's protruding end.
    const LX = s * 28.7;
    P(`LanHook${s}`, slab(0.45, 0.8, 0.45, { r: 0.1, b: 0.1, seg: 1, bseg: 1 }), gold, rf, [LX, 22.0, 0]);
    P(`LanCapT${s}`, disc(0.8, 0.5, { b: 0.15, seg: 2, bseg: 1 }), gold, rf, [LX, 21.7, 0]);
    P(`Lantern${s}`, disc(1.25, 3.2, { b: 1.0, seg: 3, bseg: 2 }), accent, rf, [LX, 18.7, 0]);
    P(`LanCapB${s}`, disc(0.8, 0.5, { b: 0.15, seg: 2, bseg: 1 }), gold, rf, [LX, 18.4, 0]);

    // Guardian fox, sitting on the plinth's outer front corner, facing -Z.
    const fx = s * 28.4;
    const fz = -2.9;
    const fy = 2.5;
    P(`FoxBody${s}`, slab(1.9, 2.1, 2.0, { r: 0.7, b: 0.5, seg: 2, bseg: 1, top: 0.7 }), white, rf, [fx, fy, fz]);
    P(`FoxBib${s}`, slab(1.6, 0.5, 1.6, { r: 0.6, b: 0.15, seg: 2, bseg: 1 }), accent, rf, [fx, fy + 1.85, fz - 0.05]);
    P(`FoxHead${s}`, slab(1.5, 1.25, 1.4, { r: 0.55, b: 0.4, seg: 2, bseg: 1 }), white, rf, [fx, fy + 2.2, fz - 0.1]);
    P(`FoxSnout${s}`, slab(0.6, 0.55, 0.9, { r: 0.2, b: 0.15, seg: 1, bseg: 1, top: 0.7 }), white, rf, [fx, fy + 2.45, fz - 0.9]);
    P(`FoxNose${s}`, slab(0.4, 0.4, 0.4, { r: 0.18, b: 0.15, seg: 1, bseg: 1 }), ink, rf, [fx, fy + 2.62, fz - 1.33]);
    for (const e of [-1, 1])
      P(`FoxEar${s}${e}`, slab(0.6, 0.95, 0.45, { r: 0.1, b: 0.05, seg: 1, bseg: 1, top: 0.25 }), white, rf, [fx + e * 0.42, fy + 3.3, fz - 0.05]);
    P(`FoxTail${s}`, slab(0.9, 2.3, 0.9, { r: 0.4, b: 0.3, seg: 2, bseg: 1 }), white, rf, [fx + s * 0.95, fy + 0.2, fz + 0.6], [0, 0, -s * 22]);
    P(`FoxTailTip${s}`, slab(0.8, 0.7, 0.8, { r: 0.4, b: 0.3, seg: 2, bseg: 1 }), gold, rf, [fx + s * 1.8, fy + 2.15, fz + 0.6], [0, 0, -s * 22]);
  }

  // Nuki: red lower beam, underside y = 22.6, protruding past the pillars.
  P('Nuki', slab(58.0, 1.8, 2.2, { r: 0.3, b: 0.3, seg: 1, bseg: 1 }), red, rf, [0, 22.6, 0]);

  // Banner board: accent frame, cream face 22 x 4.5 (one box = one front quad).
  V('BannerFrame', 24.4, 6.0, 1.3, accent, rf, 0, 26.2, -1.6, { r: 0.5, b: 0.3, seg: 2, bseg: 1 });
  P('Face', boxGeo(22, 4.5, 0.4), face, rf, [0, 26.2, -1.5]);

  // Two stacked curved upper beams: red shimaki below, ink kasagi on top,
  // gold tips continuing the kasagi's upturn out to x = +-30.
  const shimaki = await extrudeProfile(beam(-28.0, 28.0, 27.4, 1.5, 1.7, 2.4), { depth: 3.0, axis: 'z' });
  P('Shimaki', shimaki, red, rf, [0, 0, 0]);
  const kasagi = await extrudeProfile(beam(-27.4, 27.4, 28.7, 1.6, 1.9, 2.4), { depth: 4.0, axis: 'z' });
  P('Kasagi', kasagi, ink, rf, [0, 0, 0]);
  for (const s of [-1, 1]) {
    const pts = s > 0 ? beam(27.2, 29.9, 28.7, 1.6, 1.9, 2.4, 0.1, 4) : beam(-29.9, -27.2, 28.7, 1.6, 1.9, 2.4, 0.1, 4);
    const tip = await extrudeProfile(pts, { depth: 4.2, axis: 'z' });
    P(`GoldTip${s}`, tip, gold, rf, [0, 0, 0]);
  }
  // Gold plates on the kasagi top over the pillars.
  for (const s of [-1, 1]) P(`Cap${s}`, slab(1.8, 0.5, 4.2, { r: 0.2, b: 0.15, seg: 1, bseg: 1 }), gold, rf, [s * 24.4, 28.7 + 1.6 + 1.9 * Math.pow(24.4 / 30, 2.4) - 0.2, 0]);

  // Shimenawa: a THICK three-strand twisted straw rope sagging under the nuki,
  // fattest in the middle, ends buried in the pillars.
  const XE = 23.0;
  const ropeY = (x) => 22.2 - 0.6 * (1 - Math.pow(x / XE, 2));
  const prof = [];
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    const r = 0.85 + 0.18 * Math.cos(3 * a);
    prof.push([r * Math.cos(a), r * Math.sin(a)]);
  }
  const path = [];
  const scale = [];
  const NS = 18;
  for (let i = 0; i <= NS; i++) {
    const x = -XE + (2 * XE * i) / NS;
    path.push([x, ropeY(x), -0.35]);
    const f = 1 + 0.35 * (1 - Math.pow(x / XE, 2));
    scale.push([f, f]);
  }
  P('Rope', sweepProfile(prof, path, { twist: 1080, scale, cap: true }), straw, rf, [0, 0, 0]);
  // Paper shide (zigzag white strips) and straw tufts hang IN FRONT of the
  // rope from its upper half, so nothing drops below y = 20 in the opening.
  const zig = [
    [-0.5, 0],
    [0.5, 0],
    [0.5, -0.55],
    [0.05, -0.55],
    [0.5, -1.1],
    [0.05, -1.1],
    [0.5, -1.65],
    [-0.5, -1.65],
    [-0.05, -1.1],
    [-0.5, -1.1],
    [-0.05, -0.55],
    [-0.5, -0.55],
  ];
  const shide = await extrudeProfile(zig, { depth: 0.4, axis: 'z' });
  for (const x of [-15, -7.5, 0, 7.5, 15]) P(`Shide${x}`, shide, white, rf, [x, ropeY(x) + 0.5, -1.6]);
  for (const x of [-11.25, -3.75, 3.75, 11.25]) {
    const y = ropeY(x);
    P(`Tuft${x}`, slab(1.0, 1.3, 0.9, { r: 0.3, b: 0.15, seg: 2, bseg: 1, top: 1.5 }), straw, rf, [x, y - 0.9, -1.3]);
  }

  return root;
}
