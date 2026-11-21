-- build_aura_showcase.luau - Studio EDIT mode. Builds Workspace.AuraShowcase: ONE mannequin per aura,
-- wearing that aura, on a big platform. No anime characters stand here: the owner gives an aura to
-- heroes by renaming mannequins (v2, 2026-11-18).
-- Run through tools/studio/aura_showcase.py (it embeds _G.SHOWCASE); never by hand.
--
--   AuraShowcase/Auras/<AuraKey>   a mannequin wearing that aura (attr AuraKey). RENAME it to a hero's
--                                  name (several heroes: "Hero A, Hero B"; or Ctrl+D the mannequin and
--                                  rename the copy), then `python tools/studio/aura_showcase.py sync`.
--   The back of the platform is empty room for more mannequins and more heroes later.
--
-- It floats far west of the map and is DEV ONLY: the server deletes it on start (src/server/init),
-- so no player ever loads it.
local spec = _G.SHOWCASE
assert(spec, "_G.SHOWCASE missing: run tools/studio/aura_showcase.py build")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local heroAuraModule
for _, d in game:GetService("StarterPlayer").StarterPlayerScripts:GetDescendants() do
	if d:IsA("ModuleScript") and d.Name == "HeroAura" then
		heroAuraModule = d
	end
end
local HeroAura = require(heroAuraModule)
local chars = RS.Assets.Characters
local hand = SS:FindFirstChild("ImportedVfx") and SS.ImportedVfx:FindFirstChild("HandPicked")

local old = workspace:FindFirstChild("AuraShowcase")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "AuraShowcase"
root:SetAttribute("DevOnly", true)
local origin = Vector3.new(spec.origin[1], spec.origin[2], spec.origin[3])

local function part(name, size, cf, color, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function sign(parent, adornee, lines, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(10, 2.6)
	gui.StudsOffsetWorldSpace = adornee.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(24, 20, 48)
	t.BackgroundTransparency = 0.15
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = table.concat(lines, "\n")
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = t
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = t
	t.Parent = gui
	gui.Parent = parent
end

local function still(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end

local function stand(parent, name, at, color)
	local m = Instance.new("Model")
	m.Name = name
	local base = part("Stand", Vector3.new(1, 7, 7), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, m,
		Enum.PartType.Cylinder)
	m.PrimaryPart = base
	m.Parent = parent
	return m, base
end

local function placeHero(model, at)
	-- the template's pivot is its soles and it faces -Z: toward the readme and the viewer
	model:PivotTo(CFrame.new(at + Vector3.new(0, 0.5, 0)))
end

-- the floor: the auras, then SPARE_ROWS of empty room
-- one stand per figure, in ranking order (see aura_showcase.py): every hero, wearing its aura or none,
-- then one mannequin per aura nobody wears
local auraByKey = {}
for _, a in spec.auras do
	auraByKey[a.key] = a
end
local entries = spec.entries
local cols = 10
local pitch = 14
local SPARE_ROWS = 10
local auraRows = math.ceil(#entries / cols)
local depth = (auraRows + SPARE_ROWS + 2) * pitch + 20
local width = cols * pitch + 40
part("Floor", Vector3.new(width, 2, depth), CFrame.new(origin + Vector3.new(0, -1, depth / 2 - 10)),
	Color3.fromRGB(64, 58, 96), root)
local readme = part("Readme", Vector3.new(2, 2, 2), CFrame.new(origin + Vector3.new(0, 4, -14)),
	Color3.fromRGB(255, 214, 64), root)
sign(readme, readme, {
	"AURA SHOWCASE (Studio only, removed when the game runs)",
	"Each stand: an aura on the heroes who wear it (a mannequin if nobody does).",
	"To change an aura: rename a stand to a hero name (Hero A, Hero B).",
	"Then ask Claude to 'sync the aura showcase'.",
}, Color3.fromRGB(255, 214, 64), 6)
readme.Transparency = 1

local auras = Instance.new("Folder")
auras.Name = "Auras"
auras.Parent = root

local made, failed = 0, {}

-- a mannequin: the lane rig with clothes, hair and accessories off, a smooth pale body and a real
-- round head. (The hero templates keep their head MeshPart invisible: the head is an accessory, so
-- stripping accessories left v1's dummy headless.)
local dummyTemplate = chars:FindFirstChild("Char_" .. spec.dummy)
local SKIN = Color3.fromRGB(214, 218, 232)
local JOINT = Color3.fromRGB(150, 156, 184)
local function dummy()
	local d = dummyTemplate:Clone()
	for _, x in d:GetDescendants() do
		if x:IsA("Accessory") or x:IsA("Clothing") or x:IsA("ShirtGraphic") or x:IsA("Decal") then
			x:Destroy()
		elseif x:IsA("SurfaceAppearance") then
			x:Destroy()
		end
	end
	for _, x in d:GetDescendants() do
		if x:IsA("BasePart") and x.Name ~= "Head" and x.Name ~= "HumanoidRootPart" then
			x.Color = SKIN
			x.Material = Enum.Material.SmoothPlastic
			if x:IsA("MeshPart") then
				pcall(function()
					x.TextureID = ""
				end)
			end
		end
	end
	-- joints a shade darker, like a wooden artist's mannequin
	for _, n in { "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
		local j = d:FindFirstChild(n)
		if j and j:IsA("BasePart") then
			j.Color = JOINT
		end
	end
	local head = d:FindFirstChild("Head") :: BasePart
	local ball = Instance.new("Part")
	ball.Name = "MannequinHead"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.35, 1.35, 1.35)
	ball.Color = SKIN
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CFrame = head.CFrame * CFrame.new(0, 0.02, 0)
	ball.Parent = d
	-- a little neck ring and a calm face band so it reads as a head from any side
	local neck = Instance.new("Part")
	neck.Name = "MannequinNeck"
	neck.Shape = Enum.PartType.Cylinder
	neck.Size = Vector3.new(0.35, 0.55, 0.55)
	neck.Color = JOINT
	neck.Material = Enum.Material.SmoothPlastic
	neck.Anchored = true
	neck.CanCollide = false
	neck.CFrame = head.CFrame * CFrame.new(0, -0.62, 0) * CFrame.Angles(0, 0, math.rad(90))
	neck.Parent = d
	local band = Instance.new("Part")
	band.Name = "MannequinFace"
	band.Size = Vector3.new(0.75, 0.16, 0.1)
	band.Color = JOINT
	band.Material = Enum.Material.SmoothPlastic
	band.Anchored = true
	band.CanCollide = false
	band.CFrame = head.CFrame * CFrame.new(0, 0.06, -0.62)
	band.Parent = d
	return d
end

for i, e in entries do
	local a = auraByKey[e.key]
	local c = (i - 1) % cols
	local r = math.floor((i - 1) / cols)
	local at = origin + Vector3.new(((cols - 1) / 2 - c) * pitch, 0, r * pitch) -- reads left to right from the readme
	local color = Color3.fromHex(e.color)
	local hasHero = e.id ~= ""
	local label = if hasHero then e.name else e.key
	local m, base = stand(auras, label, at, color)
	m:SetAttribute("AuraKey", e.key)
	m:SetAttribute("Label", label)
	m:SetAttribute("Rank", e.rank)
	if a then
		m:SetAttribute("Source", a.source)
	end
	local template = hasHero and chars:FindFirstChild("Char_" .. e.id)
	local d
	if template then
		d = template:Clone()
		d.Name = e.id
		m:SetAttribute("Hero", e.id)
	else
		d = dummy()
	end
	d.Parent = m
	placeHero(d, at)
	still(d)
	local wearing = if hasHero then label else "worn by nobody"
	if not a then
		-- no aura yet
	elseif a.template then
		local ok, err = pcall(HeroAura.attach, d, a.key, 1, 1)
		if not ok then
			table.insert(failed, a.key .. ": " .. tostring(err))
		end
	elseif hand and hand:FindFirstChild(a.source) then
		-- not converted (no body rig in the pack): the raw effect, scripts and sounds stripped, at the chest
		local raw = hand:FindFirstChild(a.source):Clone()
		for _, x in raw:GetDescendants() do
			if x:IsA("LuaSourceContainer") or x:IsA("Sound") or x:IsA("LayerCollector") or x:IsA("JointInstance") then
				x:Destroy()
			end
		end
		local chest = d:FindFirstChild("UpperTorso")
		if raw:IsA("BasePart") then
			raw.Anchored = true
			raw.CanCollide = false
			raw.Transparency = 1
			raw.CFrame = chest.CFrame
		else
			for _, x in raw:GetDescendants() do
				if x:IsA("BasePart") then
					x.Anchored = true
					x.CanCollide = false
				end
			end
			local cf = raw:IsA("Model") and raw:GetBoundingBox() or nil
			if cf then
				raw:PivotTo(raw:GetPivot() + (chest.Position - cf.Position))
			end
		end
		raw.Name = "RawAura"
		raw.Parent = m
		wearing = wearing .. " (raw)"
	end
	local second = if a then a.key else "no aura"
	if hasHero then
		second = e.rank .. " - " .. second
	end
	sign(m, base, { wearing, second }, color, 8)
	made += 1
end

root.Parent = workspace
return string.format("showcase: %d stands, %d failed%s", made, #failed,
	#failed > 0 and ("\n" .. table.concat(failed, "\n")) or "")
