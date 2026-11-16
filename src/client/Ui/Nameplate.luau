--!strict
-- Nameplate - the plate over each hero on a pedestal (design/ui/Nameplate.json,
-- a BillboardGui authored at 350 x 150 px and sized in studs over the hero).
--
-- Detailed like the big simulators, and readable from across a plot:
--   * the rarity word in its colour (Mythic / Secret: an animated colour
--     gradient, an engine tween, no per-frame Lua)
--   * the hero's name, bold white with a dark outline
--   * one centred row of tags: size (TITAN / HUGE / BIG), mutation in its own
--     colour, and the fuse stars; the row is hidden when there are none
--   * the income BIG and green with the yen icon, "+1.2K/s"
-- A plate pops in softly when its hero appears. The plate the camera is aimed
-- at (HeroController:_refocus sets `plate.focused`) grows a little.
--
-- HeroController owns WHEN (which heroes have plates, hiding them all during a
-- throw through plate.gui.Enabled); this module owns WHAT a plate shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)

local MAPS = Lookup.of(Config)

local Nameplate = {}

Nameplate.STUDS = 7 -- plate width over a normal-size hero
Nameplate.DISTANCE = 45 -- plates show this close to the camera
local FOCUS_GROW = 1.12
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PREMIUM = Color3.fromHex("FF4FA3")
local CYCLE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF4D6D")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFB020")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFE14D")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4ADE80")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("38BDF8")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("A855F7")),
})

export type Plate = {
	gui: BillboardGui,
	scale: UIScale,
	width: number,
	studsWide: number,
	studsHigh: number,
	headTop: number,
	name: TextLabel,
	income: TextLabel,
	focused: boolean,
	shown: boolean,
}

-- (rarity name or nil for a premium hero, its colour)
local function rarityOf(id: string): (string?, Color3)
	local character = MAPS.character[id]
	if character and Config.Rarities[character.Rarity] then
		return character.Rarity, Color3.fromHex(Config.Rarities[character.Rarity].Color)
	end
	return nil, PREMIUM
end

local function displayName(id: string): string
	local row = MAPS.character[id] or MAPS.premium[id]
	return if row then row.Name else id
end

-- the rarity word: its colour, or a turning colour gradient for the top tiers
local function paintRarity(label: TextLabel, rarity: string?, colour: Color3)
	label.Text = if rarity then rarity:upper() else "PREMIUM"
	local old = label:FindFirstChild("TierCycle")
	if rarity == "Mythic" or rarity == "Secret" then
		label.TextColor3 = Color3.new(1, 1, 1)
		if not old then
			local gradient = Instance.new("UIGradient")
			gradient.Name = "TierCycle"
			gradient.Color = CYCLE
			gradient.Parent = label
			TweenService:Create(
				gradient,
				TweenInfo.new(
					if rarity == "Secret" then 2 else 3,
					Enum.EasingStyle.Linear,
					Enum.EasingDirection.In,
					-1
				),
				{ Rotation = 360 }
			):Play()
		end
	else
		if old then
			old:Destroy()
		end
		-- the Secret colour is black: anything that dark reads as a light grey word
		local _, _, v = colour:ToHSV()
		label.TextColor3 = if v < 0.25 then Color3.fromHex("C9CDF5") else colour
	end
end

--- Keep the plate's contents the size of the plate on screen.
function Nameplate.fit(plate: Plate)
	local target = math.clamp(plate.gui.AbsoluteSize.X / plate.width, 0.05, 1.5)
	if math.abs(plate.scale.Scale - target) > 0.03 * target then
		plate.scale.Scale = target
	end
end

local function size(plate: Plate)
	local grow = if plate.focused then FOCUS_GROW else 1
	return UDim2.fromScale(plate.studsWide * grow, plate.studsHigh * grow)
end

--- What a plate says (and its size: a little bigger while focused).
function Nameplate.write(plate: Plate, entry: any)
	local gui = plate.gui
	local id = tostring(entry.id or "")
	plate.name.Text = displayName(id)
	plate.income.Text = `+{Format.short(tonumber(entry.i) or 0)}/s`
	local rarity, colour = rarityOf(id)
	paintRarity(Screens.label(gui, "RarityText"), rarity, colour)
	local sizeName = if typeof(entry.z) == "string" then entry.z else nil
	local mutation = if typeof(entry.m) == "string" then entry.m else nil
	local stars = tonumber(entry.st) or 0
	Screens.frame(gui, "SizeTagCell").Visible = sizeName ~= nil
	Screens.label(gui, "SizeText").Text = if sizeName then sizeName:upper() else ""
	Screens.frame(gui, "MutationTagCell").Visible = mutation ~= nil
	Screens.label(gui, "MutationText").Text = if mutation then mutation:upper() else ""
	Screens.tint(Screens.frame(gui, "MutationTag"), Theme.mutation(mutation))
	for star = 1, 3 do
		Screens.image(gui, "Star" .. star).Visible = star <= stars
	end
	Screens.frame(gui, "Stars").Visible = stars > 0
	Screens.frame(gui, "TagRow").Visible = sizeName ~= nil or mutation ~= nil or stars > 0
	if plate.shown then
		TweenService:Create(gui, POP, { Size = size(plate) }):Play()
	end
	gui.StudsOffsetWorldSpace = Vector3.new(0, plate.headTop + 0.4 + plate.studsHigh / 2, 0)
end

--- The plate over `model` (a hero just built, `scale` its size), for `entry`
--- ({ id, i, m, z, st, u, s }). `hidden` starts it disabled (a throw is
--- playing). Parented under the model's root. Nil when there is no root or
--- no Nameplate tree.
function Nameplate.make(model: Model, entry: any, scale: number, hidden: boolean): Plate?
	local root = model.PrimaryPart
	local gui = Screens.world("Nameplate")
	if not root or not gui or not gui:IsA("BillboardGui") then
		return nil
	end
	local canvas = Screens.frame(gui, "CanvasFrame")
	local refWidth = canvas:GetAttribute("RefWidth")
	local refHeight = canvas:GetAttribute("RefHeight")
	local width = if typeof(refWidth) == "number" then refWidth else 350
	local height = if typeof(refHeight) == "number" then refHeight else 150
	local studsWide = Nameplate.STUDS * (1 + (scale - 1) * 0.5)
	local box, extents = model:GetBoundingBox()
	gui.StudsOffset = Vector3.zero
	gui.MaxDistance = Nameplate.DISTANCE
	gui.LightInfluence = 0
	gui.Adornee = root
	gui.Enabled = not hidden
	-- the canvas keeps its authored pixel size, hangs from the top of the
	-- plate, and is scaled to the plate's size on screen
	canvas.AnchorPoint = Vector2.new(0.5, 0)
	canvas.Position = UDim2.fromScale(0.5, 0)
	canvas.Size = UDim2.fromOffset(width, height)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "PlateScale"
	uiScale.Parent = canvas

	local made: Plate = {
		gui = gui,
		scale = uiScale,
		width = width,
		studsWide = studsWide,
		studsHigh = studsWide * height / width,
		headTop = box.Position.Y + extents.Y / 2 - root.Position.Y,
		name = Screens.label(gui, "HeroName"),
		income = Screens.label(gui, "YenPerSecond"),
		focused = false,
		shown = false,
	}
	Nameplate.write(made, entry)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		Nameplate.fit(made)
	end)
	-- a soft pop as the hero appears
	gui.Size = UDim2.fromScale(studsWide * 0.35, made.studsHigh * 0.35)
	gui.Parent = root
	made.shown = true
	TweenService:Create(gui, POP, { Size = size(made) }):Play()
	return made
end

return Nameplate
