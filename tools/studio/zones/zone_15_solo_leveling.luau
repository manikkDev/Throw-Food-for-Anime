-- LIB: side_lib
-- zone_15_solo_leveling.luau - zone 15, "Gate of Shadows" (Solo Leveling), on the slim lane (v2,
-- 2026-11-22). z 5200..5560 (map id gate_of_shadows, no zone data yet), lane floor y -48, lane edges
-- x +-100. Run with
--   python tools/studio/zones/run_zone.py build 15
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone15_v1_canyon
-- and tools/studio/retired/zone_15_solo_leveling_v1.luau.
--
-- A dungeon gate torn open in the city, between deep purple basalt walls seamed with glowing runes;
-- dark flagstones with neon rune lines.
--   +X, the hunters' side: the guild's dark glass tower behind its checkpoint, the gate glowing in a
--     rune circle between obelisks, the ruined temple, and the seated stone king facing the throwers
--   -X, inside the dungeon: shadow knights on guard, the dragon's bones, a second gate with the ant
--     soldier before it, and the dark dagger in its stone at the far end
--   blue crystals and rune obelisks on the shelves, blue embers rising
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local SRC = SS.StoreAssets.Zone15_SoloLeveling
local ISEKAI = SS.StoreAssets.Zone08_Isekai
local ID = "gate_of_shadows"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 5200, 5560
local rng = Random.new(15107)

local FLOOR = Color3.fromRGB(46, 42, 62)
local RUNE = Color3.fromRGB(80, 190, 255)
local STONE = Color3.fromRGB(70, 66, 92)
local GY = P.TERRACE_Y + 0.4
local CRYSTAL = SRC:FindFirstChild("CrystalSpire") or ISEKAI.Crystal
local PILLAR = SRC:FindFirstChild("Column") or SRC.Obelisk

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, props: Folder, ground: Folder -- set below, once the zone's folder is cleared
local function sight(template: Instance, side: number, scale: number, ax: number, z: number): Model?
	local m = front(sights, template, side, scale, ax, z)
	if m then
		still(m, true)
	end
	return m
end
local function prop(
	template: Instance?,
	scale: number,
	x: number,
	z: number,
	yaw: number,
	opts: any?
): Model?
	if not template then
		return nil
	end
	local m = put(props, template, scale, yaw, x, z, opts)
	if m then
		still(m, false)
	end
	return m
end
local function runeCircle(x: number, z: number, radius: number)
	cylinder(
		ground,
		"RuneRing",
		radius * 2,
		0.3,
		CFrame.new(x, GY + 0.15, z),
		RUNE,
		Enum.Material.Neon
	).CastShadow =
		false
	cylinder(
		ground,
		"RuneRingInner",
		radius * 2 - 2.4,
		0.4,
		CFrame.new(x, GY + 0.17, z),
		FLOOR,
		Enum.Material.Slate
	).CastShadow =
		false
end
local function plinth(x: number, z: number, radius: number): number
	runeCircle(x, z, radius + 3)
	cylinder(
		sights,
		"Plinth",
		radius * 2,
		3,
		CFrame.new(x, GY + 1.5, z),
		STONE,
		Enum.Material.Slate
	).CastShadow =
		false
	claim(rect(x - radius - 3, x + radius + 3, z - radius - 3, z + radius + 3, "Plinth"))
	return GY + 3
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone15_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone15_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 15 (Gate of Shadows) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute(
	"Theme",
	"Gate of Shadows (Solo Leveling), zone_15_solo_leveling.luau v2 on side_lib"
)
ground = folder(root, "Ground")
sights = folder(root, "Sights")
props = folder(root, "Props")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STONE,
	material = Enum.Material.Basalt,
	band = RUNE,
	cap = Color3.fromRGB(90, 84, 120),
	capMaterial = Enum.Material.Slate,
	buttress = 36,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(
		ground,
		"Kerb",
		s * HALF,
		s * P.KERB_OUT,
		LY - 2,
		LY + 3,
		Z0,
		Z1,
		Color3.fromRGB(80, 230, 250),
		Enum.Material.Slate
	)
	local wall = revetment(ground, s, Z0, Z1, STYLE)
	for _, p in wall:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Band" then
			p.Material = Enum.Material.Neon
		end
	end
	box(
		wall,
		"RuneSeam",
		s * (P.TERRACE_OUT - P.BATTER * 0.4 - 0.4),
		s * (P.TERRACE_OUT - P.BATTER * 0.4 + 0.6),
		GY + 10,
		GY + 10.7,
		Z0,
		Z1,
		RUNE,
		Enum.Material.Neon
	)
	-- dark flagstones, a glowing border and cross lines
	local x1 = P.TERRACE_OUT - P.BATTER
	pave(
		ground,
		s * P.KERB_OUT,
		s * (x1 + 0.5),
		Z0,
		Z1,
		GY,
		FLOOR,
		Enum.Material.Slate,
		"Flagstones"
	)
	paint(ground, s * (P.STREET_OUT + 0.6), s * (P.STREET_OUT + 1.3), Z0, Z1, RUNE, GY).Material =
		Enum.Material.Neon
	for z = Z0 + 24, Z1 - 20, 44 do
		paint(ground, s * (P.STREET_OUT + 1.3), s * x1, z, z + 0.6, RUNE, GY).Material =
			Enum.Material.Neon
	end
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end

-- ================================================================================== +X: the hunters' side
sight(SRC.Guild, 1, 1.5, 129, 5291)
prop(SRC.Checkpoint, 1.3, P.STREET_OUT + 5, 5300, facing(1))
sight(SRC.Gate, 1, 1.5, 147, 5346)
do
	runeCircle(130, 5346, 14)
	prop(SRC.Obelisk, 0.85, 132, 5326, 0)
	prop(SRC.Obelisk, 0.85, 132, 5366, 0)
end
sight(SRC.Temple, 1, 1.2, 142.5, 5406)
-- the stone king on his plinth, facing the throw stage
do
	local top = plinth(142, 5502, 16)
	still(make(sights, SRC.StoneKing, 1.0, 0, Vector3.new(142, top, 5502)), true)
end

-- ================================================================================== -X: inside the dungeon
sight(SRC.Knight, -1, 1.3, 141.5, 5281)
sight(SRC.DragonBones, -1, 1.6, 125, 5321)
sight(SRC.Knight, -1, 1.3, 141.5, 5361)
sight(SRC.Gate, -1, 1.3, 149, 5401)
sight(SRC.Knight, -1, 1.3, 141.5, 5441)
-- the ant soldier stands out before the second gate, by the lane
prop(SRC.AntSoldier, 1.0, -129, 5401, facing(-1))
for _, kz in { 5281, 5361, 5441 } do
	runeCircle(-128, kz, 8)
end
-- the dark dagger in its stone, facing the throw stage
do
	local top = plinth(-142, 5512, 15)
	still(make(sights, SRC.Dagger, 2.4, 0, Vector3.new(-142, top, 5512)), true)
end

-- ================================================================================== crystals and the shelves
for _, s in { -1, 1 } do
	scatter({
		parent = props,
		templates = { CRYSTAL },
		count = 4,
		side = s,
		ax = { P.STREET_OUT + 4, 164 },
		z = { Z0 + 50, Z1 - 6 },
		scale = { 0.4, 0.75 },
	})
	scatter({
		parent = props,
		templates = { PILLAR },
		count = 2,
		side = s,
		ax = { P.STREET_OUT + 4, 150 },
		z = { Z0 + 50, Z1 - 30 },
		scale = { 0.6, 0.9 },
	})
	scatter({
		parent = props,
		templates = { CRYSTAL, ISEKAI.Crystal },
		count = 6,
		side = s,
		ax = { 184, 200 },
		z = { Z0 + 20, Z1 - 10 },
		scale = { 0.5, 0.9 },
	})
	scatter({
		parent = props,
		templates = { SRC.Obelisk },
		count = 3,
		side = s,
		ax = { 186, 198 },
		z = { Z0 + 30, Z1 - 10 },
		scale = { 0.6, 0.85 },
	})
end

-- blue embers rising through the dark
local fx = folder(root, "Fx")
for _, z in { 5270, 5360, 5450, 5530 } do
	local source = block(
		fx,
		"EmberSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 70, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(150, 90, 255))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 5
	e.Speed = NumberRange.new(1, 3)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.LightEmission = 1
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "GATE OF SHADOWS",
	accent = Color3.fromRGB(70, 150, 255),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(58, 40, 112), Color3.fromRGB(110, 86, 180)
		end
		return Color3.fromRGB(48, 126, 236), Color3.fromRGB(130, 190, 255)
	end,
	kerb = Color3.fromRGB(80, 230, 250),
	paving = Color3.fromRGB(64, 58, 86),
	pavingTex = Color3.fromRGB(116, 108, 146),
})

markSlim(root, Z0, Z1)
local _ = rng
return string.format("zone 15 Gate of Shadows v2: %d parts\n%s", #partsOf(root), sideReport(root))
