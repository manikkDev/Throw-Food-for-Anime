// Plot_SlotSign: wooden signboard on two posts, small roof on top, and a blank
// flat face for a SurfaceGui. The face is its own colour part (Face_FFF6E0)
// whose front (-Z) is one flat quad and is the frontmost surface of that part,
// so SurfaceGui Face=Front on that MeshPart lands exactly on it.
// Art bible: design/kit.json -> kit.Plot_SlotSign, size [5, 6, 1] studs.
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

const meta = { name: 'Plot_SlotSign', category: 'prop' };

async function build() {
  const root = createRoot('Plot_SlotSign');
  const rf = rframe(root);

  const dark = mat('Post', 0x8a5a2b);
  const wood = mat('Board', 0xb5793f);
  const face = mat('Face', 0xfff6e0);
  const roof = mat('Roof', 0xe0453c);

  // Posts behind the board, fat, with a wider foot (darker base lip).
  for (const s of [-1, 1]) {
    P(`Foot${s}`, slab(0.9, 0.5, 0.9, { r: 0.18, b: 0.12, seg: 2 }), dark, rf, [s * 1.85, 0, 0.05]);
    P(`Post${s}`, slab(0.6, 4.7, 0.6, { r: 0.14, b: 0.1, seg: 2, bseg: 1 }), dark, rf, [s * 1.85, 0.3, 0.1]);
  }
  // Board: light wood frame, front at z = -0.4.
  P('Board', slab(4.6, 3.2, 0.6, { r: 0.3, b: 0.16, seg: 2 }), wood, rf, [0, 1.9, -0.1]);
  // Face panel: plain box (front = one quad), 0.12 proud of the board front.
  P('Face', boxGeo(3.9, 2.5, 0.4), face, rf, [0, 3.5, -0.32]);

  // Roof: a bevelled gable prism along Z, eaves overhanging the board.
  const gable = await extrudeProfile(
    [
      [-2.75, 0],
      [2.75, 0],
      [0, 1.0],
    ],
    { depth: 1.0, axis: 'z', bevel: 0.1, segments: 2 },
  );
  P('Roof', gable, roof, rf, [0, 5.04, -0.05]);
  // Ridge knob in roof colour so the top reads as a little house.
  P('Knob', slab(0.6, 0.45, 0.6, { r: 0.3, b: 0.2, seg: 3 }), roof, rf, [0, 5.55, -0.05]);

  return root;
}
