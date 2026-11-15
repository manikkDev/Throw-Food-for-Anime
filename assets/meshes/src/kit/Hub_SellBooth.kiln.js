// Hub_SellBooth: market stall. Red and white striped awning sloping down to
// the front, scalloped valance, a counter with coin stacks, a big coin sign.
// Art bible: design/kit.json -> kit.Hub_SellBooth, size [12, 10, 8] studs.
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

const meta = { name: 'Hub_SellBooth', category: 'prop' };

async function build() {
  const root = createRoot('Hub_SellBooth');
  const rf = rframe(root);

  const dark = mat('Base', 0x8a5a2b);
  const wood = mat('Wood', 0xb5793f);
  const red = mat('Red', 0xe0453c);
  const white = mat('White', 0xffffff);
  const gold = mat('Gold', 0xffc21a);

  // Platform (darker base lip), back shelf, counter with a white top band.
  P('Platform', slab(12, 0.5, 8, { r: 0.5, b: 0.18, seg: 2, bseg: 1 }), dark, rf, [0, 0, 0]);
  P('Shelf', slab(10.6, 4.2, 1.4, { r: 0.3, b: 0.2, seg: 2, bseg: 1 }), wood, rf, [0, 0.35, 2.8]);
  P('Counter', slab(10.6, 3.1, 2.4, { r: 0.35, b: 0.2, seg: 2, bseg: 1 }), wood, rf, [0, 0.35, -2.3]);
  P('CounterTop', slab(11.2, 0.5, 2.9, { r: 0.35, b: 0.18, seg: 2, bseg: 1 }), white, rf, [0, 3.4, -2.3]);
  // a red band across the counter front (key trim), proud of the wood
  V('CounterBand', 10.0, 0.8, 0.4, red, rf, 0, 2.2, -3.62, { r: 0.2, b: 0.1, seg: 1 });
  // coin stacks on the counter
  for (const [x, h] of [
    [-3.6, 0.9],
    [-2.6, 0.6],
    [3.3, 0.75],
  ])
    P(`Stack${x}`, disc(0.45, h, { b: 0.1, seg: 3, bseg: 1 }), gold, rf, [x, 3.85, -2.3]);

  // Posts: front ones stop under the low front edge, back ones under the high back edge.
  const SLOPE = (10.8 * Math.PI) / 180;
  const awY = (z) => 7.8 + z * Math.tan(SLOPE); // awning underside centre line
  for (const sx of [-1, 1])
    for (const sz of [-1, 1]) {
      const z = sz * 3.3;
      P(`Post${sx}${sz}`, slab(0.7, awY(z) + 0.1, 0.7, { r: 0.15, b: 0.1, seg: 1, bseg: 1 }), wood, rf, [sx * 5.3, 0, z]);
    }

  // Awning: 8 stripes, 1.5 wide, alternating red and white, back high.
  const N = 8;
  const W = 12 / N;
  const L = 8.2;
  for (let i = 0; i < N; i++) {
    const x = -6 + W / 2 + i * W;
    P(`Stripe${i}`, slab(W, 0.45, L, { r: 0.1, b: 0.12, seg: 1, bseg: 1 }), i % 2 ? white : red, rf, [x, 7.8, 0], [-10.8, 0, 0]);
  }
  // Scalloped valance under the front edge, colour matching each stripe.
  const half = [];
  for (let k = 0; k <= 6; k++) {
    const t = (k / 6) * Math.PI;
    half.push([0.7 * Math.cos(t), -0.7 * Math.sin(t)]);
  }
  const scallop = await extrudeProfile(half, { depth: 0.4, axis: 'z' });
  const frontY = awY(-L / 2) + 0.06;
  for (let i = 0; i < N; i++) {
    const x = -6 + W / 2 + i * W;
    P(`Scallop${i}`, scallop, i % 2 ? white : red, rf, [x, frontY, -3.85]);
  }

  // Coin sign standing on the awning front: gold disc, red square centre.
  V('Coin', 2.6, 2.6, 0.5, gold, rf, 0, 8.6, -3.45, { r: 1.3, b: 0.18, seg: 4, bseg: 1 });
  V('CoinRim', 2.0, 2.0, 0.5, gold, rf, 0, 8.6, -3.55, { r: 1.0, b: 0.15, seg: 4, bseg: 1 });
  V('CoinSquare', 0.8, 0.8, 0.4, red, rf, 0, 8.6, -3.65, { r: 0.1, b: 0.08, seg: 1 });

  return root;
}
