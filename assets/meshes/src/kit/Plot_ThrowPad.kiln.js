// Plot_ThrowPad: round launch pad. Yellow disc, white ring, a bold arrow
// pointing down the lane (+Z in Roblox).
// Art bible: design/kit.json -> kit.Plot_ThrowPad, size [10, 0.6, 10] studs.
//
// ---- shared kit prelude (identical in every kit/*.kiln.js) ----------------
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
const P = (name, geo, m, parent, position = [0, 0, 0], rotation = [0, 0, 0]) =>
  createPart(name, geo, m, { position, rotation, parent });
// Upright panel facing -Z with rounded corners in the FRONT view: w wide,
// h tall centred on yc, t thick, front face at zFront (back at zFront + t).
const V = (name, w, h, t, m, parent, x, yc, zFront, o = {}) =>
  P(name, slab(w, t, h, o), m, parent, [x, yc, zFront + t], [-90, 0, 0]);
// ---- end prelude ----------------------------------------------------------

const meta = { name: 'Plot_ThrowPad', category: 'prop' };

async function build() {
  const root = createRoot('Plot_ThrowPad');
  const rf = rframe(root);

  const lip = mat('BaseLip', 0x6b7686);
  const ring = mat('Ring', 0xffffff);
  const pad = mat('Pad', 0xffd23f);
  const arrow = mat('Arrow', 0xff5a36);

  // Stepped discs: every top is a different height (0.40 / 0.46 / 0.52 / 0.60),
  // so no two colours share a plane.
  P('BaseLip', disc(5.0, 0.4, { b: 0.14, seg: 8, bseg: 1 }), lip, rf);
  P('Ring', disc(4.6, 0.46, { b: 0.16, seg: 8, bseg: 1 }), ring, rf);
  P('Pad', disc(3.9, 0.52, { b: 0.14, seg: 8, bseg: 1 }), pad, rf);

  // Arrow: tip at z = +3.2 (down the lane), shaft tail at z = -0.4. Profile is [X, -Z].
  const outline = [
    [0, -3.2],
    [2.1, -0.95],
    [0.9, -0.95],
    [0.9, 0.4],
    [-0.9, 0.4],
    [-0.9, -0.95],
    [-2.1, -0.95],
  ];
  const arrowGeo = await extrudeProfile(outline, { depth: 0.4, bevel: 0.18, segments: 3, axis: 'y', center: false });
  P('Arrow', arrowGeo, arrow, rf, [0, 0.2, 0]);

  // Two chevrons trailing the arrow, so the launch direction reads from any
  // angle and the pad does not look like a road sign. Tip at local z = 0.
  const chev = (w, t, drop) => [
    [0, 0],
    [w / 2, drop],
    [w / 2, drop + t],
    [0, t],
    [-w / 2, drop + t],
    [-w / 2, drop],
  ];
  const c1 = await extrudeProfile(chev(3.4, 0.75, 1.0), { depth: 0.4, bevel: 0.12, segments: 3, axis: 'y', center: false });
  const c2 = await extrudeProfile(chev(2.6, 0.7, 0.8), { depth: 0.4, bevel: 0.12, segments: 3, axis: 'y', center: false });
  P('Chevron1', c1, arrow, rf, [0, 0.2, -0.85]);
  P('Chevron2', c2, arrow, rf, [0, 0.2, -2.1]);

  return root;
}
