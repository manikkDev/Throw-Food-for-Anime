-- aura_judge.luau (Studio EDIT mode, rerunnable): the game's auras, worn on a REAL base, for judging.
--
--   python tools/aura_judge.py show <heroId> ...      (or: page <n>, clear)
--
-- WHY: the owner judges auras on the preview yard, whose floor is dark navy. A base is in daylight on
-- pale paving: additive particles add up to WHITE there (Gojo's blue sphere came out a white ball that hid
-- him). So an aura is only judged where it is worn. This stands the baked heroes on Plot5's pedestals, in
-- the game's own spacing, and puts each one's aura on with the game's own code (src/client/Fx/HeroAura and
-- the generated Config/Auras), so what is seen is what a player sees. Nothing here ships: the folder
-- Workspace._AuraJudge is removed by `clear` (and by the next run).
--
-- A HOT aura (design/auras.json "hot") is put on at the rate the game uses at maximum graphics
-- (Core/AuraDensity), so set Studio's edit quality to Level21 and this is the game at its thickest;
-- raw = true puts every aura on unthinned, to find the hot ones.
--
-- _G.AURA_JUDGE = { ids = { heroId, ... }, raw = boolean?, marks = { [heroId] = share }? } or { clear = true }.
-- (marks tries a hot mark on a hero before it is written to design/auras.json)
-- ids is { [slot] = heroId }, slot 1..42 in reading order from the lane (front row first, left to right).
-- Returns one line per hero: "<slot> <heroId> <aura key> <live>".
local RS = game:GetService("ReplicatedStorage")

local args = _G.AURA_JUDGE or {}
_G.AURA_JUDGE = nil

for _, h in _G.AuraJudgeHandles or {} do
	pcall(h.stop)
end
_G.AuraJudgeHandles = {}
local old = workspace:FindFirstChild("_AuraJudge")
if old then
	old:Destroy()
end
if args.clear or not args.ids then
	return "cleared"
end

local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local HeroAura = require(client.Fx.HeroAura:Clone())
local Auras = require(RS.Shared.Config.Auras:Clone())
local AuraDensity = require(RS.Shared.Core.AuraDensity:Clone())
local chars = RS.Assets.Characters
-- the base's pedestals in reading order from the lane: front row first, left to right (7 a row)
local pedestals: { BasePart } = {}
for _, p in workspace.Map.Plots.Plot5.Pedestals:GetChildren() do
	if p:IsA("BasePart") then
		table.insert(pedestals, p)
	end
end
table.sort(pedestals, function(x, y)
	if math.abs(x.Position.Z - y.Position.Z) > 1 then
		return x.Position.Z > y.Position.Z
	end
	return x.Position.X < y.Position.X
end)

local folder = Instance.new("Folder")
folder.Name = "_AuraJudge"
folder.Parent = workspace

local report = {}
for i, id in args.ids do
	local ped = pedestals[i]
	local template = chars:FindFirstChild("Char_" .. id)
	if not ped or not template then
		table.insert(report, `{i} {id} FAIL {if ped then "no Char_" .. id else "no pedestal"}`)
		continue
	end
	local hero = template:Clone()
	hero:SetAttribute("HeroId", id)
	for _, p in hero:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	local root = hero:FindFirstChild("HumanoidRootPart") :: BasePart
	-- (a placed hero's root stands 3.2 above its pedestal's middle and faces the lane, +Z)
	hero:PivotTo(
		CFrame.new(ped.Position + Vector3.new(0, 3.2, 0))
			* CFrame.Angles(0, math.pi, 0)
			* root.CFrame:ToObjectSpace(hero:GetPivot())
	)
	hero.Parent = folder
	local key = Auras.ByHero[id]
	if typeof(key) ~= "string" then
		table.insert(report, `{i} {id} - 0`)
		continue
	end
	local mark = if args.marks and args.marks[id] then args.marks[id] else Auras.Hot[key]
	local rate = if args.raw then 1 else AuraDensity.rate(mark, 10)
	local handle = HeroAura.attach(hero, key, 1, rate)
	if handle then
		-- (HeroAura welds an aura part to the hero; the judge's heroes are anchored, so the part is too)
		for _, p in hero:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("RootCF") ~= nil then
				p.Anchored = true
			end
		end
		table.insert(_G.AuraJudgeHandles, handle)
		table.insert(report, `{i} {id} {key} {math.floor(handle.live + 0.5)} x{rate}`)
	else
		table.insert(report, `{i} {id} {key} FAIL no template`)
	end
end
return table.concat(report, "\n")
