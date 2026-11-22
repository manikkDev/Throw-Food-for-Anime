-- base_cleanup.luau - Studio EDIT mode, safe to run again (2026-11-22, owner's review of the bases):
--   * "unnecessary to have separate multiple food stall and selling place for each base": the five
--     food carts and five sell booths (one pair per throw pad, from rework_hub_v2.luau) become ONE
--     shared pair in the plaza, back where the hub always kept them (Hub.FoodCart, Hub.SellBooth):
--     the food cart in front of the RAMEN ALLEY district's sign, the squad booth in front of the
--     HALL OF LEGENDS sign. Their prompts (Action food / squad) never carried a Plot, so nothing in
--     the code changes: MenuController opens the same screens from any station.
--   * the small torii at the front of each base (HubV2.DojoGate) go; their stone lanterns stay
--   * the koi windsocks and hanging lantern strings beside the training courts and the path go,
--     and the one that stood in each base's back gate (Hub.Dressing, z -50) too
-- Everything removed is archived once in ServerStorage.MapArchive.BaseDressing_v1 (never delete).
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local hub, plots, hubV2 = map.Hub, map.Plots, map.HubV2

local archive = SS:FindFirstChild("MapArchive")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
end
local old = archive:FindFirstChild("BaseDressing_v1")
if not old then
	old = Instance.new("Folder")
	old.Name = "BaseDressing_v1"
	old:SetAttribute(
		"Note",
		"Per-base food carts, sell booths, torii, windsocks, lantern strings before base_cleanup.luau (2026-11-22). Never delete."
	)
	old.Parent = archive
end
local moved = {}
local function stow(inst: Instance)
	inst.Parent = old
	moved[inst.Name] = (moved[inst.Name] or 0) + 1
end

-- 1. one food cart and one squad booth, in the plaza (district signs stand at z -88, x -+282)
local STALLS = {
	{ name = "FoodCart", x = -282 },
	{ name = "SellBooth", x = 282 },
}
for _, st in STALLS do
	local keep = hub:FindFirstChild(st.name)
	for i = 1, 5 do
		local plot = plots:FindFirstChild("Plot" .. i)
		local c = plot and plot:FindFirstChild(st.name)
		if c then
			if not keep then
				keep = c
				c.Parent = hub
			else
				stow(c)
			end
		end
	end
	if keep and keep:IsA("BasePart") then
		-- in front of the district's sign, facing the bases (+Z), on the plaza
		local y = keep.Position.Y
		local rot = keep.CFrame - keep.Position
		local target = CFrame.new(st.x, y, -76) * rot
		local delta = target * keep.CFrame:Inverse()
		for _, d in keep:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		keep.CFrame = target
	end
end

-- 2. the base torii
for _, c in hubV2:GetChildren() do
	if c.Name == "DojoGate" then
		stow(c)
	end
end

-- 3. windsocks and lantern strings by the courts and the path, and the one in each back gate
local scPlots = map.Scenery:FindFirstChild("Plots")
for _, f in { scPlots, hub:FindFirstChild("Dressing") } do
	if f then
		for _, c in f:GetChildren() do
			if c.Name == "Prop_shared_KoiFlagPole" or c.Name == "Prop_shared_LanternString" then
				local p = c:GetPivot().Position
				local byBase = f == scPlots or (p.Z > -58 and p.Z < -42 and math.abs(p.X) < 240)
				if byBase then
					stow(c)
				end
			end
		end
	end
end

local report = {}
for n, k in moved do
	table.insert(report, n .. " " .. k)
end
local fc, sb = hub:FindFirstChild("FoodCart"), hub:FindFirstChild("SellBooth")
return string.format(
	"archived: %s\nFoodCart at %s, SellBooth at %s",
	table.concat(report, ", "),
	fc and tostring(fc.Position) or "none",
	sb and tostring(sb.Position) or "none"
)
