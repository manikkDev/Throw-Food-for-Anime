-- LIB: side_lib
-- zone_08_isekai.luau - zone 8, "Isekai Crossroads" (crossover: other worlds), on the slim lane (v2,
-- 2026-11-22). z 2680..3040 (map id isekai_crossroads, no zone data yet), lane floor y -48, lane edges
-- x +-100. Run with
--   python tools/studio/zones/run_zone.py build 8
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone8_v1_canyon
-- and tools/studio/retired/zone_08_isekai_v1.luau.
--
-- Where the fantasy worlds meet, between ice-blue crystal walls.
--   +X, the starting town on cobbles: the adventurers' guild with its quest boards, the item shop with
--     a mimic among its crates, the blacksmith, the tavern on the giant pig, then the summoning altar
--     and the rune portal across the terrace's end, facing the throwers
--   -X, the monsters' side by a dirt road: the giant slime and its little ones, the demon lord's
--     castle, the red dragon on its gold, and the hero's sword in its stone at the far end
--   crystals on the shelves, islands floating over them, motes of light over the lane
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone08_Isekai
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local WISTERIA = SS.StoreAssets.Zone02_DemonSlayer.Wisteria
local ID = "isekai_crossroads"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 2680, 3040
local rng = Random.new(8807)

local COBBLE = Color3.fromRGB(186, 180, 196)
local DIRT = Color3.fromRGB(150, 120, 96)
local STONE = Color3.fromRGB(150, 150, 170)
local ICE = Color3.fromRGB(150, 164, 228)
local ICE_DARK = Color3.fromRGB(104, 112, 186)
local ICE_CAP = Color3.fromRGB(214, 224, 255)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, props: Folder -- set below, once the zone's folder is cleared
local function sight(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local m = front(sights, template, side, scale, ax, z, opts)
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

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone8_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone8_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 8 (Isekai Crossroads) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Isekai Crossroads (other worlds), zone_08_isekai.luau v2 on side_lib")
local ground = folder(root, "Ground")
sights = folder(root, "Sights")
props = folder(root, "Props")
local trees = folder(root, "Trees")
local sky = folder(root, "Sky")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = ICE,
	material = Enum.Material.Glacier,
	band = ICE_DARK,
	cap = ICE_CAP,
	capMaterial = Enum.Material.Glacier,
	rail = Color3.fromRGB(176, 150, 250),
	buttress = 34,
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
		Color3.fromRGB(250, 220, 110),
		Enum.Material.Slate
	)
	revetment(ground, s, Z0, Z1, STYLE)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end
pave(
	ground,
	P.KERB_OUT,
	P.TERRACE_OUT - P.BATTER + 0.5,
	Z0,
	Z1,
	GY,
	COBBLE,
	Enum.Material.Cobblestone,
	"Cobbles"
)
pave(
	ground,
	-P.KERB_OUT,
	-(P.STREET_OUT + 2),
	Z0,
	Z1,
	GY - 0.1,
	DIRT,
	Enum.Material.Ground,
	"DirtRoad"
)
local lantern = KIT:FindFirstChild("Prop_realm_of_legends_SpiritLantern")

-- ================================================================================== +X: the starting town
sight(SRC.GuildHall, 1, 1.4, 129, 2762)
sight(SRC.ItemShop, 1, 1.4, 139, 2804)
sight(SRC.Forge, 1, 1.4, 150, 2845)
sight(SRC.PigTavern, 1, 1.0, 129, 2888)
-- quest boards before the guild, crates and a mimic before the shop, barrels by the forge
prop(SRC.QuestBoard, 1.5, P.STREET_OUT + 6, 2752, facing(1))
prop(SRC.QuestBoard, 1.5, P.STREET_OUT + 6, 2774, facing(1))
prop(KIT:FindFirstChild("Prop_store_Crate"), 1.5, 130, 2794, 20)
prop(KIT:FindFirstChild("Prop_store_Crate"), 1.2, 128, 2802, 50)
prop(SRC.Mimic, 1.2, 130, 2814, facing(1))
prop(KIT:FindFirstChild("Prop_store_Barrel"), 1.5, 140, 2832, 0)
prop(KIT:FindFirstChild("Prop_pirate_harbor_BarrelStack"), 1.3, 140, 2856, 30)
-- the summoning altar, then the rune portal across the terrace's end
prop(SRC.Altar, 1.0, 142, 2938, 0)
prop(SRC.Mimic, 1.0, 162, 2960, 200)
local portal = put(sights, SRC.Portal, 1.2, 0, 142, 3018, { name = "Portal" })
if portal then
	still(portal, true)
end

-- ================================================================================== -X: the monsters' side
sight(SRC.Slime, -1, 1.4, 138, 2762)
scatter({
	parent = props,
	templates = { SRC.SlimeSmall },
	count = 6,
	side = -1,
	ax = { P.STREET_OUT + 4, 136 },
	z = { 2742, 2790 },
	scale = { 0.7, 1.2 },
})
sight(SRC.DemonCastle, -1, 1.2, 146, 2822)
sight(SRC.Dragon, -1, 1.2, 131, 2888)
prop(KIT:FindFirstChild("Prop_pirate_harbor_TreasurePile"), 1.6, -(P.STREET_OUT + 7.5), 2900, 30)
prop(SRC.Mimic, 1.2, -(P.STREET_OUT + 7), 2874, facing(-1))
-- the hero's sword in its stone at the far end, facing the throw stage
do
	local sx, sz = -142, 2962
	for i, r in { 15, 11.5 } do
		cylinder(
			sights,
			"SwordPlinth",
			r * 2,
			1.4,
			CFrame.new(sx, GY + i * 1.3 - 0.6, sz),
			STONE,
			Enum.Material.Slate
		).CastShadow =
			false
	end
	claim(rect(sx - 16, sx + 16, sz - 16, sz + 16, "SwordPlinth"))
	still(make(sights, SRC.HeroSword, 1.6, 0, Vector3.new(sx, GY + 2.3, sz)), true)
end
-- crystals in the monsters' ground, small ones
scatter({
	parent = props,
	templates = { SRC.Crystal },
	count = 4,
	side = -1,
	ax = { P.STREET_OUT + 4, 164 },
	z = { 2930, Z1 - 10 },
	scale = { 0.3, 0.55 },
})

-- ================================================================================== both streets and shelves
for _, s in { -1, 1 } do
	for z = 2744, Z1 - 30, 50 do
		if lantern then
			prop(lantern, 1.7, s * (P.STREET_OUT + 3.5), z, facing(s))
		end
	end
	for _, t in { { 2740 }, { 2860 }, { 2990 } } do
		local tr = put(
			trees,
			if rng:NextNumber() < 0.5 then WISTERIA else JUNGLE.TreeBroad,
			0.95,
			rng:NextInteger(0, 3) * 90,
			s * 192,
			t[1] + s * 12,
			{ soft = 4 }
		)
		if tr then
			still(tr, false)
		end
	end
	scatter({
		parent = props,
		templates = { SRC.Crystal },
		count = 5,
		side = s,
		ax = { 184, 200 },
		z = { Z0 + 20, Z1 - 10 },
		scale = { 0.45, 0.8 },
	})
	-- islands floating over the shelf, a crystal on each (in the sky: no claim)
	for i, iz in { 2790, 2930 } do
		local x = s * 192
		local y = 34 + i * 8 + s * 3
		local island = make(
			sky,
			KIT.Prop_realm_of_legends_FloatingIsland,
			1.4,
			i * 70,
			Vector3.new(x, y, iz + s * 20)
		)
		island:SetAttribute("LaneOk", true)
		local _, isize = island:GetBoundingBox()
		local crystal =
			make(sky, SRC.Crystal, 0.55, i * 40, Vector3.new(x, y + isize.Y * 0.42, iz + s * 20))
		crystal:SetAttribute("LaneOk", true)
	end
end

-- motes of light over the lane
local fx = folder(root, "Fx")
for _, z in { 2750, 2840, 2930, 3010 } do
	local source = block(
		fx,
		"MoteSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 60, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Motes"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(190, 170, 255), Color3.fromRGB(130, 200, 255))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 5
	e.Speed = NumberRange.new(1, 3)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.LightEmission = 0.9
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "ISEKAI CROSSROADS",
	accent = Color3.fromRGB(150, 110, 240),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(126, 92, 220), Color3.fromRGB(180, 156, 246)
		end
		return Color3.fromRGB(88, 190, 226), Color3.fromRGB(160, 226, 246)
	end,
	kerb = Color3.fromRGB(250, 220, 110),
	paving = Color3.fromRGB(214, 210, 232),
	pavingTex = Color3.fromRGB(236, 234, 248),
})

markSlim(root, Z0, Z1)
return string.format("zone 8 Isekai Crossroads v2: %d parts\n%s", #partsOf(root), sideReport(root))
