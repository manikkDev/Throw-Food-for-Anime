// Prop_hero_city_Shop: two-storey anime convenience store. Glass front, cyan/white striped awning,
// cyan storey band, gold shop sign, rooftop billboard frame (gold face left blank for a decal),
// cyan vending machine by the door.
// Target (Roblox studs, x/y/z): 18 x 16 x 12, standing on y = 0, front -Z.
// Kiln: width along Kiln Z, depth along Kiln X, shopfront faces +X.

const meta = { name: 'Prop_hero_city_Shop', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_Shop');

  const white = mat('WallWhite', 0xffffff);
  const cyan = mat('ZoneCyan', 0x35c9f0);
  const ink = mat('GlassInk', 0x0d0f2b);
  const dark = mat('StoneDark', 0x6b7686);
  const gold = mat('SignGold', 0xffc83d);

  const WH = [], CY = [], IN = [], DK = [], GD = [];
  const FX = 4.5; // shopfront plane (Kiln X)

  // darker base lip, two storeys, cyan storey band, dark parapet
  DK.push(M(await cbox(12.0, 0.6, 18.0, 0.25), dark, [0, 0.3, 0]));
  WH.push(M(await cbox(10.0, 6.4, 17.4, 0.3), white, [-0.5, 3.8, 0]));
  CY.push(M(await cbox(10.4, 0.9, 17.8, 0.25), cyan, [-0.5, 7.45, 0]));
  WH.push(M(await cbox(9.6, 4.9, 17.0, 0.3), white, [-0.6, 10.35, 0]));
  DK.push(M(await cbox(10.0, 0.6, 17.4, 0.2), dark, [-0.5, 13.1, 0]));

  // ground floor glass front with white mullions, glass door in the middle
  IN.push(M(await cbox(0.4, 4.2, 14.6, 0.15), ink, [FX, 3.1, 0]));
  for (const z of [-5.2, -1.7, 1.7, 5.2]) WH.push(M(await cbox(0.55, 4.2, 0.45, 0.1), white, [FX + 0.05, 3.1, z]));
  CY.push(M(await cbox(0.5, 0.35, 3.0, 0.1), cyan, [FX + 0.1, 5.0, 0]));
  // upper floor windows
  for (const z of [-5.6, 0, 5.6]) IN.push(M(await cbox(0.35, 2.4, 3.8, 0.15), ink, [FX - 0.3, 10.3, z]));
  // side windows
  for (const s of [-1, 1]) IN.push(M(await cbox(5.0, 2.4, 0.35, 0.15), ink, [-0.5, 10.3, s * 8.5]));
  // gold shop sign on the storey band
  GD.push(M(await cbox(0.45, 1.3, 9.0, 0.2), gold, [FX + 0.3, 7.45, 0]));

  // striped awning sloping out over the glass front, with a striped valance
  const n = 8, W = 15.6 / n;
  for (let i = 0; i < n; i++) {
    const z = -7.8 + W * (i + 0.5);
    const m = i % 2 ? white : cyan, arr = i % 2 ? WH : CY;
    arr.push(M(await cbox(2.2, 0.4, W, 0.1), m, [FX + 0.95, 5.9, z], [0, 0, -24]));
    arr.push(M(await cbox(0.4, 0.8, W, 0.1), m, [FX + 1.95, 5.2, z]));
  }

  // cyan vending machine by the door (anime street staple)
  CY.push(M(await cbox(1.4, 3.4, 1.7, 0.2), cyan, [FX + 0.8, 2.3, -8.0]));
  IN.push(M(await cbox(0.2, 1.6, 1.2, 0.08), ink, [FX + 1.5, 2.9, -8.0]));

  // rooftop billboard frame: dark legs and frame, gold face (blank)
  for (const z of [-5.5, 0, 5.5]) DK.push(M(await cbox(0.5, 1.2, 0.5, 0.12), dark, [-2.6, 13.9, z]));
  DK.push(M(await cbox(0.6, 2.8, 13.0, 0.2), dark, [-2.6, 15.8 - 1.4 - 0.2, 0]));
  GD.push(M(await cbox(0.3, 2.2, 12.2, 0.1), gold, [-2.2, 15.8 - 1.4 - 0.2, 0]));
  // rooftop AC units
  for (const z of [-6, 6]) DK.push(M(await cbox(1.6, 1.0, 1.4, 0.2), dark, [-4.4, 13.9, z]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'WallWhite', WH);
  await fuse(root, 'ZoneCyan', CY);
  await fuse(root, 'GlassInk', IN);
  await fuse(root, 'SignGold', GD);
  return finish(root);
}
