// Hub_SummonShrine: the premium summon spot, the richest object in the hub.
// Two-tier platform with a front step, four red pillars with gold rings and
// capitals, a sweeping curved red roof with gold gable ends, eave trim and
// ridge, pink ridge orbs, pink lanterns and banners, and a glowing scroll
// altar in the middle with a pink halo.
// Art bible: design/kit.json -> kit.Hub_SummonShrine, size [14, 14, 12] studs.
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

const meta = { name: 'Hub_SummonShrine', category: 'prop' };

// Roof cross-section in (z, y): concave sweep from ridge to upturned eaves.
function roofProfile(halfD, base, rise, thick, grow = 0) {
  const N = 12;
  const top = [];
  const bot = [];
  for (let i = 0; i <= N; i++) {
    const z = -halfD + (2 * halfD * i) / N;
    const a = Math.abs(z) / halfD;
    const y = base + rise * Math.pow(1 - a, 1.8) + 0.5 * Math.pow(a, 5);
    top.push([z * (1 + grow / halfD), y + grow]);
    bot.push([z * (1 + grow / halfD), y - thick - grow]);
  }
  // axis 'x' extrude takes [u = -z, v = y]
  return [...top, ...bot.reverse()].map(([z, y]) => [-z, y]);
}

async function build() {
  const root = createRoot('Hub_SummonShrine');
  const rf = rframe(root);

  const stone = mat('Stone', 0x6b7686);
  const white = mat('White', 0xffffff);
  const red = mat('Red', 0xe0453c);
  const gold = mat('Gold', 0xffc21a);
  const pink = mat('Pink', 0xff8fc0, { emissive: 0xff8fc0, emissiveIntensity: 0.25 });

  // Platform: dark stone lip, white upper tier, white front step.
  P('Tier1', slab(14, 0.8, 12, { r: 0.6, b: 0.22, seg: 2, bseg: 1 }), stone, rf, [0, 0, 0]);
  P('Tier2', slab(12.2, 0.8, 10.2, { r: 0.5, b: 0.2, seg: 2, bseg: 1 }), white, rf, [0, 0.6, 0]);
  // step: top 1.0 (below the gold trim top 1.3), front at z -5.9 (inside the stone tier's -6.0)
  P('Step', slab(4.4, 0.7, 1.4, { r: 0.25, b: 0.18, seg: 1, bseg: 1 }), white, rf, [0, 0.3, -5.2]);
  // gold trim band round the upper tier
  P('TierTrim', slab(12.36, 0.4, 10.36, { r: 0.52, b: 0.1, seg: 2, bseg: 1 }), gold, rf, [0, 0.9, 0]);

  // Pillars with gold base rings and capitals, gold brackets up into the roof.
  const PX = 4.6;
  const PZ = 3.6;
  for (const sx of [-1, 1])
    for (const sz of [-1, 1]) {
      const x = sx * PX;
      const z = sz * PZ;
      P(`Pillar${sx}${sz}`, disc(0.55, 8.2, { b: 0.08, seg: 3, bseg: 1 }), red, rf, [x, 1.3, z]);
      P(`Ring${sx}${sz}`, disc(0.78, 0.55, { b: 0.15, seg: 3, bseg: 1 }), gold, rf, [x, 1.35, z]);
      P(`Cap${sx}${sz}`, slab(1.5, 0.55, 1.5, { r: 0.2, b: 0.15, seg: 1, bseg: 1 }), gold, rf, [x, 9.0, z]);
      P(`Bracket${sx}${sz}`, slab(1.0, 0.75, 1.0, { r: 0.15, b: 0.12, seg: 1, bseg: 1 }), gold, rf, [x, 9.45, z]);
    }
  // Red tie beams joining the pillar tops.
  for (const sz of [-1, 1]) P(`BeamZ${sz}`, slab(9.6, 0.7, 0.7, { r: 0.15, b: 0.12, seg: 1, bseg: 1 }), red, rf, [0, 8.5, sz * PZ]);
  for (const sx of [-1, 1]) P(`BeamX${sx}`, slab(0.7, 0.7, 7.6, { r: 0.15, b: 0.12, seg: 1, bseg: 1 }), red, rf, [sx * PX, 8.5, 0]);

  // Pink banners hanging on the two front pillars.
  for (const sx of [-1, 1]) V(`Banner${sx}`, 0.9, 3.0, 0.4, pink, rf, sx * PX, 6.3, -PZ - 0.9, { r: 0.15, b: 0.1, seg: 1 });

  // Curved roof: red sweep extruded along X, gold gable-end caps (same profile
  // grown 0.15), gold eave trim, gold ridge beam, pink orbs on the ridge ends.
  const roof = await extrudeProfile(roofProfile(6.0, 9.95, 2.7, 0.6), { depth: 13.0, axis: 'x' });
  P('Roof', roof, red, rf, [0, 0, 0]);
  const gable = await extrudeProfile(roofProfile(6.0, 9.95, 2.7, 0.6, 0.15), { depth: 0.45, axis: 'x' });
  for (const sx of [-1, 1]) P(`Gable${sx}`, gable, gold, rf, [sx * 6.55, 0, 0]);
  for (const sz of [-1, 1]) P(`Eave${sz}`, slab(13.2, 0.5, 0.55, { r: 0.15, b: 0.12, seg: 1, bseg: 1 }), gold, rf, [0, 9.95, sz * 5.75]);
  P('RidgeBeam', slab(12.4, 0.7, 0.9, { r: 0.25, b: 0.2, seg: 2, bseg: 1 }), gold, rf, [0, 12.5, 0]);
  for (const sx of [-1, 1]) P(`Orb${sx}`, disc(0.55, 1.05, { b: 0.5, seg: 3, bseg: 2 }), pink, rf, [sx * 6.0, 12.9, 0]);

  // Pink lanterns hanging under the front eave corners.
  for (const sx of [-1, 1]) {
    const x = sx * 5.6;
    P(`LanCapT${sx}`, disc(0.35, 0.4, { b: 0.1, seg: 2, bseg: 1 }), gold, rf, [x, 9.5, -4.9]);
    P(`Lantern${sx}`, disc(0.58, 1.4, { b: 0.5, seg: 3, bseg: 2 }), pink, rf, [x, 8.2, -4.9]);
    P(`LanCapB${sx}`, disc(0.35, 0.4, { b: 0.1, seg: 2, bseg: 1 }), gold, rf, [x, 7.95, -4.9]);
  }

  // Altar: white plinth, gold top band, a standing scroll between gold
  // rollers, and a pink halo ring behind it.
  P('Altar', slab(3.2, 1.7, 2.4, { r: 0.3, b: 0.2, seg: 2, bseg: 1 }), white, rf, [0, 1.3, 0]);
  P('AltarTop', slab(3.6, 0.45, 2.8, { r: 0.3, b: 0.15, seg: 2, bseg: 1 }), gold, rf, [0, 2.95, 0]);
  V('Scroll', 2.6, 3.2, 0.4, white, rf, 0, 5.4, -0.2, { r: 0.08, b: 0.08, seg: 1 });
  for (const y of [3.8, 7.0]) P(`Roller${y}`, disc(0.32, 3.2, { b: 0.1, seg: 2, bseg: 1 }), gold, rf, [1.6, y, 0], [0, 0, 90]);
  P('Halo', torusGeo(2.35, 0.36, 6, 24), pink, rf, [0, 5.4, 0.55]);
  // a pink jewel floating above the scroll, the summon's focus
  P('Jewel', disc(0.5, 1.0, { b: 0.45, seg: 2, bseg: 2 }), pink, rf, [0, 7.6, 0]);

  return root;
}
