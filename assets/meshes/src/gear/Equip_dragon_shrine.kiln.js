// Equip_dragon_shrine: gear tier 7. Target [9, 13, 9].
// "red and gold shrine with a coiled dragon on the roof and two flame bowls"
const meta = { name: 'Equip_dragon_shrine', category: 'prop' };

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
  const { root, f } = frame('Equip_dragon_shrine');
  const red = mat('Red', 0xe0453c);
  const gold = mat('Gold', 0xffc83d);
  const dark = mat('DarkStone', 0x6b7686);
  const stone = mat('Stone', 0x9aa4b2);
  const jade = mat('Dragon', 0x3fbf6a);
  // Two stone steps (dark lip, lighter top).
  part('Step1', await roundedBoxGeo(8.6, 0.6, 8.6, 0.2, { segments: 2 }), dark, f, [0, 0.3, 0]);
  part('Step2', await roundedBoxGeo(7.4, 0.6, 7.4, 0.2, { segments: 2 }), stone, f, [0, 0.9, 0]);
  // Four fat red pillars, gold feet and capitals.
  for (const x of [-2.75, 2.75]) {
    for (const z of [-2.75, 2.75]) {
      part('Pillar', ccyl(0.48, 6.0, 0.08, 10), red, f, [x, 4.2, z]);
      part('Foot', ccyl(0.68, 0.45, 0.12, 10), gold, f, [x, 1.42, z]);
      part('Capital', ccyl(0.66, 0.45, 0.12, 10), gold, f, [x, 7.05, z]);
    }
  }
  // Gold beams tying the pillar tops.
  for (const s of [-1, 1]) {
    part('BeamX', await roundedBoxGeo(6.4, 0.55, 0.6, 0.15, { segments: 2 }), gold, f, [0, 7.5, s * 2.75]);
    part('BeamZ', await roundedBoxGeo(0.6, 0.55, 6.4, 0.15, { segments: 2 }), gold, f, [s * 2.75, 7.5, 0]);
  }
  // Curved square roof (turn with 4 segments = square), upswept gold eave, red top.
  const roof = [[6.0, 7.75], [6.45, 8.25], [5.2, 8.55], [3.7, 9.15], [2.4, 9.85], [1.4, 10.4]];
  part('Roof', turn(roof, 4, 20, 7.7, 10.5), red, f, [0, 0, 0], [0, 45, 0]);
  part('Eave', turn([[5.9, 7.65], [6.55, 8.15], [6.45, 8.4], [5.6, 8.2]], 4, 20), gold, f, [0, 0, 0], [0, 45, 0]);
  part('RoofCap', ccyl(1.0, 0.5, 0.15, 8), gold, f, [0, 10.55, 0]);
  // Coiled jade dragon round a gold spire, head facing the front (-Z).
  part('Spire', ccyl(0.35, 1.6, 0.1, 8), gold, f, [0, 11.4, 0]);
  const coil = [];
  for (let i = 0; i <= 16; i++) {
    const t = i / 16;
    const a = Math.PI / 2 + t * Math.PI * 2.5; // starts at the back, ends at the front
    const r = 1.15 - 0.35 * t;
    coil.push([r * Math.cos(a), 10.75 + t * 1.45, r * Math.sin(a)]);
  }
  const rad = coil.map((_, i) => 0.42 - 0.1 * Math.abs(i / 16 - 0.6));
  rad[0] = 0.2;
  part('Coil', tube(coil, rad, 8, 55), jade, f);
  const head = coil[coil.length - 1];
  part('Head', ball(0.55, 10, 6), jade, f, [head[0], head[1] + 0.25, head[2] - 0.2], [0, 0, 0], [1, 0.85, 1.25]);
  part('Snout', await roundedBoxGeo(0.6, 0.4, 0.55, 0.14, { segments: 1 }), jade, f, [head[0], head[1] + 0.12, head[2] - 0.75]);
  for (const s of [-1, 1]) {
    part('Horn', tube([[head[0] + s * 0.25, head[1] + 0.55, head[2] - 0.05], [head[0] + s * 0.45, head[1] + 0.95, head[2] + 0.35]], [0.13, 0.07], 6), gold, f);
    part('Eye', ball(0.11, 6, 4), gold, f, [head[0] + s * 0.3, head[1] + 0.38, head[2] - 0.6]);
  }
  // Two flame bowls flanking the front steps.
  for (const s of [-1, 1]) {
    part('BowlPost', ccyl(0.3, 1.2, 0.08, 8), dark, f, [s * 3.6, 1.8, -3.6]);
    part('Bowl', turn([[0.3, 2.3], [0.75, 2.45], [0.85, 2.8], [0.7, 2.85]], 10, 40), gold, f, [s * 3.6, 0, -3.6]);
    const flame = [[0.4, 0], [0.5, 0.25], [0.42, 0.6], [0.22, 1.0], [0.06, 1.3]];
    part('Flame', turn(flame, 10, 70, 0, 1.4), red, f, [s * 3.6, 2.55, -3.6], [0, 0, s * 8], [1.5, 1.6, 1.5]);
    part('FlameCore', turn(flame, 8, 70, 0, 1.4), gold, f, [s * 3.6, 2.6, -4.05], [0, 0, s * 8], [0.95, 1.05, 0.95]);
  }
  settle(root, 'ground');
  return root;
}
