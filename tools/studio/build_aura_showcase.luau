-- build_aura_showcase.luau - Studio EDIT mode. Builds Workspace.AuraShowcase: the owner's view of
-- every hero wearing the aura the game gives it, and every hand-picked aura on a plain dummy.
-- Run through tools/studio/aura_showcase.py (it embeds _G.SHOWCASE); never by hand.
--
--   AuraShowcase/ByHero/<Hero Name>   the hero, its aura, a sign: rarity and aura key   (look only)
--   AuraShowcase/Auras/<AuraKey>      a grey dummy wearing that aura (attr AuraKey)      RENAME ONE to a
--                                     hero's name, then `python tools/studio/aura_showcase.py sync`
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
	gui.Size = UDim2.fromScale(9, 2.6)
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

-- the floor
local cols = 10
local pitch = 14
local heroRows = math.ceil(#spec.heroes / cols)
local auraRows = math.ceil(#spec.auras / cols)
local depth = (heroRows + auraRows + 3) * pitch + 20
local width = cols * pitch + 20
part("Floor", Vector3.new(width, 2, depth), CFrame.new(origin + Vector3.new(0, -1, depth / 2 - 10)),
	Color3.fromRGB(64, 58, 96), root)
local readme = part("Readme", Vector3.new(2, 2, 2), CFrame.new(origin + Vector3.new(0, 4, -14)),
	Color3.fromRGB(255, 214, 64), root)
sign(readme, readme, {
	"AURA SHOWCASE (Studio only, removed when the game runs)",
	"Front rows: every hero with the aura it wears in game.",
	"Back rows: every hand-picked aura on a dummy. Rename a dummy",
	"to a hero's name, then ask Claude to 'sync the aura showcase'.",
}, Color3.fromRGB(255, 214, 64), 6)
readme.Transparency = 1

local byHero = Instance.new("Folder")
byHero.Name = "ByHero"
byHero.Parent = root
local auras = Instance.new("Folder")
auras.Name = "Auras"
auras.Parent = root

local made, failed = 0, {}
for i, h in spec.heroes do
	local c = (i - 1) % cols
	local r = math.floor((i - 1) / cols)
	local at = origin + Vector3.new((c - (cols - 1) / 2) * pitch, 0, r * pitch)
	local color = Color3.fromHex(h.color)
	local m, base = stand(byHero, h.name, at, color)
	m:SetAttribute("HeroId", h.id)
	m:SetAttribute("AuraKey", h.aura or "")
	local tpl = chars:FindFirstChild("Char_" .. h.id)
	if tpl then
		local hero = tpl:Clone()
		hero.Parent = m
		placeHero(hero, at)
		still(hero)
		if h.aura then
			local ok, err = pcall(HeroAura.attach, hero, h.aura, 1, 1)
			if not ok then
				table.insert(failed, h.id .. ": " .. tostring(err))
			end
		end
	end
	sign(m, base, { h.name, h.rarity .. "  |  " .. (h.aura or "no aura") }, color, 8)
	made += 1
end

-- a plain grey dummy: a lane hero's rig with its clothes and accessories off
local dummyTemplate = chars:FindFirstChild("Char_" .. spec.dummy)
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
		if x:IsA("BasePart") then
			x.Color = Color3.fromRGB(190, 190, 200)
			x.Material = Enum.Material.SmoothPlastic
			if x:IsA("MeshPart") then
				pcall(function()
					x.TextureID = ""
				end)
			end
		end
	end
	return d
end

local z0 = (heroRows + 1) * pitch
for i, a in spec.auras do
	local c = (i - 1) % cols
	local r = math.floor((i - 1) / cols)
	local at = origin + Vector3.new((c - (cols - 1) / 2) * pitch, 0, z0 + r * pitch)
	local color = Color3.fromHex(a.color)
	local m, base = stand(auras, a.key, at, color)
	m:SetAttribute("AuraKey", a.key)
	m:SetAttribute("Source", a.source)
	local d = dummy()
	d.Parent = m
	placeHero(d, at)
	still(d)
	local wearing = a.users > 0 and (a.users .. " hero" .. (if a.users == 1 then "" else "es")) or "worn by nobody"
	if a.template then
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
		wearing = wearing .. " (raw: converted when assigned)"
	end
	sign(m, base, { a.key, a.source .. "  |  " .. wearing }, color, 8)
	made += 1
end

root.Parent = workspace
return string.format("showcase: %d stands, %d failed%s", made, #failed,
	#failed > 0 and ("\n" .. table.concat(failed, "\n")) or "")
