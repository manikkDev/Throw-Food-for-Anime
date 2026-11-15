// Prop_hero_city_NeonTower: skyscraper with cyan neon bands and a rooftop antenna.
// The hero_city zone landmark.
// Target (Roblox studs, x/y/z): 16 x 48 x 16, standing on y = 0, front -Z.

const meta = { name: 'Prop_hero_city_NeonTower', category: 'prop' };

// UNITS: authored in STUDS, converted with `kiln_to_roblox.mjs --studs-per-m 1`.
// Kiln frame: +X forward (becomes Roblox -Z, the front), +Y up, +Z right (becomes Roblox +X).
// So a Roblox size [sx, sy, sz] is Kiln extent Z = sx, Y = sy, X = sz.
// Each colour is unioned into ONE closed mesh (bible: one clean piece per colour),
// and the material name carries the hex the converter names the MeshPart after.

function mat(label, hex) {
  const m = gameMaterial(hex, { roughness: 0.8 });
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
const D = Math.PI / 180;
// raw mesh operand: position, Euler XYZ degrees, scale
function M(geo, m, pos, rot, scl) {
  const o = new THREE.Mesh(geo, m);
  o.position.set(pos[0], pos[1], pos[2]);
  if (rot) o.rotation.set(rot[0] * D, rot[1] * D, rot[2] * D);
  if (scl) o.scale.set(scl[0], scl[1], scl[2]);
  o.updateMatrixWorld(true);
  return o;
}
// chamfered box (bible: 0.15-0.3 stud chamfers, never razor-sharp)
async function cbox(w, h, d, r) {
  return roundedBoxGeo(w, h, d, Math.min(r === undefined ? 0.25 : r, Math.min(w, h, d) * 0.45), { style: 'chamfer' });
}
// faceted low-poly lobe / gem
function ico(detail) {
  return mergeVertices(new THREE.IcosahedronGeometry(1, detail || 0), { positionOnly: true });
}
function octa() {
  return mergeVertices(new THREE.OctahedronGeometry(1, 0), { positionOnly: true });
}
async function fuse(root, name, parts) {
  if (parts.length === 1) { parts[0].name = name; root.add(parts[0]); return; }
  const u = await boolUnion(name, ...parts);
  root.add(u);
}
function finish(root) {
  // centre on x and z, stand on y = 0 (the converter does not re-centre).
  // Manual bounds: THREE.Box3.setFromObject is rejected by the Kiln sandbox.
  root.updateMatrixWorld(true);
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const ch of root.children) {
    const pos = ch.geometry.attributes.position, e = ch.matrixWorld.elements;
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
      const w = [e[0] * x + e[4] * y + e[8] * z + e[12], e[1] * x + e[5] * y + e[9] * z + e[13], e[2] * x + e[6] * y + e[10] * z + e[14]];
      for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], w[k]); hi[k] = Math.max(hi[k], w[k]); }
    }
  }
  const cx = (lo[0] + hi[0]) / 2, cz = (lo[2] + hi[2]) / 2;
  for (const ch of root.children) { ch.position.x -= cx; ch.position.z -= cz; ch.position.y -= lo[1]; }
  root.updateMatrixWorld(true);
  return root;
}

async function build() {
  const root = createRoot('Prop_hero_city_NeonTower');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const ink = mat('GlassInk', 0x0d0f2b);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], IN = [], CY = [], GD = [];

  // --- darker base lip ----------------------------------------------------
  DK.push(M(await cbox(16, 1.0, 16, 0.3), dark, [0, 0.5, 0]));

  // --- three setback sections: light stone corner piers + ink glass core ---
  // [y0, y1, size, pier]
  const secs = [
    [1.0, 21.0, 15.0, 2.6],
    [22.0, 35.0, 11.6, 2.2],
    [36.0, 42.0, 8.4, 1.8],
  ];
  for (let si = 0; si < secs.length; si++) {
    const [y0, y1, w, pw] = secs[si];
    const h = y1 - y0, yc = (y0 + y1) / 2;
    IN.push(M(await cbox(w - 1.0, h, w - 1.0, 0.3), ink, [0, yc, 0]));
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      S.push(M(await cbox(pw, h, pw, 0.3), stone, [sx * (w - pw) / 2, yc, sz * (w - pw) / 2]));
      // vertical neon strip on the outer corner of each pier, sections 1 and 2
      if (si < 2) CY.push(M(await cbox(0.6, h - 1.2, 0.6, 0.15), cyan, [sx * (w / 2 + 0.05), yc, sz * (w / 2 + 0.05)], [0, 45, 0]));
    }
    // floor bands: light stone spandrels every ~4 studs, proud of the glass
    const nb = Math.floor(h / 4);
    for (let b = 1; b <= nb; b++) {
      const y = y0 + (h / (nb + 1)) * b;
      S.push(M(await cbox(w - 0.6, 0.6, w - 0.6, 0.2), stone, [0, y, 0]));
    }
    // cyan neon band capping the section
    CY.push(M(await cbox(w + 0.6, 1.0, w + 0.6, 0.3), cyan, [0, y1 + 0.5, 0]));
  }
  // roof cap and antenna
  DK.push(M(await cbox(7.0, 1.2, 7.0, 0.3), dark, [0, 43.6, 0]));
  DK.push(M(cylinderGeo(1.0, 1.3, 1.2, 8), dark, [0, 44.8, 0]));
  DK.push(M(cylinderGeo(0.35, 0.45, 2.6, 6), dark, [0, 46.6, 0]));
  CY.push(M(cylinderGeo(0.6, 0.6, 0.5, 8), cyan, [0, 46.0, 0]));
  GD.push(M(ico(1), gold, [0, 47.45, 0], null, [0.55, 0.55, 0.55]));

  // --- street level: front door (ink) with cyan canopy and gold sign ------
  IN.push(M(await cbox(0.8, 3.6, 3.6, 0.2), ink, [7.4, 2.8, 0]));
  CY.push(M(await cbox(1.8, 0.5, 5.0, 0.2), cyan, [7.5, 4.9, 0]));
  GD.push(M(await cbox(0.5, 0.9, 3.0, 0.2), gold, [7.6, 6.0, 0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'GlassInk', IN);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
