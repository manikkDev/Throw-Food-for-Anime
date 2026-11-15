// Plot_Fence: one fence section. Two fat posts with rounded caps, two chunky
// rails. Tiles end to end along X: the post feet's outer faces sit exactly at
// x = -4 and x = +4, so two sections placed 8 studs apart touch with no gap.
// Art bible: design/kit.json -> kit.Plot_Fence, size [8, 3, 0.8] studs.
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

const meta = { name: 'Plot_Fence', category: 'prop' };

function build() {
  const root = createRoot('Plot_Fence');
  const rf = rframe(root);

  const foot = mat('Foot', 0x8a5a2b);
  const post = mat('Post', 0xb5793f);
  const rail = mat('Rail', 0xffffff);
  const cap = mat('Cap', 0xffd23f);

  const L = 8;
  const FOOT_W = 1.1; // foot: wider than the post along the fence, full 0.8 depth
  const FOOT_D = 0.8;
  const POST_W = 0.86; // fat post; depth kept under the foot so no side faces share a plane
  const POST_D = 0.7;
  for (const side of [-1, 1]) {
    const x = side * (L / 2 - FOOT_W / 2); // foot outer face exactly at +-4
    P(`Foot${side}`, slab(FOOT_W, 0.6, FOOT_D, { r: 0.2, b: 0.14, seg: 2 }), foot, rf, [x, 0, 0]);
    P(`Post${side}`, slab(POST_W, 2.2, POST_D, { r: 0.2, b: 0.1, seg: 2, bseg: 1 }), post, rf, [x, 0.4, 0]);
    // round cap: a squashed ball that overhangs the post
    P(`Cap${side}`, slab(1.0, 0.62, 0.8, { r: 0.4, b: 0.29, seg: 4, bseg: 2 }), cap, rf, [x, 2.38, 0]);
  }

  // Rails run between the posts and are buried 0.15 in each, so their end
  // faces are hidden inside the posts (no coplanar faces at the tile join).
  const half = L / 2 - FOOT_W / 2 - POST_W / 2 + 0.15;
  for (const [i, y] of [
    [0, 0.85],
    [1, 1.72],
  ]) {
    P(`Rail${i}`, slab(half * 2, 0.62, 0.46, { r: 0.12, b: 0.14, seg: 1, bseg: 1 }), rail, rf, [0, y, 0]);
  }

  return root;
}
