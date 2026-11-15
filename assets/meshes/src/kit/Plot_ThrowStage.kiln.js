// Plot_ThrowStage: raised round throwing stage. Three wide steps up from the
// -Z (base) side, a thick white rim, a yellow launch disc with a bold arrow and
// two chevrons pointing +Z down the lane, four short corner posts with lantern
// caps, festival bunting between the two rear posts.
// The standing surface is FLAT at exactly y = 3: the yellow disc is extruded
// with the arrow and chevrons as HOLES, the arrow pieces fill those holes, and
// a white ring surrounds the disc; all three tops are at 3.000 and none overlap
// (no coplanar faces). The rounded white body below stops at 2.95, hidden.
// The drum is centred at z = +1.0 so the steps fit inside the 20-stud footprint.
// Art bible: design/kit.json -> kit.Plot_ThrowStage, size [20, 3, 20], budget 3000.
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

const meta = { name: 'Plot_ThrowStage', category: 'prop' };

async function build() {
  const root = createRoot('Plot_ThrowStage');
  const rf = rframe(root);

  const stone = mat('BaseLip', 0x6b7686);
  const white = mat('Rim', 0xffffff);
  const yellow = mat('Pad', 0xffd23f);
  const arrow = mat('Arrow', 0xff5a36);
  const wood = mat('Post', 0x8a5a2b);

  const CZ = 1.0; // drum centre z
  const TOP = 3.0;
  const Y0 = 0.4; // bottom of the flush top pieces
  const SEG = 32;

  // Base lip and rounded white body (top 2.95, under the flush pieces).
  P('BaseLip', disc(9.0, 0.5, { b: 0.18, seg: 8, bseg: 1 }), stone, rf, [0, 0, CZ]);
  P('Body', disc(8.8, 2.95 - Y0, { b: 0.4, seg: 8, bseg: 1 }), white, rf, [0, Y0, CZ]);

  // Arrow + chevrons, profile coords [X, -Z] relative to the drum centre.
  const S = 1.6;
  const arrowPts = [
    [0, -3.2],
    [2.1, -0.95],
    [0.9, -0.95],
    [0.9, 0.4],
    [-0.9, 0.4],
    [-0.9, -0.95],
    [-2.1, -0.95],
  ].map(([u, v]) => [u * S, v * S]);
  const chev = (tipZ, w, t, drop) =>
    [
      [0, 0],
      [w / 2, drop],
      [w / 2, drop + t],
      [0, t],
      [-w / 2, drop + t],
      [-w / 2, drop],
    ].map(([u, v]) => [u * S, (v - tipZ) * S]);
  const c1 = chev(-0.85, 3.4, 0.75, 1.0);
  const c2 = chev(-2.1, 2.6, 0.7, 0.8);
  const H = TOP - Y0;
  const ex = (outline, holes = []) => extrudeProfile(outline, { depth: H, axis: 'y', center: false, holes });

  // White ring: outer 8.4, inner 6.6 (same circleProfile phase as the disc).
  P('Ring', await ex(circleProfile(8.4, SEG), [circleProfile(6.6, SEG)]), white, rf, [0, Y0, CZ]);
  // Yellow disc with the markings cut out, then the markings themselves.
  P('Pad', await ex(circleProfile(6.6, SEG), [arrowPts, c1, c2]), yellow, rf, [0, Y0, CZ]);
  P('Arrow', await ex(arrowPts), arrow, rf, [0, Y0, CZ]);
  P('Chevron1', await ex(c1), arrow, rf, [0, Y0, CZ]);
  P('Chevron2', await ex(c2), arrow, rf, [0, Y0, CZ]);

  // Three wide white steps on the -Z side (rises 0.75; the deck is the 4th).
  for (const [i, zf] of [
    [1, -10.0],
    [2, -9.2],
    [3, -8.4],
  ]) {
    const zb = -6.5;
    P(`Step${i}`, slab(9.0, 0.75 * i, zb - zf, { r: 0.3, b: 0.12, seg: 1, bseg: 1 }), white, rf, [0, 0, (zf + zb) / 2]);
  }

  // Four corner posts on the rim with lantern caps.
  const pr = 7.5;
  const posts = [];
  for (const sx of [-1, 1])
    for (const sz of [-1, 1]) {
      const x = (sx * pr) / Math.SQRT2;
      const z = CZ + (sz * pr) / Math.SQRT2;
      posts.push([x, z, sz]);
      P(`Post${sx}${sz}`, disc(0.45, 2.3, { b: 0.1, seg: 2, bseg: 1 }), wood, rf, [x, 2.9, z]);
      P(`Lantern${sx}${sz}`, disc(0.65, 1.2, { b: 0.5, seg: 3, bseg: 2 }), arrow, rf, [x, 5.0, z]);
      P(`LanCap${sx}${sz}`, disc(0.5, 0.45, { b: 0.15, seg: 2, bseg: 1 }), yellow, rf, [x, 6.1, z]);
    }

  // Bunting between the two rear posts: a sagging white cord with flags.
  const rearZ = CZ + pr / Math.SQRT2;
  const x0 = -pr / Math.SQRT2;
  const cordY = (x) => 5.6 - 0.6 * (1 - Math.pow(x / x0, 2));
  const cord = [];
  for (let i = 0; i <= 12; i++) {
    const x = x0 + (-2 * x0 * i) / 12;
    cord.push([x, cordY(x), rearZ]);
  }
  P('Cord', sweepProfile(circleProfile(0.25, 6), cord, { cap: true }), white, rf, [0, 0, 0]);
  const flag = await extrudeProfile(
    [
      [-0.55, 0],
      [0.55, 0],
      [0, -1.1],
    ],
    { depth: 0.4, axis: 'z' },
  );
  for (let i = 0; i < 7; i++) {
    const x = x0 + (-2 * x0 * (i + 1)) / 8;
    P(`Flag${i}`, flag, i % 2 ? yellow : arrow, rf, [x, cordY(x) + 0.05, rearZ]);
  }

  return root;
}
