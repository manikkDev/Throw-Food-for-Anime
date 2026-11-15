// Hub_LeaderboardFrame: standing board, thick gold frame, blank face exactly
// 10 wide x 13 high (Face_0D0F2B, own part, front quad facing -Z), crest on top.
// Art bible: design/kit.json -> kit.Hub_LeaderboardFrame, size [12, 16, 1.5] studs.
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

const meta = { name: 'Hub_LeaderboardFrame', category: 'prop' };

async function build() {
  const root = createRoot('Hub_LeaderboardFrame');
  const rf = rframe(root);

  const base = mat('Base', 0x8a5a2b);
  const gold = mat('Frame', 0xffc21a);
  const face = mat('Face', 0x0d0f2b);
  const red = mat('Crest', 0xe0453c);
  const white = mat('Star', 0xffffff);

  // Plinth (darker base lip), full footprint.
  P('Plinth', slab(12, 0.9, 1.5, { r: 0.3, b: 0.2, seg: 2, bseg: 1 }), base, rf, [0, 0, 0]);
  // Thick gold frame, rounded corners in the front view.
  V('Frame', 12, 14.2, 1.2, gold, rf, 0, 7.7, -0.6, { r: 0.7, b: 0.25, seg: 3 });
  // Face: plain box 10 x 13, 0.1 proud of the frame front.
  P('Face', boxGeo(10, 13, 0.4), face, rf, [0, 7.7, -0.5]);
  // Inner gold lip round the face would share its plane; instead four fat
  // studs on the frame corners give the frame some richness.
  for (const sx of [-1, 1])
    for (const sy of [-1, 1]) V(`Stud${sx}${sy}`, 0.7, 0.7, 0.4, red, rf, sx * 5.5, 7.7 + sy * 6.65, -0.75, { r: 0.35, b: 0.15, seg: 2 });

  // Crest: sits on the frame top; its lower 0.15 hides BEHIND the face
  // (crest front -0.5/-0.65 vs face front -0.7), so the face is never covered.
  // Red disc with a gold rim and a white star, standing on the frame top.
  V('CrestRim', 2.3, 2.3, 1.0, gold, rf, 0, 15.1, -0.5, { r: 1.15, b: 0.25, seg: 4, bseg: 1 });
  V('Crest', 1.7, 1.7, 1.0, red, rf, 0, 15.1, -0.65, { r: 0.85, b: 0.2, seg: 4, bseg: 1 });
  const star = [];
  for (let i = 0; i < 10; i++) {
    const a = Math.PI / 2 + (i * Math.PI) / 5;
    const r = i % 2 ? 0.33 : 0.75;
    star.push([r * Math.cos(a), r * Math.sin(a)]);
  }
  const starGeo = await extrudeProfile(star, { depth: 0.5, axis: 'z' });
  P('Star', starGeo, white, rf, [0, 15.1, -0.6]);

  return root;
}
