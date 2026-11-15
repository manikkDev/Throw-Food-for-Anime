// Equip_stone_pillar: gear tier 4. Target [5, 9, 5].
// "cracked stone pillar wrapped in a thick rope with paper tags"
const meta = { name: 'Equip_stone_pillar', category: 'prop' };

// ---- shared header (synced into every gear/food program by sync_header.mjs) ----
// Authored in the ROBLOX frame: studs, +Y up, FRONT = -Z. The RobloxFrame group
// is turned -90 deg about Y so kiln_to_roblox.mjs's +90 deg turn cancels it.
// Convert with: kiln_to_roblox.mjs in.glb out.glb --studs-per-m 1
const hexName = (h) => h.toString(16).toUpperCase().padStart(6, '0');
function mat(label, hex, opts = {}) {
  const m = gameMaterial(hex, { roughness: 0.85, metalness: 0, flatShading: false, ...opts });
  m.name = `${label}_${hexName(hex)}`;
  return m;
}
function frame(name) {
  const root = createRoot(name);
  const f = new THREE.Group();
  f.name = 'RobloxFrame';
  f.rotation.y = -Math.PI / 2;
  root.add(f);
  return { root, f };
}
function group(name, parent, pos = [0, 0, 0], rotDeg = [0, 0, 0]) {
  const g = new THREE.Group();
  g.name = name;
  g.position.set(...pos);
  g.rotation.set(...rotDeg.map((d) => (d * Math.PI) / 180));
  parent.add(g);
  return g;
}
// Rings of points -> closed solid. rings[k] is an array of [x,y,z]; all rings
// have the same count, wound so that consecutive rings + the index order make
// outward faces (see turn/pillow). Ends are closed with fans to a centre point.
function skin(rings, capLo, capHi, crease) {
  const pos = [];
  const idx = [];
  const n = rings[0].length;
  const starts = rings.map((r) => {
    const s = pos.length / 3;
    for (const p of r) pos.push(...p);
    return s;
  });
  for (let k = 0; k < starts.length - 1; k++) {
    const a = starts[k], b = starts[k + 1];
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      idx.push(a + i, a + j, b + j, a + i, b + j, b + i);
    }
  }
  const cb = pos.length / 3;
  pos.push(...capLo);
  const ct = pos.length / 3;
  pos.push(...capHi);
  const r0 = starts[0], r1 = starts[starts.length - 1];
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    idx.push(cb, r0 + j, r0 + i, ct, r1 + i, r1 + j);
  }
  return creaseNormals(meshGeo({ positions: pos, indices: idx }).toNonIndexed(), { angle: crease });
}
// Solid of revolution about +Y from [radius, y] stations listed bottom to top.
// (Kiln's lathe closed onto the axis leaves zero-area faces whose zero normals
// fail export QA, so the ends are fans.) Facets under `crease` deg shade smooth.
function turn(pts, seg = 12, crease = 40, yLo = null, yHi = null) {
  const rings = pts.map(([r, y]) => {
    const ring = [];
    for (let i = 0; i < seg; i++) {
      const a = (2 * Math.PI * i) / seg;
      ring.push([r * Math.cos(a), y, -r * Math.sin(a)]);
    }
    return ring;
  });
  return skin(rings, [0, yLo ?? pts[0][1], 0], [0, yHi ?? pts[pts.length - 1][1], 0], crease);
}
// Chamfered cylinder along Y, centred on the origin.
function ccyl(r, h, c, seg = 12) {
  return turn([[r - c, -h / 2], [r, -h / 2 + c], [r, h / 2 - c], [r - c, h / 2]], seg);
}
// Rounded ball: a turned profile, so poles are fans (no zero normals).
function ball(r, seg = 10, rows = 6, crease = 80) {
  const pts = [];
  for (let k = 1; k < rows; k++) {
    const t = -Math.PI / 2 + (Math.PI * k) / rows;
    pts.push([r * Math.cos(t), r * Math.sin(t)]);
  }
  return turn(pts, seg, crease, -r, r);
}
// Convex outline (CCW in XY) hugging equal circles of radius r round `centres`
// (listed CCW). `per` points per corner arc.
function roundedOutline(centres, r, per = 4) {
  const n = centres.length;
  const nrm = (p, q) => {
    const dx = q[0] - p[0], dy = q[1] - p[1], l = Math.hypot(dx, dy);
    return Math.atan2(-dx / l, dy / l);
  };
  const out = [];
  for (let i = 0; i < n; i++) {
    const prev = centres[(i - 1 + n) % n], c = centres[i], next = centres[(i + 1) % n];
    let a0 = nrm(prev, c), a1 = nrm(c, next);
    while (a1 < a0) a1 += 2 * Math.PI;
    for (let k = 0; k <= per; k++) {
      const a = a0 + ((a1 - a0) * k) / per;
      out.push([c[0] + r * Math.cos(a), c[1] + r * Math.sin(a)]);
    }
  }
  return out;
}
// Outline (CCW in XY) lofted along Z through [z, inset, scale?] stations,
// back to front, each station the outline pulled in by `inset` along its
// vertex normals. Caps are fans to the outline centroid at capZ (lets a face
// bulge). Gives puffy rounded-edge solids: rice balls, buns, cushions, stars.
function pillow(outline, stations, crease = 50, capBulge = 0) {
  const n = outline.length;
  const cx = outline.reduce((s, p) => s + p[0], 0) / n, cy = outline.reduce((s, p) => s + p[1], 0) / n;
  const vn = outline.map((p, i) => {
    const a = outline[(i - 1 + n) % n], b = outline[(i + 1) % n];
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy);
    return [dy / l, -dx / l];
  });
  const rings = stations.map(([z, inset, s = 1]) => outline.map((p, i) => [cx + (p[0] - cx) * s - vn[i][0] * inset, cy + (p[1] - cy) * s - vn[i][1] * inset, z]));
  const z0 = stations[0][0], z1 = stations[stations.length - 1][0];
  return skin(rings, [cx, cy, z0 - capBulge], [cx, cy, z1 + capBulge], crease);
}
// Star outline (CCW), points up.
function starOutline(points, R, r) {
  const out = [];
  for (let i = 0; i < points * 2; i++) {
    const a = Math.PI / 2 + (Math.PI * i) / points;
    const rr = i % 2 ? r : R;
    out.push([rr * Math.cos(a), rr * Math.sin(a)]);
  }
  return out;
}
// Tube of radius `r` (or [r per station]) along a polyline path, closed caps.
function tube(path, r, seg = 8, crease = 60) {
  const rs = Array.isArray(r) ? r : path.map(() => r);
  const V = (a) => new THREE.Vector3(...a);
  const P = path.map(V);
  let up = new THREE.Vector3(0, 1, 0);
  const t0 = P[1].clone().sub(P[0]).normalize();
  if (Math.abs(t0.dot(up)) > 0.9) up = new THREE.Vector3(1, 0, 0);
  let nrm = up.clone().sub(t0.clone().multiplyScalar(up.dot(t0))).normalize();
  const rings = [];
  let prevT = t0;
  for (let k = 0; k < P.length; k++) {
    const t = (k === 0 ? P[1].clone().sub(P[0]) : k === P.length - 1 ? P[k].clone().sub(P[k - 1]) : P[k + 1].clone().sub(P[k - 1])).normalize();
    // parallel transport of the normal
    const q = new THREE.Quaternion().setFromUnitVectors(prevT, t);
    nrm.applyQuaternion(q).normalize();
    prevT = t;
    const bin = t.clone().cross(nrm).normalize();
    const ring = [];
    for (let i = 0; i < seg; i++) {
      const a = (2 * Math.PI * i) / seg;
      // order chosen so skin() winds outward (path runs low -> high ring index)
      const d = nrm.clone().multiplyScalar(Math.cos(a)).add(bin.clone().multiplyScalar(Math.sin(a)));
      ring.push(P[k].clone().add(d.multiplyScalar(rs[k])).toArray());
    }
    rings.push(ring);
  }
  return skin(rings, P[0].toArray(), P[P.length - 1].toArray(), crease);
}
function part(name, geo, m, parent, pos = [0, 0, 0], rot = [0, 0, 0], scale = [1, 1, 1]) {
  return createPart(name, geo, m, { position: pos, rotation: rot, scale, parent });
}
// Gear: stand on y = 0, centred on x and z. Food: centred on its own centre.
function settle(root, mode) {
  root.updateMatrixWorld(true);
  const b = new THREE.Box3().setFromObject(root, true);
  const c = b.getCenter(new THREE.Vector3());
  root.position.set(-c.x, mode === 'ground' ? -b.min.y : -c.y, -c.z);
  root.updateMatrixWorld(true);
}
// ---- end shared header ----

async function build() {
  const { root, f } = frame('Equip_stone_pillar');
  const dark = mat('DarkStone', 0x6b7686);
  const stone = mat('Stone', 0x9aa4b2);
  const rope = mat('Rope', 0xf4d58a);
  const paper = mat('Paper', 0xffffff);
  const glow = mat('CrackGlow', 0xffa21f, { emissive: 0xffa21f, emissiveIntensity: 0.6 });
  // Octagonal stepped base (dark lip) and column, chamfered.
  part('Base', turn([[2.3, 0], [2.5, 0.2], [2.5, 0.55], [2.2, 0.8], [1.9, 0.85], [1.85, 1.1]], 8, 20), dark, f, [0, 0, 0], [0, 22.5, 0]);
  part('Column', turn([[1.55, 1.0], [1.5, 4.5], [1.42, 7.6]], 8, 20), stone, f, [0, 0, 0], [0, 22.5, 0]);
  part('Cap', turn([[1.5, 7.5], [1.9, 7.7], [1.95, 8.3], [1.75, 8.55], [1.2, 8.7]], 8, 20), dark, f, [0, 0, 0], [0, 22.5, 0]);
  // Glowing cracks: zigzag tubes half sunk into the faces.
  const crack = (a, y0, y1, w) => {
    const pts = [];
    for (let i = 0; i <= 5; i++) {
      const y = y0 + ((y1 - y0) * i) / 5;
      const aa = a + (i % 2 ? w : -w);
      pts.push([1.47 * Math.cos(aa), y, 1.47 * Math.sin(aa)]);
    }
    return tube(pts, 0.17, 6, 60);
  };
  part('Crack1', crack(-Math.PI / 2 + 0.25, 1.4, 4.4, 0.18), glow, f);
  part('Crack2', crack(-Math.PI / 2 - 0.5, 6.2, 7.4, 0.14), glow, f);
  part('Crack3', crack(Math.PI / 2 + 0.3, 1.6, 4.0, 0.16), glow, f);
  // Thick shimenawa rope: two twisted strands round the column.
  for (const ph of [0, Math.PI]) {
    const pts = [];
    for (let i = 0; i <= 24; i++) {
      const a = (i / 24) * Math.PI * 2;
      pts.push([1.78 * Math.cos(a), 5.6 + 0.16 * Math.sin(a * 6 + ph), 1.78 * Math.sin(a)]);
    }
    part('Rope', tube(pts, 0.32, 7, 60), rope, f);
  }
  part('RopeKnot', ball(0.5, 10, 6), rope, f, [0, 5.6, -1.85], [0, 0, 0], [1.2, 0.9, 0.7]);
  // Zigzag paper tags hanging from the rope.
  for (const a of [-Math.PI / 2 - 0.75, -Math.PI / 2 + 0.75, 0, Math.PI, Math.PI / 2]) {
    const rr = 1.5;
    const tag = group('Tag', f, [rr * Math.cos(a), 5.05, rr * Math.sin(a)], [0, 90 - (a * 180) / Math.PI, 0]);
    const g = await roundedBoxGeo(0.55, 0.52, 0.22, 0.07, { segments: 1 });
    [[0, 0], [0.18, -0.46], [0, -0.92], [0.18, -1.38]].forEach(([dx, dy], i) => part('TagStep', g, paper, tag, [dx - 0.09, dy, 0.03 * i], [0, 0, i % 2 ? -6 : 6]));
  }
  settle(root, 'ground');
  return root;
}
