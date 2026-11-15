// Hub_DailyChest: fat treasure chest, domed lid hinged at the back and open
// 16 degrees, a yellow glow slab showing in the gap, big gold lock plate.
// Art bible: design/kit.json -> kit.Hub_DailyChest, size [6, 5, 4.5] studs.
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

const meta = { name: 'Hub_DailyChest', category: 'prop' };

// Lid cross-section in (z, y), hinged at the back (+Z) edge and opened by `a`
// degrees (front edge lifts). Returned as extrudeProfile axis-'x' points [u=-z, v=y].
function lidProfile(halfD, wall, dome, a, grow = 0) {
  const pts = [];
  pts.push([halfD + grow, -grow]);
  const N = 8;
  for (let i = 0; i <= N; i++) {
    const t = (i / N) * Math.PI;
    pts.push([(halfD + grow) * Math.cos(t), wall + (dome + grow) * Math.sin(t)]);
  }
  pts.push([-(halfD + grow), -grow]);
  const r = (a * Math.PI) / 180;
  const zh = halfD;
  return pts.map(([z, y]) => {
    const dz = z - zh;
    return [-(zh + dz * Math.cos(r) + y * Math.sin(r)), y * Math.cos(r) - dz * Math.sin(r)];
  });
}

async function build() {
  const root = createRoot('Hub_DailyChest');
  const rf = rframe(root);

  const dark = mat('Base', 0x8a5a2b);
  const wood = mat('Wood', 0xb5793f);
  const gold = mat('Gold', 0xffc21a);
  const glow = mat('Glow', 0xfff27a, { emissive: 0xfff27a, emissiveIntensity: 0.6 });
  const ink = mat('Keyhole', 0x0d0f2b);

  P('BaseLip', slab(6.0, 0.5, 4.5, { r: 0.4, b: 0.18, seg: 2, bseg: 1 }), dark, rf, [0, 0, 0]);
  P('Body', slab(5.6, 2.6, 4.1, { r: 0.35, b: 0.2, seg: 2, bseg: 1 }), wood, rf, [0, 0.3, 0]);
  // glow slab inside, showing in the open gap
  P('Glow', slab(5.1, 0.95, 3.6, { r: 0.2, b: 0.1, seg: 1, bseg: 1 }), glow, rf, [0, 2.6, -0.05]);

  const A = 16;
  const lid = await extrudeProfile(lidProfile(2.05, 0.45, 1.0, A), { depth: 5.7, axis: 'x', bevel: 0.12, segments: 2 });
  P('Lid', lid, wood, rf, [0, 2.9, 0]);
  // gold straps (body strap top 2.98, 0.08 above the body top 2.9: not coplanar): on the lid (same profile, grown 0.1) and down the body
  const strap = await extrudeProfile(lidProfile(2.05, 0.45, 1.0, A, 0.1), { depth: 0.65, axis: 'x' });
  for (const s of [-1, 1]) {
    P(`LidStrap${s}`, strap, gold, rf, [s * 1.85, 2.9, 0]);
    P(`BodyStrap${s}`, slab(0.65, 2.58, 4.24, { r: 0.12, b: 0.1, seg: 1, bseg: 1 }), gold, rf, [s * 1.85, 0.4, 0]);
  }
  // lock plate on the body front, keyhole in ink
  V('Lock', 1.5, 1.7, 0.45, gold, rf, 0, 2.0, -2.2, { r: 0.35, b: 0.12, seg: 2 });
  V('Keyhole', 0.42, 0.7, 0.4, ink, rf, 0, 1.85, -2.28, { r: 0.2, b: 0.08, seg: 2 });

  return root;
}
