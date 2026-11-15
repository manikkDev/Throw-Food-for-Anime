// Plot_NameArch: walk-through festival gate. Opening 10.9 wide x 8.0 high,
// a wide blank name board across the top (Face_FFFFFF, its own part, front
// quad facing -Z), paper lanterns hung off the outer side of both posts.
// Art bible: design/kit.json -> kit.Plot_NameArch, size [16, 11, 2.5] studs.
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

const meta = { name: 'Plot_NameArch', category: 'prop' };

async function build() {
  const root = createRoot('Plot_NameArch');
  const rf = rframe(root);

  const stone = mat('Base', 0x6b7686);
  const red = mat('Red', 0xe0453c);
  const ink = mat('Ink', 0x0d0f2b);
  const face = mat('Face', 0xffffff);
  const glow = mat('Lantern', 0xffd23f);

  const PX = 6.3; // post centre
  for (const s of [-1, 1]) {
    // stone foot (darker base lip), then a fat round pillar
    P(`Base${s}`, slab(2.3, 1.1, 2.3, { r: 0.4, b: 0.2, seg: 2, bseg: 1 }), stone, rf, [s * PX, 0, 0]);
    P(`Pillar${s}`, disc(0.85, 9.6, { b: 0.1, seg: 4, bseg: 1 }), red, rf, [s * PX, 0.8, 0]);
    // lantern arm (ink) out of the post's outer side
    P(`Arm${s}`, slab(1.3, 0.4, 0.4, { r: 0.1, b: 0.1, seg: 1, bseg: 1 }), ink, rf, [s * (PX + 0.95), 7.3, 0]);
    // paper lantern: fat yellow body with ink caps, hung under the arm
    const LX = s * (PX + 1.4);
    P(`LanternTop${s}`, disc(0.4, 0.4, { b: 0.1, seg: 2, bseg: 1 }), ink, rf, [LX, 6.95, 0]);
    P(`LanternBody${s}`, disc(0.62, 1.6, { b: 0.55, seg: 3, bseg: 2 }), glow, rf, [LX, 5.5, 0]);
    P(`LanternBot${s}`, disc(0.4, 0.4, { b: 0.1, seg: 2, bseg: 1 }), ink, rf, [LX, 5.25, 0]);
  }

  // Name board: red frame spanning between (and into) the pillars, white face
  // panel 0.1 proud of the frame front.
  P('BoardFrame', slab(13.2, 2.4, 0.9, { r: 0.25, b: 0.16, seg: 2 }), red, rf, [0, 8.0, 0]);
  P('Face', boxGeo(10.0, 1.65, 0.4), face, rf, [0, 9.12, -0.36]);

  // Shimaki (red tie under the top beam) and the kasagi: an ink top beam with
  // upturned ends, extruded from a front-view profile along Z.
  P('Shimaki', slab(15.0, 0.45, 1.5, { r: 0.15, b: 0.12, seg: 1 }), red, rf, [0, 10.0, 0]);
  const N = 12;
  const top = [];
  const bot = [];
  for (let i = 0; i <= N; i++) {
    const x = -8 + (16 * i) / N;
    const lift = 0.28 * Math.pow(Math.abs(x) / 8, 3);
    top.push([x, 0.45 + lift]);
    bot.push([x * 0.985, lift * 0.9]);
  }
  const kasagi = await extrudeProfile([...bot, ...top.reverse()], { depth: 2.2, axis: 'z' });
  P('Kasagi', kasagi, ink, rf, [0, 10.27, 0]);

  return root;
}
