// Prop_samurai_castle_CastleKeep: three-tier castle keep, white walls, red curved roofs,
// gold fish ornaments. The samurai_castle zone landmark.
// Target (Roblox studs, x/y/z): 36 x 44 x 30, standing on y = 0, front -Z.
// Kiln: width (Roblox x) runs along Kiln Z, depth (Roblox z) along Kiln X, front +X.

const meta = { name: 'Prop_samurai_castle_CastleKeep', category: 'prop' };

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

// Flared hip roof: a 4-segment revolve (a pyramid) rotated 45 deg, scaled to a rectangle.
// halfX/halfZ = eave half extents (Kiln X = depth, Kiln Z = width). topRatio = top/eave.
async function hipRoof(m, y, halfX, halfZ, h, topRatio, thick) {
  const R = Math.SQRT2;
  const prof = [[0, 0], [R, 0], [R, thick]];
  for (const f of [0.2, 0.45, 0.72]) prof.push([R * (1 - (1 - topRatio) * Math.pow(f, 0.55)), thick + h * f]);
  prof.push([R * topRatio, thick + h], [0, thick + h]);
  const g = await revolveProfile(prof, { segments: 4 });
  g.rotateY(Math.PI / 4);
  return M(g, m, [0, y, 0], null, [halfX, 1, halfZ]);
}
// battered stone course: straight-sided frustum, same trick
async function frustum(m, y, bx, bz, tx, tz, h) {
  const R = Math.SQRT2;
  const g = await revolveProfile([[0, 0], [R, 0], [R * (tx / bx), h], [0, h]], { segments: 4 });
  g.rotateY(Math.PI / 4);
  // one taper ratio for both axes (tx/bx); tz is documentation only
  return M(g, m, [0, y, 0], null, [bx, 1, bz]);
}

async function build() {
  const root = createRoot('Prop_samurai_castle_CastleKeep');

  const stone = mat('StoneLight', 0x9aa4b2);
  const dark = mat('StoneDark', 0x6b7686);
  const white = mat('PlasterWhite', 0xffffff);
  const red = mat('ZoneRed', 0xe0453c);
  const gold = mat('Gold', 0xffc83d);

  const S = [], DK = [], WH = [], RD = [], GD = [];

  // --- darker base lip --------------------------------------------------
  DK.push(M(await cbox(30, 1.0, 36, 0.3), dark, [0, 0.5, 0]));

  // --- battered stone base in three courses (ledges read as stonework) ----
  // [y, bottom half X, bottom half Z, top half X, top half Z, h]
  const courses = [
    [1.0, 14.4, 17.4, 13.6, 16.6, 3.0],
    [4.0, 13.4, 16.4, 12.6, 15.6, 3.0],
    [7.0, 12.4, 15.4, 11.6, 14.6, 3.0],
  ];
  for (const [y, bx, bz, tx, tz, h] of courses) S.push(await frustum(stone, y, bx, bz, tx, tz, h));
  // dark cap course on top of the stone, under the white walls
  DK.push(M(await cbox(23.6, 0.8, 29.6, 0.25), dark, [0, 10.2, 0]));

  // --- tier walls (white) and roofs (red) --------------------------------
  // tier: [wallY0, wallH, depth(X), width(Z)]
  const tiers = [
    [10.4, 6.4, 20, 25],
    [19.6, 5.6, 15, 19],
    [27.6, 5.0, 10, 13],
  ];
  for (const [y0, h, dx, dz] of tiers) WH.push(M(await cbox(dx, h, dz, 0.3), white, [0, y0 + h / 2, 0]));

  RD.push(await hipRoof(red, 16.4, 13.6, 16.8, 3.6, 0.58, 0.6));
  RD.push(await hipRoof(red, 24.8, 10.4, 12.8, 3.2, 0.52, 0.55));
  RD.push(await hipRoof(red, 32.2, 7.6, 9.4, 6.0, 0.24, 0.55));
  // ridge on the top roof, along the width
  RD.push(M(await cbox(1.6, 1.2, 6.4, 0.3), red, [0, 38.9, 0]));

  // --- front gable (chidori hafu) on the first roof: red frame, white face, gold crest
  const gableRed = await extrudeProfile([[-5.2, 0], [5.2, 0], [0, 3.4]], { depth: 5, axis: 'x', bevel: 0.2, bevelStyle: 'chamfer' });
  RD.push(M(gableRed, red, [9.6, 18.4, 0]));
  const gableWhite = await extrudeProfile([[-4.0, 0], [4.0, 0], [0, 2.5]], { depth: 0.6, axis: 'x' });
  WH.push(M(gableWhite, white, [12.0, 18.75, 0]));
  GD.push(M(cylinderXGeo(0.55, 0.55, 0.5, 10), gold, [12.35, 19.75, 0]));
  // the same gable, smaller, on the second roof
  const gable2 = await extrudeProfile([[-3.6, 0], [3.6, 0], [0, 2.6]], { depth: 4, axis: 'x', bevel: 0.2, bevelStyle: 'chamfer' });
  RD.push(M(gable2, red, [7.2, 26.0, 0]));
  const gable2w = await extrudeProfile([[-2.7, 0], [2.7, 0], [0, 1.9]], { depth: 0.6, axis: 'x' });
  WH.push(M(gable2w, white, [9.0, 26.3, 0]));

  // --- windows: dark slatted panels proud of the white walls -------------
  const win = await cbox(0.5, 1.8, 2.0, 0.15);
  const winS = await cbox(2.0, 1.8, 0.5, 0.15);
  const wins = [
    // [tierIndex, front/back count, side count]
    [0, 4, 3, 13.0],
    [1, 3, 2, 22.0],
    [2, 2, 1, 29.6],
  ];
  for (const [ti, nf, ns, wy] of wins) {
    const [, , dx, dz] = tiers[ti];
    for (let i = 0; i < nf; i++) {
      const z = (i - (nf - 1) / 2) * (dz / (nf + 0.4));
      if (ti === 0 && Math.abs(z) < 1) continue;
      DK.push(M(win, dark, [dx / 2 + 0.1, wy, z]));
      DK.push(M(win, dark, [-dx / 2 - 0.1, wy, z]));
    }
    for (let i = 0; i < ns; i++) {
      const x = (i - (ns - 1) / 2) * (dx / (ns + 0.6));
      DK.push(M(winS, dark, [x, wy, dz / 2 + 0.1]));
      DK.push(M(winS, dark, [x, wy, -dz / 2 - 0.1]));
    }
  }
  // gate in the stone base, front
  DK.push(M(await cbox(1.4, 5.0, 5.0, 0.3), dark, [14.0, 3.6, 0]));
  RD.push(M(await cbox(1.2, 0.8, 6.4, 0.25), red, [14.3, 6.4, 0]));

  // --- gold shachihoko fish on both ridge ends ---------------------------
  // silhouette in (u, v): u maps to -Z (axis x), head down, tail curling outward
  const fish = [[0.0, 0.0], [1.2, 0.4], [1.45, 1.4], [0.95, 2.4], [1.15, 3.2], [1.9, 4.0], [0.5, 3.8], [-0.45, 3.0], [-0.95, 1.8], [-0.9, 0.6]];
  const fishR = await extrudeProfile(fish, { depth: 0.9, axis: 'x', bevel: 0.12, bevelStyle: 'chamfer' });
  const fishL = await extrudeProfile(fish.map(([u, v]) => [-u, v]), { depth: 0.9, axis: 'x', bevel: 0.12, bevelStyle: 'chamfer' });
  GD.push(M(fishR, gold, [0, 39.2, 2.5]));
  GD.push(M(fishL, gold, [0, 39.2, -2.5]));
  // gold caps on the four corners of the first roof eave (warm highlights)
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) GD.push(M(ico(0), gold, [sx * 13.3, 17.25, sz * 16.5], null, [0.7, 0.7, 0.7]));

  await fuse(root, 'StoneDark', DK);
  await fuse(root, 'StoneLight', S);
  await fuse(root, 'PlasterWhite', WH);
  await fuse(root, 'ZoneRed', RD);
  await fuse(root, 'Gold', GD);
  return finish(root);
}
