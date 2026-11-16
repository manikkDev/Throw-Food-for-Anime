--!nocheck
-- review_auras.luau - EDIT mode. Puts every ReplicatedStorage.Assets.Auras.<Key> (or the keys in
-- _G.AURA_REVIEW) on a clone of one hero in rows at Workspace.AuraReview (y = 600, away from the map)
-- so they can be captured side by side. Mirrors the apply logic of src/client/Fx/HeroAura.luau.
-- Run with _G.AURA_REVIEW_CLEAR = true to remove the stage.

local RS = game:GetService("ReplicatedStorage")
local old = workspace:FindFirstChild("AuraReview")
if old then
	old:Destroy()
end
if _G.AURA_REVIEW_CLEAR then
	_G.AURA_REVIEW_CLEAR = nil
	return "cleared"
end

local HERO = _G.AURA_REVIEW_HERO or "Char_cursed_vessel"
local PER_ROW, DX, DZ = tonumber(_G.AURA_REVIEW_ROW) or 40, tonumber(_G.AURA_REVIEW_DX) or 8, 16
local ORIGIN = Vector3.new(0, 600, 0)

local stage = Instance.new("Folder")
stage.Name = "AuraReview"
stage.Parent = workspace
local floor = Instance.new("Part")
floor.Anchored = true
floor.Size = Vector3.new(420, 1, 40)
floor.Position = ORIGIN + Vector3.new(190, -0.5, 0)
floor.Color = Color3.fromRGB(70, 76, 110)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = stage

local function apply(model, tpl)
	local root = model:FindFirstChild("HumanoidRootPart")
	local clone = tpl:Clone()
	for _, f in clone:GetChildren() do
		if f.Name == "Beams" then
			for _, b in f:GetChildren() do
				b.Parent = root
			end
			continue
		end
		local target = model:FindFirstChild(f.Name) or root
		for _, ch in f:GetChildren() do
			if ch:IsA("Attachment") then
				ch.CFrame = target.CFrame:ToObjectSpace(root.CFrame * ch.CFrame)
				ch.Parent = target
			elseif ch.Name == "Direct" then
				for _, e in ch:GetChildren() do
					e.Parent = target
				end
			elseif ch:IsA("BasePart") then
				ch.CFrame = root.CFrame * (ch:GetAttribute("RootCF") or CFrame.new())
				local w = Instance.new("WeldConstraint")
				w.Part0 = target
				w.Part1 = ch
				w.Parent = ch
				ch.Parent = model
			end
		end
	end
	clone:Destroy()
end

local keys = {}
if type(_G.AURA_REVIEW) == "table" then
	keys = _G.AURA_REVIEW
else
	for _, t in RS.Assets.Auras:GetChildren() do
		table.insert(keys, t.Name)
	end
	table.sort(keys)
end
local template = RS.Assets.Characters:FindFirstChild(HERO)
local out = {}
for i, key in keys do
	local tpl = RS.Assets.Auras:FindFirstChild(key)
	if not tpl then
		continue
	end
	local m = template:Clone()
	m.Name = key
	local col, row = (i - 1) % PER_ROW, (i - 1) // PER_ROW
	local at = ORIGIN + Vector3.new(col * DX, 0, row * DZ)
	m:PivotTo(CFrame.new(at))
	m.Parent = stage
	local ok, err = pcall(apply, m, tpl)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 30)
	tag.StudsOffset = Vector3.new(0, 4.5, 0)
	tag.AlwaysOnTop = true
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0
	tl.TextScaled = true
	tl.Text = key
	tl.Parent = tag
	tag.Parent = m:FindFirstChild("Head")
	table.insert(out, string.format("%s at row %d col %d (%.0f,%.0f,%.0f)%s", key, row, col, at.X, at.Y, at.Z, if ok then "" else " FAIL " .. tostring(err)))
end
return table.concat(out, "\n")
