-- RETIRED 2026-11-22: zone 8 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_08_isekai.luau (side_lib) builds the zone now.
-- zone_08_isekai.luau - zone 8, "Isekai Crossroads" (crossover: other worlds), z 2680..3040. Map id
-- isekai_crossroads (no zone data yet). Run: python tools/studio/zones/run_zone.py build 8 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a tavern, a slime, a portal and crystals on bare grass,
-- with crystals standing in the trees and half buried in the ledges.)
--
-- The picture: where the fantasy worlds meet, under ice-blue crystal walls.
--   +X (left from the throw stage), the starting town: the adventurers' guild with its quest
--     boards, the item shop, the blacksmith, the tavern on the giant pig, then the summoning altar
--     and the rune portal facing the throwers.
--   -X, the monsters' side: the giant slime and its little ones, the demon lord's castle, the red
--     dragon asleep on its gold, and the hero's sword in its stone at the far end.
--   Crystals along the walls, mimics among the crates, islands floating over the rims, motes of light.
-- Templates: StoreAssets.Zone08_Isekai (all generate_mesh, squared, fronting -Z).
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 8,
	id = "isekai_crossroads",
	title = "Isekai Crossroads (other worlds)",
	src = "Zone08_Isekai",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 64, [1] = 64 },
	},
	prev = { -- zone 7's forest pass
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 28, [1] = 28 },
		ledgeY = { [-1] = 12, [1] = 12 },
		top = { [-1] = 70, [1] = 66 },
	},
	mats = {
		rock = Enum.Material.Glacier,
		prevRock = Enum.Material.Mud,
		terrace = G,
		prevTerrace = G,
		ledge = G,
		top = G,
	},
	colors = { [Enum.Material.Glacier] = Color3.fromRGB(150, 164, 228) },
	wobble = 0.5,
})
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local sky = folder(root, "Sky")
local JUNGLE = STORE.Zone01_Naruto
local WISTERIA = STORE.Zone02_DemonSlayer.Wisteria

local COBBLE = Color3.fromRGB(186, 180, 196)
local DIRT = Color3.fromRGB(150, 120, 96)
local STONE = Color3.fromRGB(150, 150, 170)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

-- ================================================================================== +X: the starting town
do
	local side = 1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, COBBLE, Enum.Material.Cobblestone)
	local z = S0 + 2
	local guildZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.GuildHall, 1.8 } } })
	local shopZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.ItemShop, 2.0 } } })
	local forgeZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 5,
		list = { { SRC.Forge, 2.1 }, { SRC.PigTavern, 1.35 } },
	})
	local rowEnd = z - 5
	-- quest boards before the guild, crates and a mimic before the shop, barrels by the forge
	place(props, SRC.QuestBoard, 1.7, facing(side), Vector3.new(172, GY, guildZ0 + 10))
	place(props, SRC.QuestBoard, 1.7, facing(side), Vector3.new(172, GY, guildZ0 + 34))
	try(props, KIT.Prop_store_Crate, 1.6, 20, Vector3.new(170, GY, shopZ0 + 8))
	try(props, KIT.Prop_store_Crate, 1.3, 50, Vector3.new(174.5, GY, shopZ0 + 11))
	place(props, SRC.Mimic, 1.3, facing(side), Vector3.new(171, GY, shopZ0 + 38))
	try(props, KIT.Prop_store_Barrel, 1.6, 0, Vector3.new(170, GY, forgeZ0 + 6))
	try(props, KIT.Prop_pirate_harbor_BarrelStack, 1.4, 30, Vector3.new(171, GY, forgeZ0 + 46))
	try(props, STORE.Zone07_Hunter.Signpost, 1.5, facing(side), Vector3.new(169, GY, shopZ0 - 2.5))
	for lz = S0 + 22, rowEnd, 50 do
		try(
			props,
			KIT.Prop_realm_of_legends_SpiritLantern,
			1.8,
			facing(side),
			Vector3.new(166.6, GY, lz)
		)
	end
	-- the summoning altar, then the portal across the terrace's end, its back to the next gate's pillar
	do
		local pz = S1 - 11.6
		place(sights, SRC.Portal, 1.7, 0, Vector3.new(200, GY - 0.4, pz), { fit = 1.0 })
		local az = (rowEnd + pz - 11) / 2
		place(sights, SRC.Altar, 1.35, 0, Vector3.new(196, GY - 0.3, az))
		try(props, SRC.Mimic, 1.1, 200, Vector3.new(224, GY, az + 12))
	end
end

-- ================================================================================== -X: the monsters' side
do
	local side = -1
	pave(groundF, side, 163.5, 174, S0 - 4, S1 + 2, DIRT, Enum.Material.Ground)
	local z = S0 + 2
	local slimeZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 6,
		front = 190,
		list = { { SRC.Slime, 1.9 } },
	})
	local slimeZ1 = z - 6
	z = row({ parent = sights, side = side, z = z, gap = 6, list = { { SRC.DemonCastle, 2.1 } } })
	local dragonZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 6,
		front = 176,
		list = { { SRC.Dragon, 1.85 } },
	})
	local rowEnd = z - 6
	-- little slimes round the big one
	scatter({
		parent = props,
		templates = { SRC.SlimeSmall },
		count = 9,
		side = side,
		ax = { 176, 232 },
		z = { slimeZ0 - 2, slimeZ1 + 4 },
		scale = { 0.6, 1.3 },
		y = TERRACE - 0.2,
		soft = true,
	})
	-- a mimic at the edge of the dragon's hoard
	try(props, SRC.Mimic, 1.2, facing(side), Vector3.new(-171, TERRACE, dragonZ0 + 6))
	-- the hero's sword in its stone at the far end, facing the throw stage
	do
		local sz = (rowEnd + 6 + S1) / 2
		for i, r in { 17, 13 } do
			local ring = cylinder(
				sights,
				"SwordPlinth",
				r * 2,
				1.4,
				CFrame.new(-200, TERRACE + i * 1.3 - 0.5, sz),
				STONE,
				Enum.Material.Slate
			)
			ring.CastShadow = false
		end
		reserve(-200, sz, 17, 17, LY, TERRACE + 4, "the sword's plinth")
		place(sights, SRC.HeroSword, 2.6, 0, Vector3.new(-200, TERRACE + 2.3, sz), { over = true })
	end
	for lz = S0 + 30, S1 - 20, 54 do
		try(
			props,
			KIT.Prop_realm_of_legends_SpiritLantern,
			1.8,
			facing(side),
			Vector3.new(-166.6, GY, lz)
		)
	end
end

-- ================================================================================== both sides
for _, side in { -1, 1 } do
	-- crystals: along the wall's foot, on the ledges and the rims; big ones where there is room
	if side < 0 then
		scatter({
			parent = props,
			templates = { SRC.Crystal },
			count = 8,
			side = side,
			ax = { 176, 230 },
			z = { S0, S1 - 4 },
			scale = { 0.4, 1.0 },
			y = TERRACE - 1.4,
			soft = true,
			sunkOk = 3,
		})
	end
	scatter({
		parent = props,
		templates = { SRC.Crystal },
		count = 7,
		side = side,
		ax = { ledgeAx(side) - 8, ledgeAx(side) + 8 },
		z = { Z0 + 30, Z1 },
		scale = { 0.5, 1.0 },
		sink = 2.4,
		soft = true,
		sunkOk = 12,
	})
	scatter({
		parent = props,
		templates = { SRC.Crystal },
		count = 6,
		side = side,
		ax = { rimAx(side) + 2, rimAx(side) + 30 },
		z = { Z0 + 20, Z1 },
		scale = { 1.0, 1.9 },
		sink = 3,
		soft = true,
		sunkOk = 12,
	})
	-- trees: wisteria and green on the ledge, a wood on the rim
	for tz = Z0 + 36, Z1 - 8, 30 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then WISTERIA else JUNGLE.TreeBroad,
			side,
			ledgeAx(side) + rng:NextNumber(-7, 7),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.7, 1.0)
		)
	end
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 9,
		side = side,
		ax = { ledgeAx(side) - 10, ledgeAx(side) + 9 },
		z = { Z0 + 30, Z1 },
		scale = { 1.2, 1.8 },
		sink = 0.6,
		soft = true,
	})
	for tz = Z0 + 18, Z1 - 4, 22 do
		local roll = rng:NextNumber()
		local template = if roll < 0.35
			then WISTERIA
			elseif roll < 0.7 then JUNGLE.TreeBroad
			else JUNGLE.TreeTall
		plant(
			trees,
			template,
			side,
			rimAx(side) + rng:NextNumber(-6, 10),
			tz + rng:NextNumber(-7, 7),
			rng:NextNumber(1.3, 1.9)
		)
	end
	for tz = Z0 + 30, Z1 - 4, 34 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(30, 48),
			tz + rng:NextNumber(-10, 10),
			rng:NextNumber(1.6, 2.3)
		)
	end
	-- islands floating over the rim, a crystal on each
	for i, iz in { Z0 + 110, Z0 + 250 } do
		local x = side * (rimAx(side) + 26 + i * 8)
		local y = 112 + i * 14 + side * 6
		local island = make(
			sky,
			KIT.Prop_realm_of_legends_FloatingIsland,
			2.2,
			i * 70,
			Vector3.new(x, y, iz + side * 30)
		)
		island:SetAttribute("AuditSkip", true) -- in the sky by design
		local _, isize = island:GetBoundingBox()
		local crystal =
			make(sky, SRC.Crystal, 0.8, i * 40, Vector3.new(x, y + isize.Y * 0.42, iz + side * 30))
		crystal:SetAttribute("AuditSkip", true)
	end
end
-- motes of light
drift(
	"rbxassetid://5057182105",
	Color3.fromRGB(190, 170, 255),
	Color3.fromRGB(130, 200, 255),
	0.9,
	6,
	0.9
)

floor({
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
return finish()
