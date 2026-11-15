// Prop_samurai_castle_StoneWall: sloped stone wall section with a tiled cap.
// Target (Roblox studs, x/y/z): 24 x 9 x 5, standing on y = 0, front -Z.
// Kiln: the 24-stud length runs along Kiln Z, the 5-stud depth along Kiln X.
// Same battered-course stonework as the CastleKeep base, so the zone reads as one build.

const meta = { name: 'Prop_samurai_castle_StoneWall', category: 'prop' };

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

async function frustum(m, y, bx, bz, tx, h) {
  const R = Math.SQRT2;
  const g = await revolveProfile([[0, 0], [R, 0], [R * (tx / bx), h], [0, h]], { segments: 4 });
  g.rotateY(Math.PI / 4);
  return M(g, m, [0, y, 0], null, [bx, 1, bz]);
}

async function build() {
  const root = createRoot('Prop_samurai_castle_StoneWall');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const white = mat('PlasterWhite', 0xffffff);
  const red = mat('ZoneRed', 0xe0453c);

  const S = [], DK = [], WH = [], RD = [];

  // darker base lip
  DK.push(M(await cbox(5.0, 0.8, 24.0, 0.25), dark, [0, 0.4, 0]));
  // two battered stone courses with a ledge between them
  S.push(await frustum(stone, 0.8, 2.35, 11.8, 1.95, 2.4));
  S.push(await frustum(stone, 3.2, 1.9, 11.6, 1.5, 2.4));
  // big stone blocks proud of the front and back slopes (reads as masonry, not a box)
  const blk = await cbox(0.7, 1.0, 2.6, 0.2);
  for (const s of [-1, 1]) {
    for (let i = 0; i < 6; i++) {
      const z = -9.5 + i * 3.8;
      S.push(M(blk, stone, [s * 2.05, 2.0, z + 1.0], [0, 0, s * 9]));
      S.push(M(blk, stone, [s * 1.62, 4.4, z - 0.6], [0, 0, s * 9]));
    }
  }
  // white plaster wall on top, with dark loopholes
  WH.push(M(await cbox(2.4, 2.2, 22.6, 0.25), white, [0, 6.7, 0]));
  for (let i = 0; i < 5; i++) {
    const z = -8.8 + i * 4.4;
    for (const s of [-1, 1]) DK.push(M(await cbox(0.4, 0.8, 0.8, 0.15), dark, [s * 1.15, 6.6, z], [i % 2 ? 45 : 0, 0, 0]));
  }
  // red beam band under the cap (zone trim)
  RD.push(M(await cbox(2.8, 0.6, 23.0, 0.2), red, [0, 7.55, 0]));
  // tiled cap: gable section along the wall, with raised tile ribs
  const cap = await extrudeProfile([[-2.45, 0], [2.45, 0], [2.45, 0.35], [0.35, 1.05], [-0.35, 1.05], [-2.45, 0.35]], { depth: 24.0, axis: 'z', bevel: 0.1, bevelStyle: 'chamfer' });
  DK.push(M(cap, dark, [0, 8.05, 0]));
  const rib = await extrudeProfile([[-2.5, 0.25], [-2.5, 0.55], [-0.3, 1.25], [0.3, 1.25], [2.5, 0.55], [2.5, 0.25], [0.3, 0.95], [-0.3, 0.95]], { depth: 0.5, axis: 'z' });
  for (let i = 0; i < 10; i++) DK.push(M(rib, dark, [0, 8.05, -10.8 + i * 2.4]));
  // red ridge cap (zone trim visible from above and far away)
  RD.push(M(await cbox(1.1, 0.55, 24.0, 0.2), red, [0, 9.2, 0]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'PlasterWhite', WH);
  await fuse(root, 'ZoneRed', RD);
  return finish(root);
}
