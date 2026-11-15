// Hub_IndexBoard: an open giant book (the hero index) on a wooden stand. Blue
// cover; the open pages are one blank face (Face_FFFFFF, own part, front quad
// facing -Z) for a SurfaceGui.
// Art bible: design/kit.json -> kit.Hub_IndexBoard, size [10, 9, 1.5] studs.
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

const meta = { name: 'Hub_IndexBoard', category: 'prop' };

function build() {
  const root = createRoot('Hub_IndexBoard');
  const rf = rframe(root);

  const wood = mat('Stand', 0x8a5a2b);
  const blue = mat('Cover', 0x3b6fe0);
  const page = mat('Face', 0xffffff);
  const gold = mat('Gold', 0xffc21a);
  const red = mat('Ribbon', 0xe0453c);

  // Stand: foot, post, and a ledge the book rests on.
  P('Foot', slab(6.0, 0.6, 1.5, { r: 0.4, b: 0.2, seg: 2, bseg: 1 }), wood, rf, [0, 0, 0]);
  P('Post', slab(1.3, 3.0, 0.9, { r: 0.25, b: 0.12, seg: 2, bseg: 1 }), wood, rf, [0, 0.4, 0.1]);
  P('Ledge', slab(9.0, 0.6, 1.4, { r: 0.3, b: 0.18, seg: 2, bseg: 1 }), wood, rf, [0, 3.0, 0]);

  // Cover: blue board behind the pages, rounded corners, with a spine bump
  // poking out above and below the pages at the centre.
  V('Cover', 10.0, 6.4, 0.6, blue, rf, 0, 6.25, -0.1, { r: 0.6, b: 0.18, seg: 3 });
  V('Spine', 1.2, 6.9, 0.8, blue, rf, 0, 6.2, -0.2, { r: 0.45, b: 0.2, seg: 3 });
  // Gold corner caps on the cover.
  for (const sx of [-1, 1])
    for (const sy of [-1, 1]) V(`Corner${sx}${sy}`, 1.1, 1.1, 0.85, gold, rf, sx * 4.6, 6.25 + sy * 2.85, -0.25, { r: 0.4, b: 0.15, seg: 2 });

  // Pages: one flat face, 8.4 x 4.6 (a fat blue cover border shows round it), 0.3 proud of the cover front.
  P('Face', boxGeo(8.4, 4.6, 0.5), page, rf, [0, 6.2, -0.15]);

  // Bookmark ribbon hanging below the pages, over the ledge front.
  V('Ribbon', 0.7, 1.6, 0.4, red, rf, 3.0, 2.85, -0.8, { r: 0.15, b: 0.1, seg: 1 });

  return root;
}
