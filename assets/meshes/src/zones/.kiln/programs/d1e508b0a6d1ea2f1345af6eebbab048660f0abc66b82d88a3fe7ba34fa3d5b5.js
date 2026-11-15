// Prop_samurai_castle_PineTree: pine with three flat cloud-shaped layers.
// Target (Roblox studs, x/y/z): 10 x 17 x 10, standing on y = 0, front -Z.
//
// UNITS: authored in STUDS, converted with `kiln_to_roblox.mjs --studs-per-m 1`.
// Kiln frame: +X forward (becomes Roblox -Z), +Y up, +Z right (becomes Roblox +X).
// Each colour is unioned into ONE closed mesh (bible: one clean piece per colour).

const meta = { name: 'Prop_samurai_castle_PineTree', category: 'prop' };

function mat(label, hex) {
  const m = gameMaterial(hex, { roughness: 0.8 });
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
const D = Math.PI / 180;
function M(geo, m, pos, rot, scl) {
  const o = new THREE.Mesh(geo, m);
  o.position.set(pos[0], pos[1], pos[2]);
  if (rot) o.rotation.set(rot[0] * D, rot[1] * D, rot[2] * D);
  if (scl) o.scale.set(scl[0], scl[1], scl[2]);
  o.updateMatrixWorld(true);
  return o;
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
  const root = createRoot('Prop_samurai_castle_PineTree');

  const bark = mat('Bark', 0x8a5a2b);
  const leafDark = mat('LeafDark', 0x46b82c);
  const leafLight = mat('LeafLight', 0x5bd43a);
  const trim = mat('ZoneRed', 0xe0453c);
  const lip = mat('StoneDark', 0x6b7686);

  // --- base lip: a low octagonal stone ring the trunk stands in -------------
  const base = [
    M(await revolveProfile([[0, 0], [2.6, 0], [2.6, 0.55], [2.2, 0.75], [0, 0.75]], { segments: 8, bevel: 0.15, bevelSegments: 2 }), lip, [0, 0, 0], [0, 22.5, 0]),
  ];

  // --- trunk: chunky, kinked once, with two stubby arms to the pads ---------
  const wood = [
    M(cylinderGeo(0.85, 1.25, 6.0, 7), bark, [0, 3.0, 0]),
    M(cylinderGeo(0.65, 0.85, 5.2, 7), bark, [0.25, 8.2, -0.15], [6, 0, -6]),
    M(cylinderGeo(0.5, 0.65, 4.4, 7), bark, [0.45, 12.8, -0.25], [-4, 0, 4]),
    // arms out to the lower pad lobes
    M(cylinderGeo(0.45, 0.6, 3.2, 6), bark, [0, 6.2, 1.6], [62, 0, 0]),
    M(cylinderGeo(0.45, 0.6, 3.0, 6), bark, [0.2, 6.4, -1.5], [-60, 0, 0]),
  ];

  // --- red zone trim: a fat rope band round the trunk (shimenawa) -----------
  const red = [M(await revolveProfile([[0.9, 0], [1.42, 0], [1.42, 0.7], [0.9, 0.7]], { segments: 10, bevel: 0.2, bevelSegments: 2 }), trim, [0, 1.9, 0])];

  // --- the three cloud layers: dark lobe cluster + lighter top band ---------
  // [y, spread, lobe radius, flatten]
  const layers = [
    { y: 7.3, r: 3.0, lobe: 2.25, n: 6, flat: 0.5, cx: 0, cz: 0 },
    { y: 11.6, r: 2.3, lobe: 1.85, n: 5, flat: 0.52, cx: 0.3, cz: -0.2 },
    { y: 15.4, r: 1.3, lobe: 1.7, n: 4, flat: 0.6, cx: 0.45, cz: -0.25 },
  ];
  const dark = [];
  const light = [];
  layers.forEach((L, li) => {
    const sph = sphereGeo(1, 7, 5);
    dark.push(M(sph, leafDark, [L.cx, L.y, L.cz], null, [L.lobe * 1.15, L.lobe * L.flat * 1.1, L.lobe * 1.15]));
    for (let i = 0; i < L.n; i++) {
      const a = (i / L.n) * Math.PI * 2 + li * 0.6;
      const rr = L.r * (i % 2 ? 0.92 : 1.0);
      const x = L.cx + Math.cos(a) * rr;
      const z = L.cz + Math.sin(a) * rr;
      const s = L.lobe * (i % 2 ? 0.88 : 1.0);
      dark.push(M(sph, leafDark, [x, L.y - 0.1, z], [0, a / D, 0], [s, s * L.flat, s]));
    }
    // lighter top band: smaller flattened lobes riding the upper surface
    const lc = Math.max(3, L.n - 2);
    light.push(M(sph, leafLight, [L.cx, L.y + L.lobe * L.flat * 0.75, L.cz], null, [L.lobe * 1.05, L.lobe * L.flat * 0.65, L.lobe * 1.05]));
    for (let i = 0; i < lc; i++) {
      const a = (i / lc) * Math.PI * 2 + li * 0.6 + 0.4;
      const x = L.cx + Math.cos(a) * L.r * 0.62;
      const z = L.cz + Math.sin(a) * L.r * 0.62;
      const s = L.lobe * 0.8;
      light.push(M(sph, leafLight, [x, L.y + L.lobe * L.flat * 0.55, z], null, [s, s * L.flat * 0.7, s]));
    }
  });

  await fuse(root, 'StoneDark', base);
  await fuse(root, 'Bark', wood);
  await fuse(root, 'ZoneRed', red);
  await fuse(root, 'LeafDark', dark);
  await fuse(root, 'LeafLight', light);
  return finish(root);
}
