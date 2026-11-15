// Hub_GiftBox: big pink gift box, yellow ribbon both ways, a fat bow on top,
// white polka dots.
// Art bible: design/kit.json -> kit.Hub_GiftBox, size [5, 5, 5] studs.
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

const meta = { name: 'Hub_GiftBox', category: 'prop' };

function build() {
  const root = createRoot('Hub_GiftBox');
  const rf = rframe(root);

  const lipM = mat('Lip', 0xe05597);
  const pink = mat('Box', 0xff8fc0);
  const ribbon = mat('Ribbon', 0xffd23f);
  const dots = mat('Dots', 0xffffff);

  P('BaseLip', slab(4.8, 0.45, 4.8, { r: 0.35, b: 0.15, seg: 2, bseg: 1 }), lipM, rf, [0, 0, 0]);
  P('Box', slab(4.5, 3.2, 4.5, { r: 0.3, b: 0.2, seg: 2, bseg: 1 }), pink, rf, [0, 0.3, 0]);
  // lid overhangs the box, darker pink like the lip
  P('Lid', slab(4.9, 0.95, 4.9, { r: 0.35, b: 0.22, seg: 2, bseg: 1 }), lipM, rf, [0, 3.25, 0]);

  // Ribbon both ways: body bands 0.08 proud of the box, lid bands proud of the lid.
  P('BandX', slab(0.9, 3.0, 4.66, { r: 0.1, b: 0.05, seg: 1, bseg: 1 }), ribbon, rf, [0, 0.4, 0]);
  P('BandZ', slab(4.66, 3.0, 0.9, { r: 0.1, b: 0.05, seg: 1, bseg: 1 }), ribbon, rf, [0, 0.4, 0]);
  P('LidBandX', slab(0.9, 1.05, 5.06, { r: 0.1, b: 0.12, seg: 1, bseg: 1 }), ribbon, rf, [0, 3.2, 0]);
  P('LidBandZ', slab(5.06, 1.05, 0.9, { r: 0.1, b: 0.12, seg: 1, bseg: 1 }), ribbon, rf, [0, 3.2, 0]);

  // Bow: two fat loops tilted out, and a knot.
  for (const s of [-1, 1]) {
    P(`Loop${s}`, torusGeo(0.62, 0.26, 6, 12), ribbon, rf, [s * 0.68, 4.42, 0], [0, 0, s * -35]);
  }
  P('Knot', slab(0.9, 0.7, 0.9, { r: 0.45, b: 0.3, seg: 3, bseg: 2 }), ribbon, rf, [0, 4.05, 0]);

  // Polka dots: one in each quadrant of each side, 0.06 proud of the box.
  const H = 2.25;
  for (const [ax, sgn] of [
    ['z', -1],
    ['z', 1],
    ['x', -1],
    ['x', 1],
  ]) {
    for (const u of [-1.3, 1.3])
      for (const y of [1.15, 2.55]) {
        const geo = disc(0.36, 0.4, { b: 0.1, seg: 3, bseg: 1 });
        if (ax === 'z') P(`Dot${ax}${sgn}${u}${y}`, geo, dots, rf, [u, y, sgn * (H - 0.34)], [sgn * 90, 0, 0]);
        else P(`Dot${ax}${sgn}${u}${y}`, geo, dots, rf, [sgn * (H - 0.34), y, u], [0, 0, -sgn * 90]);
      }
  }

  return root;
}
