--!strict
-- StoreFx - the Store's effects (UI v5.2, owner's review 6), in ONE loop that
-- runs only while the store is open and touches only what is on screen.
--
-- v5.2: NOTHING IN THE STORE CHANGES SIZE. The chips' scale pulse is gone
-- (the owner saw text and plate breathe out of step, "like 10 fps"): chips
-- get shine() instead (a glint band sliding across + a halo breathing in
-- transparency), the border chase never touches thickness, and VfxPulse is
-- replaced by VfxBreath (transparency only).
--
--   flipbooks  a clipping square (attribute VfxGrid = cols = rows, VfxFps)
--              holding a `Sheet` image grid x grid its size: a frame is shown
--              by moving the Sheet by whole cells, so it works whatever the
--              texture's pixel size. VfxOnce = a crackle: one cycle, a pause.
--              At most MAX_FLIPS step per frame (the rest hold their frame).
--   sprites    VfxTurn (deg/s), VfxBreath (transparency amplitude), VfxRise
--              (px per loop, fade in/out, VfxDrift sway), VfxThrust (px out
--              along the image's rotation: a spear stabbing out and drawing
--              back), VfxPeriod seconds.
--   drips      a clipping holder (VfxDrip = period, VfxPhase, VfxRunFrom/To)
--              whose `Run` image slides down; its bead then falls off as the
--              sibling `<holder>Drop` (VfxFall px). Position only.
--   textures   every owner texture ships its id in VfxImage (Screens.prepare
--              blanks images whose IconKey is not in Icons; bind() puts them
--              back). ids: assets/ui/ids_store_v5.json.
--   borders    a light chase round a border (a turning UIGradient on its
--              UIStroke).
--   text       a sliding gradient on a label (rarity chip, titles, name).
--   shine      a glint band sliding across a chip / frame every few seconds
--              (one UIGradient Offset, set every frame) and a halo behind it
--              breathing in transparency. Text never moves or resizes.
--   stages     3D showcases (Viewports.heroSequence) stepped by this loop.
--
-- Particles do not render in a ViewportFrame: every aura / flame / spark is
-- one of these UI layers behind or in front of the viewport.

local RunService = game:GetService("RunService")

local StoreFx = {}

local MAX_FLIPS = 16

type Flip = {
	holder: GuiObject,
	sheet: ImageLabel,
	grid: number,
	fps: number,
	once: boolean,
	phase: number,
	pos: UDim2,
	rise: number?,
	period: number,
	alpha: number,
	hiddenUntil: number,
	cycleStart: number,
}

type Sprite = {
	image: ImageLabel,
	pos: UDim2,
	rot: number,
	alpha: number,
	phase: number,
	turn: number?,
	breath: number?,
	rise: number?,
	thrust: number?,
	drift: number,
	period: number,
}

type Drip = {
	holder: GuiObject,
	run: GuiObject,
	drop: ImageLabel?,
	dropPos: UDim2,
	dropAlpha: number,
	from: number,
	to: number,
	fall: number,
	period: number,
	phase: number,
}

type Border = { stroke: UIStroke, gradient: UIGradient, speed: number, phase: number }
type Shimmer = { gradient: UIGradient, speed: number }
type Shine = { gradient: UIGradient, period: number, sweep: number, phase: number }
type Halo = { image: ImageLabel, alpha: number, amp: number, speed: number, phase: number }
type Stage = { frame: GuiObject, step: (number) -> () }

-- strong tables (a weak Instance key is dropped when its Luau wrapper is
-- collected, which froze UiFx's flares in v4.2); emptied on Destroying
local flips: { [GuiObject]: Flip } = {}
local sprites: { [ImageLabel]: Sprite } = {}
local drips: { [GuiObject]: Drip } = {}
local borders: { [UIStroke]: Border } = {}
local shimmers: { [UIGradient]: Shimmer } = {}
local shines: { [UIGradient]: Shine } = {}
local halos: { [ImageLabel]: Halo } = {}
local stages: { Stage } = {}

local clip: GuiObject? = nil
local connection: RBXScriptConnection? = nil
local t0 = 0

local function num(inst: Instance, name: string): number?
	local value = inst:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function forget(inst: Instance, map: any)
	inst.Destroying:Once(function()
		map[inst] = nil
	end)
end

local function bindDrip(d: GuiObject, period: number)
	local run = d:FindFirstChild("Run")
	if not (run and run:IsA("GuiObject")) then
		return
	end
	local parent = d.Parent
	local found = if parent then parent:FindFirstChild(d.Name .. "Drop") else nil
	local drop = if found and found:IsA("ImageLabel") then found else nil
	drips[d] = {
		holder = d,
		run = run,
		drop = drop,
		dropPos = if drop then drop.Position else UDim2.new(),
		dropAlpha = if drop then drop.ImageTransparency else 0,
		from = num(d, "VfxRunFrom") or 0,
		to = num(d, "VfxRunTo") or 0,
		fall = if drop then num(drop, "VfxFall") or 0 else 0,
		period = period,
		phase = num(d, "VfxPhase") or math.random() * period,
	}
	forget(d, drips)
end

--- Make the effect layers under `root` live: restore the owner textures,
--- size the flipbook sheets, register every animated layer. `scroller` is
--- the page's scroller: layers inside it animate only while in view.
--- Idempotent.
function StoreFx.bind(root: Instance, scroller: GuiObject?)
	clip = scroller or clip
	for _, d in root:GetDescendants() do
		if d:IsA("ImageLabel") then
			local image = d:GetAttribute("VfxImage")
			if typeof(image) == "string" then
				d.Image = image
			end
		end
		if d:IsA("GuiObject") then
			local grid = num(d, "VfxGrid")
			local dripPeriod = num(d, "VfxDrip")
			if dripPeriod then
				if not drips[d] then
					bindDrip(d, dripPeriod)
				end
			elseif grid then
				local sheet = d:FindFirstChild("Sheet")
				if not flips[d] and sheet and sheet:IsA("ImageLabel") then
					sheet.Size = UDim2.fromScale(grid, grid)
					sheet.Position = UDim2.fromScale(0, 0)
					flips[d] = {
						holder = d,
						sheet = sheet,
						grid = grid,
						fps = num(d, "VfxFps") or 20,
						once = d:GetAttribute("VfxOnce") == true,
						phase = math.random() * 4,
						pos = d.Position,
						rise = num(d, "VfxRise"),
						period = num(d, "VfxPeriod") or 3,
						alpha = sheet.ImageTransparency,
						hiddenUntil = 0,
						cycleStart = 0,
					}
					forget(d, flips)
				end
			elseif d:IsA("ImageLabel") and not sprites[d] and d.Name ~= "Sheet" then
				local turn, breath, rise = num(d, "VfxTurn"), num(d, "VfxBreath"), num(d, "VfxRise")
				local thrust = num(d, "VfxThrust")
				if turn or breath or rise or thrust then
					sprites[d] = {
						image = d,
						pos = d.Position,
						rot = d.Rotation,
						alpha = d.ImageTransparency,
						phase = math.random() * math.pi * 2,
						turn = turn,
						breath = breath,
						rise = rise,
						thrust = thrust,
						drift = num(d, "VfxDrift") or 0,
						period = num(d, "VfxPeriod") or 2.5,
					}
					forget(d, sprites)
				end
			end
		end
	end
end

--- A light chase round `card`'s border: its border stroke turns white with
--- a moving bright band in `colour` (the thickness never changes). The stroke
--- may be on `card` itself or on its `Face`. `deep` overrides the dark end.
function StoreFx.border(card: GuiObject, colour: Color3, speed: number?, deep: Color3?)
	local face = card:FindFirstChild("Face")
	local target: Instance = if face then face else card
	local stroke: UIStroke? = nil
	for _, child in target:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			stroke = child
		end
	end
	if not stroke or borders[stroke] then
		return
	end
	stroke.Color = Color3.new(1, 1, 1)
	local dark = deep or colour:Lerp(Color3.new(0, 0, 0), 0.25)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Chase"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.40, colour),
		ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.60, colour),
		ColorSequenceKeypoint.new(1, dark),
	})
	gradient.Parent = stroke
	borders[stroke] = {
		stroke = stroke,
		gradient = gradient,
		speed = speed or 120,
		phase = math.random() * 360,
	}
	forget(stroke, borders)
end

--- A sliding gradient across `label` in `colours` (Offset only).
function StoreFx.shimmer(label: GuiObject, colours: { Color3 }, speed: number?)
	local gradient = label:FindFirstChild("Shimmer")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "Shimmer"
		gradient.Parent = label
	end
	local g = gradient :: UIGradient
	local points = {}
	local n = #colours
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / math.max(1, n - 1), c))
	end
	if n == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, colours[1]))
	end
	g.Color = ColorSequence.new(points)
	if not shimmers[g] then
		shimmers[g] = { gradient = g, speed = speed or 0.35 }
		forget(g, shimmers)
	end
end

--- An attention effect that cannot desync (v5.2, owner's review 6): a soft
--- white glint band slides across `target` every `period` seconds (one
--- UIGradient's Offset, set every frame) and, when `glowImage` is given, a
--- halo behind it breathes in transparency. Neither changes any size or
--- position, so text and plate can never drift apart. Removes any v5.1
--- `FxPulseScale` left on the target. `corner` rounds the glint (a pill by
--- default); `z` is its ZIndex among the target's children.
function StoreFx.shine(
	target: GuiObject,
	period: number?,
	glowImage: string?,
	glowColour: Color3?,
	corner: UDim?,
	z: number?
)
	for _, d in target:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "FxPulseScale" then
			d:Destroy()
		end
	end
	local band = target:FindFirstChild("FxShine")
	if not band then
		local f = Instance.new("Frame")
		f.Name = "FxShine"
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = z or 40
		f.Active = false
		local round = Instance.new("UICorner")
		round.CornerRadius = corner or UDim.new(0.5, 0)
		round.Parent = f
		local g = Instance.new("UIGradient")
		g.Rotation = 18
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.38, 1),
			NumberSequenceKeypoint.new(0.47, 0.75),
			NumberSequenceKeypoint.new(0.5, 0.58),
			NumberSequenceKeypoint.new(0.53, 0.75),
			NumberSequenceKeypoint.new(0.62, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Offset = Vector2.new(-1, 0)
		g.Parent = f
		f.Parent = target
		band = f
	end
	local gradient = (band :: Instance):FindFirstChildOfClass("UIGradient")
	if gradient and not shines[gradient] then
		shines[gradient] = {
			gradient = gradient,
			period = period or 3.2,
			sweep = 0.9,
			phase = math.random() * 3,
		}
		forget(gradient, shines)
	end
	if glowImage and not target:FindFirstChild("FxHalo") then
		local halo = Instance.new("ImageLabel")
		halo.Name = "FxHalo"
		halo.BackgroundTransparency = 1
		halo.Image = glowImage
		halo.ImageColor3 = glowColour or Color3.new(1, 1, 1)
		halo.ImageTransparency = 0.55
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.new(1, 34, 1, 30)
		halo.ZIndex = 0
		halo.Parent = target
		halos[halo] =
			{ image = halo, alpha = 0.5, amp = 0.32, speed = 2.4, phase = math.random() * 6 }
		forget(halo, halos)
	end
end

--- Step a 3D showcase from the loop while `frame` is on screen.
function StoreFx.stage(frame: GuiObject, step: (number) -> ())
	table.insert(stages, { frame = frame, step = step })
end

-- ------------------------------------------------------------------ loop --

local memo: { [Instance]: boolean } = {}
local clipFrom = Vector2.zero
local clipTo = Vector2.zero

local function shown(node: Instance): boolean
	local cached = memo[node]
	if cached ~= nil then
		return cached
	end
	local result: boolean
	if node:IsA("LayerCollector") then
		result = node.Enabled and node.Parent ~= nil
	elseif node:IsA("GuiObject") and not node.Visible then
		result = false
	else
		local parent = node.Parent
		result = parent ~= nil and shown(parent)
	end
	memo[node] = result
	return result
end

local function onScreen(gui: GuiObject): boolean
	if not shown(gui) then
		return false
	end
	local scroller = clip
	if scroller and gui:IsDescendantOf(scroller) then
		local at, size = gui.AbsolutePosition, gui.AbsoluteSize
		return at.X < clipTo.X
			and at.X + size.X > clipFrom.X
			and at.Y < clipTo.Y
			and at.Y + size.Y > clipFrom.Y
	end
	return true
end

local function stepFlips(t: number)
	local budget = MAX_FLIPS
	for holder, f in flips do
		if budget <= 0 then
			break
		end
		if onScreen(holder) then
			budget -= 1
			local frames = f.grid * f.grid
			local index: number
			if f.once then
				-- a crackle: one pass through the sheet, then hidden a while
				if t < f.hiddenUntil then
					f.sheet.Visible = false
					continue
				end
				if f.cycleStart == 0 then
					f.cycleStart = t
				end
				index = math.floor((t - f.cycleStart) * f.fps)
				if index >= frames then
					f.cycleStart = 0
					f.hiddenUntil = t + 0.7 + math.random() * 1.8
					f.sheet.Visible = false
					continue
				end
				f.sheet.Visible = true
			else
				index = math.floor((t + f.phase) * f.fps) % frames
			end
			f.sheet.Position = UDim2.fromScale(-(index % f.grid), -(index // f.grid))
			local rise = f.rise
			if rise then
				local k = ((t + f.phase) / f.period) % 1
				local bob = math.sin(k * math.pi * 2)
				f.holder.Position = f.pos + UDim2.fromOffset(0, -rise * bob)
			end
		end
	end
end

local function stepSprites(t: number)
	for image, s in sprites do
		if onScreen(image) then
			local rise = s.rise
			local thrust = s.thrust
			if rise then
				-- rises, fading in and out, swaying
				local k = ((t + s.phase) / s.period) % 1
				local fade = math.sin(k * math.pi)
				image.Position = s.pos
					+ UDim2.fromOffset(s.drift * math.sin((t + s.phase) * 2.1), -rise * k)
				image.ImageTransparency = 1 - (1 - s.alpha) * fade
			elseif thrust then
				-- stabs out fast along its rotation, holds, draws back slowly
				local k = ((t + s.phase) / s.period) % 1
				local out = if k < 0.12
					then 1 - (1 - k / 0.12) ^ 3
					elseif k < 0.3 then 1
					else 1 - ((k - 0.3) / 0.7) ^ 0.6
				local a = math.rad(s.rot)
				image.Position = s.pos
					+ UDim2.fromOffset(math.sin(a) * thrust * out, -math.cos(a) * thrust * out)
				image.ImageTransparency = s.alpha + (1 - s.alpha) * 0.5 * (1 - out)
			end
			local turn = s.turn
			if turn and turn ~= 0 then
				image.Rotation = s.rot + turn * t
			end
			local breath = s.breath
			if breath and not rise and not thrust then
				local wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi / s.period + s.phase)
				image.ImageTransparency = math.clamp(s.alpha + breath * wave, 0, 1)
			end
		end
	end
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

local function stepDrips(t: number)
	for holder, d in drips do
		if onScreen(holder) then
			-- the run creeps down for 72% of the period, then the bead falls
			-- off and the run draws back up
			local k = ((t + d.phase) / d.period) % 1
			local grow = if k < 0.72 then smooth(k / 0.72) else 1 - 0.65 * smooth((k - 0.72) / 0.28)
			d.run.Position = UDim2.new(0.5, 0, 0, d.from + (d.to - d.from) * grow)
			local drop = d.drop
			if drop then
				if k >= 0.72 then
					local u = (k - 0.72) / 0.28
					drop.Position = d.dropPos + UDim2.fromOffset(0, d.fall * u * u)
					drop.ImageTransparency = d.dropAlpha
						+ (1 - d.dropAlpha) * math.max(0, (u - 0.55) / 0.45)
				else
					drop.ImageTransparency = 1
				end
			end
		end
	end
end

local function step(_dt: number)
	local t = os.clock() - t0
	table.clear(memo)
	local scroller = clip
	if scroller then
		clipFrom = scroller.AbsolutePosition
		clipTo = clipFrom + scroller.AbsoluteSize
	end
	for _, st in stages do
		if onScreen(st.frame) then
			st.step(t)
		end
	end
	for stroke, b in borders do
		if shown(stroke.Parent :: Instance) then
			b.gradient.Rotation = (b.phase + t * b.speed) % 360
		end
	end
	for gradient, s in shimmers do
		local x = ((t * s.speed) % 2) - 1
		gradient.Offset = Vector2.new(x, 0)
	end
	for gradient, sh in shines do
		-- one sweep (-1 -> 1) in `sweep` s, then off the chip until the next
		local k = ((t + sh.phase) % sh.period) / sh.sweep
		gradient.Offset = Vector2.new(if k < 1 then -1 + 2 * k else 1, 0)
	end
	for image, h in halos do
		image.ImageTransparency = h.alpha + h.amp * (0.5 + 0.5 * math.sin(t * h.speed + h.phase))
	end
	stepFlips(t)
	stepSprites(t)
	stepDrips(t)
end

--- Start the loop (the store opened). Safe to call twice.
function StoreFx.start()
	if connection then
		return
	end
	t0 = os.clock()
	connection = RunService.RenderStepped:Connect(step)
end

--- Stop the loop (the store closed): nothing runs, the showcases are
--- forgotten (their owner stops them), everything rests at its shipped pose.
function StoreFx.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(stages)
	table.clear(memo)
	for image, s in sprites do
		image.Position = s.pos
		image.Rotation = s.rot
		image.ImageTransparency = s.alpha
	end
	for holder, f in flips do
		holder.Position = f.pos
		f.sheet.Visible = true
		f.hiddenUntil = 0
		f.cycleStart = 0
	end
	for _, d in drips do
		d.run.Position = UDim2.new(0.5, 0, 0, d.from)
		local drop = d.drop
		if drop then
			drop.Position = d.dropPos
			drop.ImageTransparency = 1
		end
	end
	for gradient in shines do
		gradient.Offset = Vector2.new(-1, 0)
	end
end

function StoreFx.running(): boolean
	return connection ~= nil
end

return StoreFx
