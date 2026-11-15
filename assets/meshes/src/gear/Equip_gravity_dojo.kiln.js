// Equip_gravity_dojo: gear tier 6. Target [9, 10, 9].
// "sci-fi gravity chamber: round platform, three curved pylons, purple energy rings"
const meta = { name: 'Equip_gravity_dojo', category: 'prop' };

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
  const { root, f } = frame('Equip_gravity_dojo');
  const steel = mat('Steel', 0x6b7686);
  const white = mat('White', 0xe8eef5);
  const purple = mat('Purple', 0xa66bff, { emissive: 0xa66bff, emissiveIntensity: 0.5 });
  const glow = mat('Glow', 0xe2ccff, { emissive: 0xe2ccff, emissiveIntensity: 0.7 });
  const ink = mat('Ink', 0x0d0f2b);
  // Platform: dark steel lip, white deck, purple inlay ring and a glowing centre pad.
  part('Base', turn([[4.3, 0], [4.5, 0.2], [4.5, 0.6], [4.2, 0.8], [3.9, 0.85]], 24, 35), steel, f);
  part('Deck', turn([[3.95, 0.8], [3.95, 1.05], [3.8, 1.2], [0.5, 1.2]], 24, 35), white, f);
  const ring = (R, y, tube_r, n = 24, tilt = 0) => {
    const pts = [];
    for (let i = 0; i <= n; i++) {
      const a = (i / n) * Math.PI * 2;
      const z = R * Math.sin(a);
      pts.push([R * Math.cos(a), y + Math.sin((tilt * Math.PI) / 180) * z, z * Math.cos((tilt * Math.PI) / 180)]);
    }
    return tube(pts, tube_r, 6, 70);
  };
  part('Inlay', ring(3.2, 1.22, 0.16, 24), purple, f);
  part('Pad', ccyl(1.6, 0.16, 0.05, 20), glow, f, [0, 1.25, 0]);
  part('PadRim', ring(1.75, 1.3, 0.14, 20), ink, f);
  // Three curved pylons rising from the rim and arching inward, purple tips.
  for (let k = 0; k < 3; k++) {
    const a = (k / 3) * Math.PI * 2 + Math.PI / 2; // one pylon at the back (+Z), two front corners
    const c = Math.cos(a), s = Math.sin(a);
    const prof = [[3.85, 0.7], [4.05, 2.4], [4.0, 4.5], [3.7, 6.6], [3.1, 8.3], [2.4, 9.3]];
    part('Pylon' + k, tube(prof.map(([r, y]) => [r * c, y, r * s]), [0.55, 0.5, 0.46, 0.42, 0.38, 0.33], 8, 45), white, f);
    part('PylonFoot', await roundedBoxGeo(1.3, 0.9, 1.3, 0.2, { segments: 2 }), steel, f, [3.95 * c, 0.9, 3.95 * s], [0, -(a * 180) / Math.PI, 0]);
    part('PylonBand', ccyl(0.62, 0.35, 0.08, 8), purple, f, [4.03 * c, 3.2, 4.03 * s]);
    part('PylonTip', ball(0.45, 10, 6), purple, f, [2.3 * c, 9.45, 2.3 * s]);
  }
  // Floating purple energy rings, slightly tilted.
  part('Ring1', ring(3.0, 3.6, 0.22, 28, 6), purple, f);
  part('Ring2', ring(2.6, 5.7, 0.22, 28, -8), purple, f);
  part('Ring3', ring(2.1, 7.6, 0.2, 24, 10), purple, f);
  settle(root, 'ground');
  return root;
}
