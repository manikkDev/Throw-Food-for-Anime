-- post_build.luau - run in Studio EDIT mode after the map chunks (build_in_studio.py does it).
--
-- Small dressing passes that are cheaper to state once here than to thread through the
-- generator. Safe to re-run.
--   1. Wall bodies get a real surface per zone. As flat SmoothPlastic slabs a 2,000-stud
--      corridor read as cardboard; a built-in material with the zone's own colour reads as
--      brick, planks or stone at no cost (no textures to upload, no extra parts).
--   2. The training-dummy stand-ins the map places on each dojo pad are removed: the SERVER
--      stands the owner's real gear tier there (PlotService:_showGear).
--   3. Glow: the parts the modellers marked as lamps, flames and screens become Neon.

local map = workspace:FindFirstChild("Map")
if not map then
	return "no Workspace.Map"
end

local WALLS = {
	Walls_sakura_schoolyard = Enum.Material.Brick,
	Walls_pirate_harbor = Enum.Material.WoodPlanks,
	Walls_ninja_village = Enum.Material.Wood,
	Walls_samurai_castle = Enum.Material.Cobblestone,
	Walls_hero_city = Enum.Material.Concrete,
	Walls_realm_of_legends = Enum.Material.Marble,
}

-- kit model -> the colour-part name prefixes that should glow
local GLOW = {
	Prop_hero_city_NeonSign = { "ZoneCyan", "NeonPink" },
	Prop_hero_city_ArcadeMachine = { "ZoneCyan" },
	Prop_hero_city_StreetLamp = { "ZoneCyan" },
	Prop_hero_city_NeonTower = { "ZoneCyan" },
	Prop_hero_city_MechaStatue = { "ZoneCyan" },
	Prop_realm_of_legends_SpiritGate = { "GlowLilac" },
	Prop_realm_of_legends_SpiritLantern = { "ZoneViolet" },
	Prop_shared_VendingMachine = { "White" },
	Prop_shared_LanternString = { "Red" },
}

local walls, dummies, glowing = 0, 0, 0
for _, inst in map:GetDescendants() do
	if inst:IsA("Part") and inst.Name == "WallBody" then
		inst.Material = WALLS[inst.Parent.Name] or Enum.Material.Brick
		walls += 1
	elseif inst.Name == "Equip_wooden_dummy" and inst:GetAttribute("MissingMesh") then
		inst:Destroy()
		dummies += 1
	elseif inst:IsA("MeshPart") then
		local model = inst.Parent
		local prefixes = model and GLOW[model:GetAttribute("Kit") or model.Name]
		if prefixes then
			for _, prefix in prefixes do
				if string.sub(inst.Name, 1, #prefix) == prefix then
					inst.Material = Enum.Material.Neon
					glowing += 1
				end
			end
		end
	end
end
return string.format("post_build: %d wall bodies surfaced, %d dummy stand-ins removed, %d parts glowing", walls, dummies, glowing)
