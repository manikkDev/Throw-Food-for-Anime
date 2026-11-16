--!strict
-- UiFx - the moving parts of the UI, on ONE shared loop.
--
--   * bursts: every `Sunburst` / `Glow` / `Burst` / `Rays` / `Halo` image turns
--     and breathes, more with rarity (Common still, Rare a slow turn, Epic turn
--     + pulse, Legendary gold, Mythic / Secret colour-cycling). An image can
--     override its turn with the attribute `FxTurn` (degrees per second,
--     negative turns the other way) and its pulse with `FxPulse`.
--   * sparkles: every `Sparkle*` / `Twinkle*` star twinkles
--   * risers: every `Flame*` / `Petal*` / `Ember*` sprite rises through its
--     parent and fades, then starts again (auras, petals around featured cards)
--   * rarity card frames: tiered animated borders, surface patterns that
--     shimmer, a glow from Legendary, a shine on HOVER only (styleCard)
--   * shines: the soft gloss streak that sweeps across a button on hover
--     (sweep), and the permanent gloss layer on every button (makeGloss)
--
-- The loop is connected ONLY while something asks for it (a page is open, or a
-- HUD moment is on screen: activate(key, true)), steps at 30 Hz and touches
-- only records whose whole ancestry is visible in an enabled gui. With every
-- page closed and no moment up, nothing runs per frame.
--
-- WHY THE FLARES USED TO STOP AFTER A FEW SECONDS (v4.2): the records lived in
-- WEAK-KEYED tables keyed by the ImageLabel. Roblox hands Luau a userdata
-- wrapper per Instance, and when no script holds that wrapper the garbage
-- collector frees it even though the Instance is still in the PlayerGui; the
-- weak entry goes with it. Nothing else referenced a flare, so every record
-- vanished at the next GC cycle and its image froze where it was. The tables
-- are strong now; a record is dropped when its image is Destroyed (or loses
-- its parent), which is the real end of its life.
--
-- This module must not require Screens (Screens requires it).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiFx = {}

local STEP = 1 / 30
local GOLD = Color3.fromHex("FFD45C")

type Tier = { turn: number, pulse: number, colour: string? }

-- degrees per second, pulse (size fraction), colour mode
local TIERS: { [string]: Tier } = {
	Common = { turn = 4, pulse = 0 },
	Uncommon = { turn = 6, pulse = 0.02 },
	Rare = { turn = 10, pulse = 0.03 },
	Epic = { turn = 16, pulse = 0.05 },
	Legendary = { turn = 22, pulse = 0.07, colour = "gold" },
	Mythic = { turn = 28, pulse = 0.08, colour = "cycle" },
	Secret = { turn = 34, pulse = 0.09, colour = "cycle" },
	Premium = { turn = 22, pulse = 0.07, colour = "gold" },
	Default = { turn = 8, pulse = 0.025 },
}

type Record = {
	kind: string, -- "burst" | "sparkle" | "riser"
	tier: Tier,
	rot: number,
	size: UDim2,
	pos: UDim2,
	alpha: number,
	colour: Color3,
	phase: number,
	turn: number?, -- FxTurn override
	pulse: number?, -- FxPulse override
	period: number, -- a riser's loop length
}

local records: { [ImageLabel]: Record } = {}
local strokes: { [UIGradient]: number } = {}
local patterns: { [UIGradient]: { drift: number, cycle: boolean, image: ImageLabel } } = {}
local glows: { [UIStroke]: { colour: Color3, cycle: boolean } } = {}
local active: { [string]: boolean } = {}
local connection: RBXScriptConnection? = nil
local acc = 0

local BURST_NAMES = { Sunburst = true, Glow = true, Burst = true, Rays = true, Halo = true }

local function kindOf(name: string): string?
	-- RaysBack / RaysFront and CardGlow: the purchase celebration's layers (Ui/Celebrate)
	if
		BURST_NAMES[name]
		or name:match("^Glow%d+$")
		or name:match("^Rays%d+$")
		or name:match("^Rays%u%l+$")
		or name == "CardGlow"
	then
		return "burst"
	elseif name:match("^Sparkle%d*$") or name:match("^Twinkle%d*$") then
		return "sparkle"
	elseif name:match("^Flame%d*$") or name:match("^Petal%d*$") or name:match("^Ember%d*$") then
		return "riser"
	end
	return nil
end

local function tierOf(rarity: string?): Tier
	return (if rarity then TIERS[rarity] else nil) or TIERS.Default
end

local function register(d: ImageLabel, kind: string)
	if records[d] then
		return
	end
	local turn = d:GetAttribute("FxTurn")
	local pulse = d:GetAttribute("FxPulse")
	records[d] = {
		kind = kind,
		tier = TIERS.Default,
		rot = d.Rotation,
		size = d.Size,
		pos = d.Position,
		alpha = d.ImageTransparency,
		colour = d.ImageColor3,
		phase = math.random() * math.pi * 2,
		turn = if typeof(turn) == "number" then turn else nil,
		pulse = if typeof(pulse) == "number" then pulse else nil,
		period = 1.6 + math.random() * 1.2,
	}
	d.Destroying:Once(function()
		records[d] = nil
	end)
end

--- Register the flares, sparkles and risers under `root` (a screen, a row or
--- card clone, or a moment built in code). Idempotent.
function UiFx.scan(root: Instance)
	local function look(d: Instance)
		if d:IsA("ImageLabel") then
			local kind = kindOf(d.Name)
			if kind then
				register(d, kind)
			end
		end
	end
	look(root)
	for _, d in root:GetDescendants() do
		look(d)
	end
end

--- Say which rarity the flares under `holder` belong to (nil: the default
--- gentle turn). Restores the shipped colour when the tier has none.
function UiFx.setRarity(holder: Instance, rarity: string?)
	local tier = tierOf(rarity)
	local function look(d: Instance)
		local rec = if d:IsA("ImageLabel") then records[d] else nil
		if rec and rec.tier ~= tier then
			rec.tier = tier
			if not tier.colour then
				d.ImageColor3 = rec.colour
			end
			d.Size = rec.size
			d.Rotation = rec.rot
		end
	end
	look(holder)
	for _, d in holder:GetDescendants() do
		look(d)
	end
end

--- Recolour the flares under `holder` (their resting colour; a gold / cycling
--- tier still paints over it).
function UiFx.setColour(holder: Instance, colour: Color3)
	local function look(d: Instance)
		local rec = if d:IsA("ImageLabel") then records[d] else nil
		if rec then
			rec.colour = colour
			d.ImageColor3 = colour
		end
	end
	look(holder)
	for _, d in holder:GetDescendants() do
		look(d)
	end
end

-- -------------------------------------------------------------- the loop --

-- visibility of an ancestor chain, memoised for one step
local seen: { [Instance]: boolean } = {}

local function shown(node: Instance): boolean
	local memo = seen[node]
	if memo ~= nil then
		return memo
	end
	local result: boolean
	if node:IsA("LayerCollector") then
		result = node.Enabled
	elseif node:IsA("GuiObject") then
		local parent = node.Parent
		result = node.Visible and parent ~= nil and shown(parent)
	else
		-- a Folder or the PlayerGui: transparent to visibility, but must lead to a gui
		local parent = node.Parent
		result = parent ~= nil and not parent:IsA("DataModel") and shown(parent)
	end
	seen[node] = result
	return result
end

local function scaled(size: UDim2, s: number): UDim2
	return UDim2.new(size.X.Scale * s, size.X.Offset * s, size.Y.Scale * s, size.Y.Offset * s)
end

local function step(dt: number)
	table.clear(seen)
	local now = os.clock()
	for image, rec in records do
		if not image.Parent then
			records[image] = nil
			continue
		end
		if not shown(image) then
			continue
		end
		local tier = rec.tier
		local t = now + rec.phase
		if rec.kind == "sparkle" then
			local k = 0.5 + 0.5 * math.sin(t * 2.6)
			image.ImageTransparency = rec.alpha + (1 - rec.alpha) * 0.6 * (1 - k)
			image.Rotation = rec.rot + math.sin(t * 1.3) * 18
			image.Size = scaled(rec.size, 0.78 + 0.34 * k)
		elseif rec.kind == "riser" then
			-- rise one parent-height-ish (40% of the parent), fade in then out, loop
			local u = ((now + rec.phase) % rec.period) / rec.period
			image.Position = rec.pos - UDim2.fromScale(0, 0.4 * u)
			local fade = if u < 0.2 then u / 0.2 else 1 - (u - 0.2) / 0.8
			image.ImageTransparency = 1 - (1 - rec.alpha) * fade
			image.Size = scaled(rec.size, 1 - 0.35 * u)
			image.Rotation = rec.rot + math.sin(t * 2) * 10
			if tier.colour == "cycle" then
				image.ImageColor3 = Color3.fromHSV((now * 0.12 + rec.phase * 0.1) % 1, 0.5, 1)
			end
		else
			local turn = rec.turn or tier.turn
			if turn ~= 0 then
				image.Rotation = (rec.rot + now * turn) % 360
			end
			local pulse = rec.pulse or tier.pulse
			if pulse > 0 then
				local s = 1 + pulse * math.sin(t * 2.2)
				image.Size = scaled(rec.size, s)
				image.ImageTransparency =
					math.clamp(rec.alpha + 0.12 * (0.5 - 0.5 * math.sin(t * 2.2)), 0, 1)
			end
			if tier.colour == "gold" then
				image.ImageColor3 = GOLD
			elseif tier.colour == "cycle" then
				image.ImageColor3 = Color3.fromHSV((now * 0.12 + rec.phase * 0.1) % 1, 0.5, 1)
			end
		end
	end
	for gradient, speed in strokes do
		if not gradient.Parent then
			strokes[gradient] = nil
		elseif shown(gradient.Parent) then
			gradient.Rotation = (gradient.Rotation + speed * dt) % 360
		end
	end
	for gradient, beat in patterns do
		if not gradient.Parent then
			patterns[gradient] = nil
		elseif shown(beat.image) then
			if beat.drift > 0 then
				gradient.Offset = Vector2.new(((now * beat.drift) % 2.4) - 1.2, 0)
			end
			if beat.cycle then
				beat.image.ImageColor3 = Color3.fromHSV((now * 0.08) % 1, 0.45, 1)
			end
		end
	end
	for stroke, beat in glows do
		if not stroke.Parent then
			glows[stroke] = nil
		elseif shown(stroke.Parent) then
			stroke.Transparency = 0.55 + 0.25 * (0.5 + 0.5 * math.sin(now * 2.4))
			if beat.cycle then
				stroke.Color = Color3.fromHSV((now * 0.15) % 1, 0.6, 1)
			end
		end
	end
end

local function refresh()
	local want = next(active) ~= nil
	if want and not connection then
		acc = 0
		connection = RunService.Heartbeat:Connect(function(dt: number)
			acc += dt
			if acc >= STEP then
				local elapsed = math.min(acc, 0.25)
				acc = 0
				step(elapsed)
			end
		end)
	elseif not want and connection then
		connection:Disconnect()
		connection = nil
	end
end

--- Ask for the loop under `key` (a page is open, a HUD moment is up) or let
--- go of it. The loop runs while any key holds it.
function UiFx.activate(key: string, on: boolean)
	active[key] = if on then true else nil
	refresh()
end

--- True while the loop runs (for tests and the dev panel).
function UiFx.running(): boolean
	return connection ~= nil
end

-- ------------------------------------------------------------- level --

--- v4.5 (owner's review 6: "the announcement bar is slanted"). Put `root` and
--- everything under it back to its designed angle: the root (a moment's bar,
--- card, toast or dialog) at exactly 0, every descendant at the Rotation it
--- shipped with (kept as a "ShipRotation" attribute the first time it is
--- seen), except the flares, sparkles and risers this module turns on purpose.
--- Called by every HUD moment as it comes in, so no entrance, pop or shake
--- can ever leave a moment tilted.
function UiFx.level(root: GuiObject)
	root.Rotation = 0
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") and not (d:IsA("ImageLabel") and (records[d] or kindOf(d.Name))) then
			local ship = d:GetAttribute("ShipRotation")
			if typeof(ship) ~= "number" then
				ship = d.Rotation
				d:SetAttribute("ShipRotation", ship)
			end
			if d.Rotation ~= ship then
				d.Rotation = ship :: number
			end
		end
	end
end

-- ------------------------------------------------------------- shines --

-- A soft, wide gloss streak: a bell of light, never a hard bar.
local SHINE_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 1),
	NumberSequenceKeypoint.new(0.4, 0.9),
	NumberSequenceKeypoint.new(0.46, 0.74),
	NumberSequenceKeypoint.new(0.5, 0.66),
	NumberSequenceKeypoint.new(0.54, 0.74),
	NumberSequenceKeypoint.new(0.6, 0.9),
	NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local SHINE_FROM = Vector2.new(-1, 0)
local SHINE_TO = Vector2.new(1, 0)
local SHINE_LEAN = math.rad(20) -- how far the streak leans from upright, ON SCREEN
local sweeping: { [UIGradient]: Tween } = {}

-- A UIGradient's Rotation is applied in the element's 0..1 box, so on a wide
-- button a fixed angle lies almost flat (18 degrees on a 358 x 48 pill drew a
-- streak 22 degrees off horizontal: the "slanted" toast). This is the rotation
-- that leans the streak SHINE_LEAN off upright in PIXELS for this shape.
local function leanFor(frame: GuiObject, lean: number?): number
	if lean == 0 then
		return 0 -- an upright streak (a thin bar: a leaning one reads as the bar being tilted)
	end
	local size = frame.AbsoluteSize
	local w = if size.X > 0 then size.X else frame.Size.X.Offset
	local h = if size.Y > 0 then size.Y else frame.Size.Y.Offset
	if w <= 0 or h <= 0 then
		return 6
	end
	local radians = if lean then math.rad(lean) else SHINE_LEAN
	return math.deg(math.atan(math.tan(radians) * h / w))
end

local function overlay(
	name: string,
	face: GuiObject,
	parent: Instance,
	fill: boolean?,
	z: number
): Frame
	local found = parent:FindFirstChild(name)
	if found and found:IsA("Frame") then
		return found
	end
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.BackgroundColor3 = Color3.new(1, 1, 1)
	layer.BorderSizePixel = 0
	layer.Active = false
	pcall(function()
		(layer :: any).Interactable = false
	end)
	if fill then
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = 20
	else
		layer.Size = face.Size
		layer.Position = face.Position
		layer.AnchorPoint = face.AnchorPoint
		layer.ZIndex = face.ZIndex + z
	end
	local corner = face:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = layer
	end
	layer.Parent = parent
	return layer
end

--- A soft shine streak the shape of `face` (its rounded corners), as a sibling
--- in `parent` laid exactly over the face (or inside `parent` filling it when
--- `fill` is set). Invisible until swept. Reuses one named "Shine".
function UiFx.makeShine(face: GuiObject, parent: Instance, fill: boolean?): Frame
	local existing = parent:FindFirstChild("Shine")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local shine = overlay("Shine", face, parent, fill, 2)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "ShineGradient"
	gradient.Rotation = 6
	gradient.Transparency = SHINE_ALPHA
	gradient.Offset = SHINE_FROM
	gradient.Parent = shine
	return shine
end

-- the permanent gloss: a light top half fading out by the middle, a soft
-- shade along the bottom (white over the top, black under the bottom)
local GLOSS_COLOUR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.56, Color3.new(0, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
})
local GLOSS_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.6),
	NumberSequenceKeypoint.new(0.14, 0.72),
	NumberSequenceKeypoint.new(0.46, 0.94),
	NumberSequenceKeypoint.new(0.55, 1),
	NumberSequenceKeypoint.new(0.75, 1),
	NumberSequenceKeypoint.new(1, 0.84),
})

--- The glossy look every button wears: a soft highlight over the top half
--- and a soft shade along the bottom edge, laid over the face like the shine.
function UiFx.makeGloss(face: GuiObject, parent: Instance, fill: boolean?): Frame
	local existing = parent:FindFirstChild("Gloss")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local gloss = overlay("Gloss", face, parent, fill, 1)
	if fill then
		gloss.ZIndex = 19
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "GlossGradient"
	gradient.Rotation = 90
	gradient.Color = GLOSS_COLOUR
	gradient.Transparency = GLOSS_ALPHA
	gradient.Parent = gloss
	return gloss
end

--- Sweep a shine (made by makeShine) across once, slowly and softly. A sweep
--- already running is left to finish. `lean` = the streak's lean off upright
--- ON SCREEN, in degrees (default 20; 0 = upright).
function UiFx.sweep(shine: Frame, seconds: number?, lean: number?)
	local gradient = shine:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return
	end
	local running = sweeping[gradient]
	if running and running.PlaybackState == Enum.PlaybackState.Playing then
		return
	end
	gradient.Rotation = leanFor(shine, lean)
	gradient.Offset = SHINE_FROM
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(seconds or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Offset = SHINE_TO }
	)
	sweeping[gradient] = tween
	tween.Completed:Once(function()
		if sweeping[gradient] == tween then
			sweeping[gradient] = nil
			-- parked off the face and level: nothing of a swept streak stays tilted
			gradient.Offset = SHINE_FROM
			gradient.Rotation = 0
		end
	end)
	tween:Play()
end

-- ------------------------------------------------------- rarity cards --
--
-- v4.3 (owner's review 4: "made in a hurry, not flashy enough"). Each tier has
-- its own frame, its own surface and its own motion, and the low tiers stay
-- quiet on purpose:
--   Common     a plain white frame, no pattern
--   Uncommon   a soft mint frame, faint dots
--   Rare       a soft blue gradient drifting round the frame, dots with a slow shimmer
--   Epic       a light CHASE: one bright run racing round a violet frame, a starfield
--   Legendary  a turning gold frame, a pulsing gold glow outside it, gold rays inside
--   Mythic     a multicolour frame turning fast, a colour-cycling glow and sakura
--   Secret     the full rainbow, the fastest turn, a cycling glow and a cycling starfield
-- The card's shine streak crosses ONLY on hover (1.5 s, Rare and up); it never
-- runs on a timer. Patterns shimmer: a soft bright band drifts across them.

local Icons =
	require(game:GetService("ReplicatedStorage").Shared.Config.Icons) :: { [string]: string }

local function faceOf(card: GuiObject): GuiObject
	local face = card:FindFirstChild("Face")
	return if face and face:IsA("GuiObject") then face else card
end

local function borderOf(face: GuiObject): UIStroke?
	for _, child in face:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			return child
		end
	end
	return nil
end

local function seq(colours: { Color3 }): ColorSequence
	local points = {}
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colours - 1), c))
	end
	return ColorSequence.new(points)
end

local W = Color3.new(1, 1, 1)
local HOVER_SHINE = 1.5

type Pattern = {
	image: string,
	colour: Color3?,
	alpha: number,
	tile: number?,
	drift: number,
	cycle: boolean?,
}
type Look = {
	colours: { Color3 }?,
	points: ColorSequence?,
	solid: Color3?,
	thick: number,
	spin: number,
	shine: boolean?,
	glow: Color3?,
	glowCycle: boolean?,
	pattern: Pattern?,
}

-- the Epic chase: a violet frame with ONE bright run in it
local CHASE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("7C3AED")),
	ColorSequenceKeypoint.new(0.38, Color3.fromHex("A855F7")),
	ColorSequenceKeypoint.new(0.47, Color3.fromHex("F0ABFC")),
	ColorSequenceKeypoint.new(0.5, W),
	ColorSequenceKeypoint.new(0.53, Color3.fromHex("F0ABFC")),
	ColorSequenceKeypoint.new(0.62, Color3.fromHex("A855F7")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("7C3AED")),
})

local FRAMES: { [string]: Look } = {
	Common = { solid = W, thick = 3, spin = 0 },
	Uncommon = {
		solid = Color3.fromHex("B8F5C9"),
		thick = 3,
		spin = 0,
		pattern = {
			image = "pattern_dots",
			colour = Color3.fromHex("B8F5C9"),
			alpha = 0.88,
			tile = 22,
			drift = 0,
		},
	},
	Rare = {
		colours = {
			Color3.fromHex("BAE6FD"),
			Color3.fromHex("38BDF8"),
			W,
			Color3.fromHex("0EA5E9"),
			Color3.fromHex("BAE6FD"),
		},
		thick = 3.5,
		spin = 28,
		shine = true,
		pattern = {
			image = "pattern_dots",
			colour = Color3.fromHex("7DD3FC"),
			alpha = 0.8,
			tile = 22,
			drift = 0.18,
		},
	},
	Epic = {
		points = CHASE,
		thick = 4,
		spin = 150,
		shine = true,
		pattern = {
			image = "BgStars",
			colour = Color3.fromHex("E9C6FF"),
			alpha = 0.74,
			drift = 0.24,
		},
	},
	Legendary = {
		colours = {
			Color3.fromHex("FFF3B0"),
			Color3.fromHex("FFC93C"),
			W,
			Color3.fromHex("F59E0B"),
			Color3.fromHex("FFF3B0"),
		},
		thick = 4,
		spin = 70,
		shine = true,
		glow = Color3.fromHex("FFC93C"),
		pattern = { image = "BgRays", colour = Color3.fromHex("FFD45C"), alpha = 0.74, drift = 0.3 },
	},
	Mythic = {
		colours = {
			Color3.fromHex("FB3B6B"),
			Color3.fromHex("FFB020"),
			W,
			Color3.fromHex("FF4FA3"),
			Color3.fromHex("A855F7"),
			Color3.fromHex("FB3B6B"),
		},
		thick = 4.5,
		spin = 110,
		shine = true,
		glow = Color3.fromHex("FF4FA3"),
		glowCycle = true,
		pattern = { image = "BgSakura", alpha = 0.7, drift = 0.36, cycle = true },
	},
	Secret = {
		colours = {
			Color3.fromHex("FF4D6D"),
			Color3.fromHex("FFE14D"),
			Color3.fromHex("4ADE80"),
			Color3.fromHex("38BDF8"),
			Color3.fromHex("A855F7"),
			Color3.fromHex("FF4D6D"),
		},
		thick = 4.5,
		spin = 160,
		shine = true,
		glow = Color3.fromHex("FFFFFF"),
		glowCycle = true,
		pattern = { image = "BgStars", alpha = 0.66, drift = 0.45, cycle = true },
	},
}
FRAMES.Premium = FRAMES.Legendary

--- A turning colour gradient on a stroke (a premium card frame, a Mythic
--- rarity word): `colours` spin at `speed` degrees per second on the loop.
function UiFx.spinGradient(gradient: UIGradient, speed: number)
	strokes[gradient] = speed
	gradient.Destroying:Once(function()
		strokes[gradient] = nil
	end)
end

--- The colour list of a tier frame (nil below Rare), for other code that
--- wants the same look (the nameplate's rarity word, the reveal card).
function UiFx.tierColours(rarity: string?): { Color3 }?
	local look = if rarity then FRAMES[rarity] else nil
	if look and look.points then
		local out = {}
		for _, point in look.points.Keypoints do
			table.insert(out, point.Value)
		end
		return out
	end
	return if look then look.colours else nil
end

-- the shimmer over a pattern: a soft brighter band drifting across it
local SHIMMER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(0.38, 0.55),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.62, 0.55),
	NumberSequenceKeypoint.new(1, 0.55),
})

local function cornerFrom(from: Instance, to: Instance)
	local corner = from:FindFirstChildOfClass("UICorner")
	if corner and not to:FindFirstChildOfClass("UICorner") then
		corner:Clone().Parent = to
	end
end

-- the tier's surface pattern inside `holder` (under everything else in it)
local function applyPattern(holder: GuiObject, pattern: Pattern?)
	local found = holder:FindFirstChild("TierPattern")
	if not pattern or holder:FindFirstChildWhichIsA("UIGridStyleLayout") then
		if found then
			found:Destroy()
		end
		return
	end
	local image: ImageLabel
	if found and found:IsA("ImageLabel") then
		image = found
	else
		image = Instance.new("ImageLabel")
		image.Name = "TierPattern"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = -1
		image.Active = false
		cornerFrom(holder, image)
		image.Parent = holder
	end
	image.Image = Icons[pattern.image] or ""
	if pattern.tile then
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(pattern.tile, pattern.tile)
	else
		image.ScaleType = Enum.ScaleType.Crop
	end
	image.ImageColor3 = pattern.colour or W
	image.ImageTransparency = pattern.alpha
	local shimmer = image:FindFirstChild("TierShimmer")
	if pattern.drift > 0 or pattern.cycle then
		local gradient = if shimmer and shimmer:IsA("UIGradient")
			then shimmer
			else Instance.new("UIGradient")
		gradient.Name = "TierShimmer"
		gradient.Transparency = SHIMMER
		gradient.Rotation = 20
		gradient.Parent = image
		patterns[gradient] = { drift = pattern.drift, cycle = pattern.cycle == true, image = image }
	elseif shimmer then
		shimmer:Destroy()
	end
end

-- a soft glow ring just outside the card's face (Legendary and up)
local function applyGlow(card: GuiObject, face: GuiObject, look: Look)
	local found = card:FindFirstChild("TierGlow")
	if not look.glow or card == face then
		if found then
			found:Destroy()
		end
		return
	end
	local glow: Frame
	if found and found:IsA("Frame") then
		glow = found
	else
		glow = Instance.new("Frame")
		glow.Name = "TierGlow"
		glow.BackgroundTransparency = 1
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		local p, z = face.Position, face.Size
		glow.Position = UDim2.new(
			p.X.Scale + z.X.Scale / 2,
			p.X.Offset + z.X.Offset / 2,
			p.Y.Scale + z.Y.Scale / 2,
			p.Y.Offset + z.Y.Offset / 2
		)
		glow.Size = z + UDim2.fromOffset(4, 4)
		glow.ZIndex = face.ZIndex - 1
		glow.Active = false
		cornerFrom(face, glow)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "GlowStroke"
		stroke.Thickness = 6
		stroke.Transparency = 0.6
		stroke.Parent = glow
		glow.Parent = card
	end
	local stroke = glow:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = look.glow :: Color3
	glows[stroke] = { colour = look.glow :: Color3, cycle = look.glowCycle == true }
end

local function hoverShine(card: GuiObject, face: GuiObject)
	if card:GetAttribute("TierHover") then
		return
	end
	card:SetAttribute("TierHover", true)
	card.MouseEnter:Connect(function()
		local look = FRAMES[card:GetAttribute("TierStyled") :: string]
		if not look or not look.shine then
			return
		end
		local shine = face:FindFirstChild("Shine")
		if shine and shine:IsA("Frame") then
			UiFx.sweep(shine, HOVER_SHINE)
		end
	end)
end

--- Style a card / tile / row by rarity: its border becomes the tier's frame
--- (see the table above), its face gets the tier's pattern, Legendary and up a
--- glow, and its flares take the tier's motion. The shine crosses on hover only.
function UiFx.styleCard(card: GuiObject, rarity: string?)
	if card:GetAttribute("TierStyled") == (rarity or "") then
		return
	end
	card:SetAttribute("TierStyled", rarity or "")
	UiFx.setRarity(card, rarity)
	local look = (if rarity then FRAMES[rarity] else nil) or FRAMES.Common
	local face = faceOf(card)
	local stroke = borderOf(face)
	if stroke then
		local old = stroke:FindFirstChild("TierGradient")
		local points = look.points or (if look.colours then seq(look.colours) else nil)
		if points then
			stroke.Color = W
			local gradient = if old and old:IsA("UIGradient")
				then old
				else Instance.new("UIGradient")
			gradient.Name = "TierGradient"
			gradient.Color = points
			gradient.Rotation = 45
			gradient.Parent = stroke
			strokes[gradient] = if look.spin > 0 then look.spin else nil
		else
			if old then
				strokes[old :: UIGradient] = nil
				old:Destroy()
			end
			stroke.Color = look.solid or W
		end
		stroke.Thickness = look.thick
	end
	applyPattern(face, look.pattern)
	applyGlow(card, face, look)
	if look.shine and not face:FindFirstChildWhichIsA("UIGridStyleLayout") then
		UiFx.makeShine(face, face, true)
		hoverShine(card, face)
	end
end

--- The tier's surface pattern (no frame change) on a portrait tile or well:
--- a hero's portrait sits on its rarity's texture, gently shimmering.
function UiFx.stylePortrait(tile: GuiObject, rarity: string?)
	local look = (if rarity then FRAMES[rarity] else nil) or FRAMES.Common
	applyPattern(tile, look.pattern)
end

return UiFx
