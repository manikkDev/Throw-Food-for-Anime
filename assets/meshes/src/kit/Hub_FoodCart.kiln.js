// Hub_FoodCart: yatai street-food cart. Two big wheels, a counter with bowls,
// a blue and white striped gable awning, noren flaps, a red paper lantern.
// Art bible: design/kit.json -> kit.Hub_FoodCart, size [12, 10, 7] studs.
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

const meta = { name: 'Hub_FoodCart', category: 'prop' };

function build() {
  const root = createRoot('Hub_FoodCart');
  const rf = rframe(root);

  const dark = mat('Dark', 0x8a5a2b);
  const wood = mat('Wood', 0xb5793f);
  const blue = mat('Blue', 0x2f7de1);
  const white = mat('White', 0xffffff);
  const red = mat('Red', 0xe0453c);

  // Chassis (dark lip) and cart body.
  P('Chassis', slab(9.6, 0.6, 4.8, { r: 0.3, b: 0.18, seg: 2, bseg: 1 }), dark, rf, [0, 1.2, 0.6]);
  P('Body', slab(9.0, 2.9, 4.3, { r: 0.35, b: 0.2, seg: 2, bseg: 1 }), wood, rf, [0, 1.65, 0.6]);
  // blue band on the body front (key trim)
  V('BodyBand', 8.4, 0.8, 0.4, blue, rf, 0, 3.1, -1.8, { r: 0.2, b: 0.1, seg: 1 });
  // Counter: white top overhanging the front.
  P('Counter', slab(10.0, 0.5, 2.4, { r: 0.3, b: 0.16, seg: 2, bseg: 1 }), white, rf, [0, 4.5, -1.3]);

  // Wheels: dark discs on the sides, red hubs.
  for (const s of [-1, 1]) {
    P(`Wheel${s}`, disc(1.8, 0.6, { b: 0.2, seg: 5, bseg: 1 }), dark, rf, [s * 4.7, 1.8, 0.6], [0, 0, s * -90]);
    P(`Hub${s}`, disc(0.6, 0.5, { b: 0.15, seg: 3, bseg: 1 }), red, rf, [s * 5.25, 1.8, 0.6], [0, 0, s * -90]);
  }
  // Handle shafts out of the back.
  for (const s of [-1, 1]) P(`Shaft${s}`, slab(0.45, 0.45, 1.6, { r: 0.1, b: 0.1, seg: 1, bseg: 1 }), dark, rf, [s * 3.4, 2.4, 3.5]);

  // Bowls on the counter: red tapered bowls with white noodle tops.
  for (const x of [-3, 0, 3]) {
    P(`Bowl${x}`, disc(0.55, 0.6, { b: 0.12, seg: 3, bseg: 1, top: 1.35 }), red, rf, [x, 4.95, -1.5]);
    P(`Noodles${x}`, disc(0.6, 0.4, { b: 0.15, seg: 3, bseg: 1 }), white, rf, [x, 5.25, -1.5]);
  }

  // Four posts up to the roof.
  for (const sx of [-1, 1])
    for (const sz of [-1, 1]) P(`Post${sx}${sz}`, slab(0.6, 3.75, 0.6, { r: 0.12, b: 0.1, seg: 1, bseg: 1 }), wood, rf, [sx * 4.3, 4.6, sz < 0 ? -1.2 : 2.6]);

  // Gable awning, ridge along X at z = 0.7, 8 stripes per slope.
  const N = 8;
  const W = 11.6 / N;
  const PITCH = 24;
  const SL = 3.9; // slope length
  const ridgeY = 9.3;
  const dz = (SL / 2) * Math.cos((PITCH * Math.PI) / 180);
  const dy = (SL / 2) * Math.sin((PITCH * Math.PI) / 180);
  for (let i = 0; i < N; i++) {
    const x = -5.8 + W / 2 + i * W;
    const m = i % 2 ? white : blue;
    P(`RoofF${i}`, slab(W, 0.45, SL, { r: 0.08, b: 0.12, seg: 1, bseg: 1 }), m, rf, [x, ridgeY - dy - 0.25, 0.7 - dz], [-PITCH, 0, 0]);
    P(`RoofB${i}`, slab(W, 0.45, SL, { r: 0.08, b: 0.12, seg: 1, bseg: 1 }), m, rf, [x, ridgeY - dy - 0.25, 0.7 + dz], [PITCH, 0, 0]);
  }
  P('Ridge', slab(12.0, 0.6, 0.9, { r: 0.2, b: 0.2, seg: 2, bseg: 1 }), dark, rf, [0, ridgeY - 0.05, 0.7]);

  // Noren: four short blue/white flaps under the front eave.
  const eaveZ = 0.7 - 2 * dz + 0.15;
  for (let i = 0; i < 4; i++) V(`Noren${i}`, 1.9, 1.1, 0.4, i % 2 ? blue : white, rf, -3.15 + i * 2.1, 6.95, eaveZ - 0.2, { r: 0.12, b: 0.1, seg: 1 });

  // Red paper lantern hanging off the front right corner.
  const LX = 5.3;
  const LZ = eaveZ - 0.1;
  P('LanternCapT', disc(0.38, 0.4, { b: 0.1, seg: 2, bseg: 1 }), dark, rf, [LX, 7.05, LZ]);
  P('Lantern', disc(0.62, 1.5, { b: 0.55, seg: 3, bseg: 2 }), red, rf, [LX, 5.65, LZ]);
  P('LanternCapB', disc(0.38, 0.4, { b: 0.1, seg: 2, bseg: 1 }), dark, rf, [LX, 5.4, LZ]);

  return root;
}
