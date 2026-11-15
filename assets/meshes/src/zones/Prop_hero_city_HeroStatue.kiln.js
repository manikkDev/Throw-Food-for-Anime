// Prop_hero_city_HeroStatue: caped hero statue on a plinth, bronze with a cyan plaque.
// Target (Roblox studs, x/y/z): 8 x 16 x 8, standing on y = 0, front -Z.
// Bronze #CD7F32 is outside the bible's material palette list; the kit entry asks for bronze.
// The hero faces +X (Roblox -Z), right fist raised, left hand on hip, cape behind.

const meta = { name: 'Prop_hero_city_HeroStatue', category: 'prop' };

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
  const root = createRoot('Prop_hero_city_HeroStatue');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const bronze = mat('Bronze', 0xcd7f32);
  const cyan = mat('ZoneCyan', 0x35c9f0);

  const S = [], DK = [], BZ = [], CY = [];

  // plinth: dark lip, light body, light cap
  DK.push(M(await cbox(8, 0.8, 8, 0.3), dark, [0, 0.4, 0]));
  S.push(M(await cbox(6.8, 4.4, 6.8, 0.3), stone, [0, 3.0, 0]));
  S.push(M(await cbox(7.4, 0.7, 7.4, 0.25), stone, [0, 5.55, 0]));
  DK.push(M(await cbox(7.0, 0.4, 7.0, 0.15), dark, [0, 5.0, 0]));
  // cyan plaque on the front, and cyan band on the back
  CY.push(M(await cbox(0.4, 1.8, 4.2, 0.15), cyan, [3.45, 3.0, 0]));

  // ---- the figure (bronze), feet on y = 5.9 ----
  const Y = 5.9;
  for (const s of [-1, 1]) {
    BZ.push(M(await cbox(1.6, 0.8, 1.05, 0.25), bronze, [0.25, Y + 0.4, s * 1.05]));                 // boot
    BZ.push(M(cylinderGeo(0.5, 0.62, 3.6, 8), bronze, [0, Y + 2.3, s * 0.82], [s * 7, 0, 0]));          // leg
  }
  BZ.push(M(await cbox(1.7, 1.0, 2.4, 0.3), bronze, [0, Y + 4.1, 0]));                                 // hips
  BZ.push(M(await cbox(1.9, 2.6, 2.9, 0.45), bronze, [0, Y + 5.7, 0]));                                // chest
  BZ.push(M(cylinderGeo(0.4, 0.45, 0.6, 8), bronze, [0, Y + 7.2, 0]));                                 // neck
  BZ.push(M(ico(1), bronze, [0.05, Y + 8.2, 0], null, [0.95, 1.05, 0.95]));                            // head
  // right arm raised (Kiln -Z side is Roblox -x; keep it on +Z = Roblox +x)
  BZ.push(M(ico(1), bronze, [0, Y + 6.8, 1.65], null, [0.62, 0.62, 0.62]));                            // shoulder
  BZ.push(M(cylinderGeo(0.42, 0.48, 3.0, 8), bronze, [0, Y + 8.2, 1.95], [-10, 0, 0]));               // arm up
  BZ.push(M(ico(1), bronze, [0, Y + 9.75, 2.2], null, [0.62, 0.66, 0.62]));                            // fist
  // left arm bent, fist on hip
  BZ.push(M(ico(1), bronze, [0, Y + 6.8, -1.65], null, [0.62, 0.62, 0.62]));
  BZ.push(M(cylinderGeo(0.42, 0.45, 1.9, 8), bronze, [0, Y + 6.0, -2.15], [-28, 0, 0]));              // upper arm, out
  BZ.push(M(cylinderGeo(0.42, 0.42, 1.7, 8), bronze, [0, Y + 4.7, -1.95], [52, 0, 0]));               // forearm, in
  // cape: flared sheet behind the body, bottom swept back
  const cape = [[-1.5, 0], [1.5, 0], [2.3, -4.6], [1.2, -5.2], [0, -4.8], [-1.2, -5.2], [-2.3, -4.6]];
  BZ.push(M(await extrudeProfile(cape.map(([z, y]) => [-z, y]), { depth: 0.5, axis: 'x', bevel: 0.15, bevelStyle: 'chamfer' }), bronze, [-1.2, Y + 7.0, 0], [0, 0, -14]));
  // cyan chest emblem (zone trim)
  CY.push(M(await cbox(0.4, 0.9, 0.9, 0.12), cyan, [0.95, Y + 6.0, 0], [45, 0, 0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'Bronze', BZ);
  await fuse(root, 'ZoneCyan', CY);
  return finish(root);
}
