--!strict
-- Viewports - the 3D slots in the UI: hero thumbs and portraits, food cards.
--
-- A ViewportFrame keeps the ONE clone it was last given: asking for the same
-- thing again is free, so a list can call this on every snapshot. A template
-- that is not in the place leaves the slot empty and is asked for again next
-- time (no error, no stand-in).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Parent.Fx.Motion)

local Viewports = {}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local FOV = 30
-- a food is seen from a little above and a little to the side
local FOOD_PITCH = math.rad(22)
local FOOD_YAW = math.rad(28)
-- framing (see Viewports.food): how much of the food's longest half side to
-- allow for, and how much of its extents box must stay on screen
local FOOD_ROUND = 1.08
local FOOD_BOX = 0.85

-- food viewports that turn while the food shop is open
local spinning: { [ViewportFrame]: Model } = {}
local spinConnection: RBXScriptConnection? = nil

local function template(kind: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(kind)
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

local function clear(frame: ViewportFrame)
	local world = frame:FindFirstChild("World")
	if world then
		world:Destroy()
	end
	spinning[frame] = nil
end

local function stage(frame: ViewportFrame): (WorldModel, Camera)
	clear(frame)
	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = frame
	local camera = frame:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = frame
	end
	camera.FieldOfView = FOV
	frame.CurrentCamera = camera
	return world, camera
end

--- Turn a hero model into a pure black shape: every part black, nothing
--- left that could give it away (the index before a hero is caught, and the
--- silhouette that walks in before a reveal).
function Viewports.blacken(model: Model)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Color = BLACK
			piece.Material = Enum.Material.SmoothPlastic
			if piece:IsA("MeshPart") then
				piece.TextureID = ""
			end
		elseif piece:IsA("SpecialMesh") then
			piece.TextureId = ""
		elseif
			piece:IsA("Decal")
			or piece:IsA("SurfaceAppearance")
			or piece:IsA("Clothing")
			or piece:IsA("ShirtGraphic")
			or piece:IsA("BodyColors")
			or piece:IsA("ParticleEmitter")
		then
			piece:Destroy()
		end
	end
end

-- Head-and-shoulders framing, measured on the model itself (heroes differ in
-- height, scale, hair and hats): the box from just under the shoulders to the
-- TOP OF THE HAIR, as wide as the shoulders; then the camera is pulled back
-- until every top corner of that box sits inside the frame with headroom.
-- v4.5 (owner's review 6: "heads cut off at the top"): v4.3 capped the hair at
-- a quarter head above the head, ignored a hair mesh whose centre sat below
-- the head's middle and measured parts without their rotation, so tall or
-- spiky hair ran out of the top of the tile.
local HERO_YAW = math.rad(14) -- seen a little from its right
local HERO_PITCH = math.rad(5) -- and a little from above
local HERO_MARGIN = 1.12 -- the first guess at the room round the box
local HERO_TOP = 0.84 -- the hair's top reaches at most 84% of the way up to the frame's top edge
local HERO_SIDE = 0.94 -- the head and shoulders reach at most 94% of the way to a side edge
local HAIR_REACH = 1.9 -- hair / a hat counts up to this many head heights above the head (a halo or a raised sword does not)
local PORTRAIT_INSET = 5 -- px between a portrait and its tile's rounded frame

-- v4.3 (owner's review 4: "the portraits are outside their frames"). A parent's
-- ClipsDescendants clips to its RECTANGLE, never to its rounded corners, and a
-- viewport filling a rounded tile painted the hero over the corners and over
-- the tile's white frame. So a portrait sits INSIDE its tile: inset by a few
-- pixels, its own rounded corners, and a rim (a copy of the tile's frame stroke)
-- drawn ABOVE it, so nothing of the hero is ever outside or on the frame.
local function framePortrait(frame: ViewportFrame)
	if frame:GetAttribute("Framed") then
		return
	end
	frame:SetAttribute("Framed", true)
	local tile = frame.Parent
	if not tile or not tile:IsA("GuiObject") then
		return
	end
	local corner = tile:FindFirstChildOfClass("UICorner")
	local border: UIStroke? = nil
	for _, child in tile:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			border = child
		end
	end
	if not corner and not border then
		return -- a free-standing viewport (a banner): nothing to sit inside
	end
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -2 * PORTRAIT_INSET, 1, -2 * PORTRAIT_INSET)
	if corner and not frame:FindFirstChildOfClass("UICorner") then
		local own = Instance.new("UICorner")
		local radius = corner.CornerRadius
		own.CornerRadius = UDim.new(radius.Scale, math.max(0, radius.Offset - PORTRAIT_INSET))
		own.Parent = frame
	end
	if border and not tile:FindFirstChild("PortraitRim") then
		local rim = Instance.new("Frame")
		rim.Name = "PortraitRim"
		rim.BackgroundTransparency = 1
		rim.Size = UDim2.fromScale(1, 1)
		rim.ZIndex = frame.ZIndex + 2
		rim.Active = false
		if corner then
			corner:Clone().Parent = rim
		end
		local stroke = border:Clone()
		stroke.Parent = rim
		rim.Parent = tile
	end
end

local function partNamed(model: Model, names: { string }): BasePart?
	-- a direct child first: an accessory or a prop can carry a part named "Head" deep inside
	for _, name in names do
		local found = model:FindFirstChild(name)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	for _, name in names do
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

-- the world-axis box of a part, its rotation counted (a tilted hair mesh
-- reaches higher than its centre plus half its Size.Y)
local function boxOf(part: BasePart): (Vector3, Vector3)
	local cf, half = part.CFrame, part.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local extent = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	)
	return cf.Position - extent, cf.Position + extent
end

type Bust = { min: Vector3, max: Vector3 }

-- The head-and-shoulders box, or nil. The top is the highest point of the
-- head and of every visible piece on it (hair, ears, hats: anything whose box
-- reaches above the head's middle inside the head's column, whatever its
-- centre), up to HAIR_REACH head heights above the head. The bottom is just
-- under the shoulders; the width covers the shoulders and the hair.
local function headShoulders(model: Model): Bust?
	local head = partNamed(model, { "Head" })
	if not head then
		return nil
	end
	local headMin, headMax = boxOf(head)
	local headH = math.max(headMax.Y - headMin.Y, 0.4)
	local headMid = (headMin + headMax) / 2
	local column = math.max(headMax.X - headMin.X, headMax.Z - headMin.Z, headH) * 1.6
	local cap = headMax.Y + headH * HAIR_REACH
	local lo, hi = headMin, headMax
	for _, piece in model:GetDescendants() do
		if
			piece:IsA("BasePart")
			and piece ~= head
			and piece.Transparency < 0.9
			and piece.Name ~= "HumanoidRootPart"
		then
			local pMin, pMax = boxOf(piece)
			local mid = (pMin + pMax) / 2
			if
				pMax.Y > headMid.Y
				and pMin.Y < cap
				and math.abs(mid.X - headMid.X) < column
				and math.abs(mid.Z - headMid.Z) < column
			then
				lo = Vector3.new(
					math.min(lo.X, math.max(pMin.X, headMid.X - column)),
					lo.Y,
					math.min(lo.Z, math.max(pMin.Z, headMid.Z - column))
				)
				hi = Vector3.new(
					math.max(hi.X, math.min(pMax.X, headMid.X + column)),
					math.max(hi.Y, math.min(pMax.Y, cap)),
					math.max(hi.Z, math.min(pMax.Z, headMid.Z + column))
				)
			end
		end
	end
	local bottom = headMin.Y - headH * 0.9
	local torso = partNamed(model, { "UpperTorso", "Torso" })
	if torso then
		local tMin, tMax = boxOf(torso)
		bottom = math.min(headMin.Y - headH * 0.35, tMin.Y + (tMax.Y - tMin.Y) * 0.4)
		-- the shoulders: a little wider than the upper torso, centred on it
		local halfW = (tMax.X - tMin.X) * 0.6
		local cx = (tMin.X + tMax.X) / 2
		lo = Vector3.new(math.min(lo.X, cx - halfW), lo.Y, math.min(lo.Z, tMin.Z))
		hi = Vector3.new(math.max(hi.X, cx + halfW), hi.Y, math.max(hi.Z, tMax.Z))
	end
	return { min = Vector3.new(lo.X, bottom, lo.Z), max = hi }
end

-- Point `camera` at the bust in a frame of `aspect` (width / height): start
-- from the distance that fits its height, then move back until the top
-- corners (the hair) sit within HERO_TOP of the half height and every corner
-- within HERO_SIDE of the half width (the chest may run out of the bottom).
local function frameBust(camera: Camera, bust: Bust, aspect: number)
	local tanHalf = math.tan(math.rad(FOV / 2))
	local size = bust.max - bust.min
	local centre = (bust.min + bust.max) / 2
	local toward = Vector3.new(
		-math.sin(HERO_YAW) * math.cos(HERO_PITCH),
		math.sin(HERO_PITCH),
		-math.cos(HERO_YAW) * math.cos(HERO_PITCH)
	)
	local distance = math.max(
		size.Y / 2 * HERO_MARGIN / tanHalf,
		size.X / 2 * HERO_MARGIN / (tanHalf * aspect)
	) + size.Z / 2
	local tops: { Vector3 } = {}
	local corners: { Vector3 } = {}
	for _, x in { bust.min.X, bust.max.X } do
		for _, z in { bust.min.Z, bust.max.Z } do
			table.insert(tops, Vector3.new(x, bust.max.Y, z))
			table.insert(corners, Vector3.new(x, bust.max.Y, z))
			table.insert(corners, Vector3.new(x, bust.min.Y, z))
		end
	end
	local cf = CFrame.lookAt(centre + toward * distance, centre)
	for _ = 1, 12 do
		local worst = 0
		for _, p in tops do
			local q = cf:PointToObjectSpace(p)
			worst = math.max(worst, q.Y / math.max(-q.Z, 0.05) / tanHalf / HERO_TOP)
		end
		for _, p in corners do
			local q = cf:PointToObjectSpace(p)
			worst = math.max(
				worst,
				math.abs(q.X) / math.max(-q.Z, 0.05) / (tanHalf * aspect) / HERO_SIDE
			)
		end
		if worst <= 1 then
			break
		end
		distance *= math.min(worst, 2) * 1.02
		cf = CFrame.lookAt(centre + toward * distance, centre)
	end
	camera.CFrame = cf
end

--- Light `frame` like a studio portrait: a bright key from in front and above the camera and a high
--- ambient, so a hero's face and clothes read in full colour on a card (owner's review: the card
--- portraits looked dark under the ViewportFrame defaults, ambient 200 / light 140 from the back left).
function Viewports.bright(frame: ViewportFrame)
	frame.Ambient = Color3.fromRGB(225, 225, 232)
	frame.LightColor = Color3.fromRGB(255, 248, 238)
	-- heroes face -Z and the camera sits on that side: the light travels toward +Z, down a little
	frame.LightDirection = Vector3.new(0.35, -0.55, 1)
end

--- Show hero `id` in `frame`, head and shoulders. `silhouette` draws it as a
--- black shape (the index, before the hero is discovered). nil clears.
function Viewports.hero(frame: ViewportFrame, id: string?, silhouette: boolean?)
	local key = if id then id .. (if silhouette then "|hidden" else "") else ""
	if frame:GetAttribute("Showing") == key then
		return
	end
	clear(frame)
	frame:SetAttribute("Showing", "")
	framePortrait(frame)
	local source = if id then template("Characters", "Char_" .. id) else nil
	if not source then
		return
	end
	local model = source:Clone()
	if silhouette then
		Viewports.blacken(model)
	end
	frame.ImageColor3 = if silhouette then BLACK else WHITE
	-- a baked rig: pivot at the feet, facing -Z
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	local bust = headShoulders(model)
	if not bust then
		camera.CFrame = CFrame.lookAt(Vector3.new(-1.2, 4.95, -5.1), Vector3.new(0, 4.55, 0))
	else
		-- the frame's shape: its laid-out size, else its offsets (framePortrait's
		-- inset size has a negative offset: then a square is assumed)
		local wide = if frame.AbsoluteSize.X > 0 then frame.AbsoluteSize.X else frame.Size.X.Offset
		local high = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.Y else frame.Size.Y.Offset
		frameBust(camera, bust, if wide > 0 and high > 0 then wide / high else 1)
	end
	frame:SetAttribute("Showing", key)
end

--- Show food `id` in `frame`, whole, and register it to spin. nil clears.
function Viewports.food(frame: ViewportFrame, id: string?)
	local key = id or ""
	if frame:GetAttribute("Showing") == key then
		return
	end
	clear(frame)
	frame:SetAttribute("Showing", "")
	local source = if id then template("Foods", "Food_" .. id) else nil
	if not source then
		return
	end
	local model = source:Clone()
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	-- FRAMING: the food fills the viewport's height (the viewport is about
	-- 78% of its art tile). The half diagonal of the extents box is NOT the
	-- food's size: a rounded food reaches only half its longest side, and
	-- framing the box's corners left the food at 40% of the tile. So the
	-- radius is the food's longest half side plus a little; and so that a
	-- boxy or tall food is not cut, never less than FOOD_BOX of what the box
	-- itself needs on screen as it spins (up and across).
	local size = model:GetExtentsSize()
	local sinP, cosP = math.sin(FOOD_PITCH), math.cos(FOOD_PITCH)
	local reach = math.sqrt(size.X * size.X + size.Z * size.Z) / 2
	local boxUp = cosP * size.Y / 2 + sinP * reach
	local wide = frame.Size.X.Offset
	local high = frame.Size.Y.Offset
	local aspect = if wide > 0 and high > 0 then wide / high else 1
	local radius = math.max(
		math.max(size.X, size.Y, size.Z) / 2 * FOOD_ROUND,
		FOOD_BOX * boxUp,
		FOOD_BOX * reach / aspect,
		0.25
	)
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.02
	camera.CFrame = CFrame.lookAt(
		Vector3.new(math.sin(FOOD_YAW) * cosP, sinP, -math.cos(FOOD_YAW) * cosP) * distance,
		Vector3.zero
	)
	frame:SetAttribute("Showing", key)
	spinning[frame] = model
	frame.Destroying:Once(function()
		spinning[frame] = nil
	end)
end

--- Turn the registered foods slowly while `clip` (their scroller) is given;
--- nil stops. Only foods inside the clip rectangle are moved.
function Viewports.spin(clip: GuiObject?)
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
	if not clip then
		return
	end
	spinConnection = RunService.RenderStepped:Connect(function()
		local turn = CFrame.Angles(0, os.clock() * 0.9, 0)
		local from = clip.AbsolutePosition
		local to = from + clip.AbsoluteSize
		for frame, model in spinning do
			local at = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			if
				at.X < to.X
				and at.X + size.X > from.X
				and at.Y < to.Y
				and at.Y + size.Y > from.Y
			then
				model:PivotTo(turn)
			end
		end
	end)
end

-- -------------------------------------------------- any model (v4.2) --

export type Shown = {
	model: Model,
	camera: Camera,
	centre: Vector3, -- the model's bounding-box centre (it sits at the origin)
	distance: number, -- the camera distance that frames it
	pitch: number,
}

local function asModel(source: Instance): Model?
	if source:IsA("Model") then
		return source:Clone()
	elseif source:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = source.Name
		local part = source:Clone()
		part.Parent = model
		model.PrimaryPart = part
		return model
	end
	return nil
end

--- Show any Model or BasePart template in `frame`, framed whole by its
--- bounding box (centred at the origin), seen a little from above. Nothing
--- in it simulates (anchored, no scripts, no sounds). Returns what the
--- caller needs to turn or zoom it (Viewports.pose), or nil.
function Viewports.model(frame: ViewportFrame, source: Instance?, margin: number?): Shown?
	clear(frame)
	frame:SetAttribute("Showing", "")
	if not source then
		return nil
	end
	local ok, model = pcall(asModel, source)
	if not ok or not model then
		return nil
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
		elseif
			piece:IsA("LuaSourceContainer")
			or piece:IsA("Sound")
			or piece:IsA("ParticleEmitter")
			or piece:IsA("Beam")
			or piece:IsA("Trail")
		then
			piece:Destroy()
		end
	end
	local box, size = model:GetBoundingBox()
	-- the box centre goes to the origin, the model keeps its own facing
	model:PivotTo(model:GetPivot() - box.Position)
	local world, camera = stage(frame)
	model.Parent = world
	local wide = if frame.AbsoluteSize.X > 0 then frame.AbsoluteSize.X else frame.Size.X.Offset
	local high = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.Y else frame.Size.Y.Offset
	local aspect = if wide > 0 and high > 0 then wide / high else 1
	local radius = math.max(size.Magnitude / 2, 0.25) * (margin or 1.05)
	local tanHalf = math.tan(math.rad(FOV / 2))
	local distance = radius / (tanHalf * math.min(1, aspect))
	local shown: Shown = {
		model = model,
		camera = camera,
		centre = Vector3.zero,
		distance = distance,
		pitch = math.rad(14),
	}
	Viewports.pose(shown, 0, 1)
	frame:SetAttribute("Showing", "model:" .. source.Name)
	return shown
end

--- Point the camera of a Shown model: `yaw` radians round it, `zoom` > 1
--- moves the camera away (the model looks smaller), < 1 closer.
function Viewports.pose(shown: Shown, yaw: number, zoom: number)
	local d = shown.distance * zoom
	local cp = math.cos(shown.pitch)
	local eye = shown.centre
		+ Vector3.new(math.sin(yaw) * cp, math.sin(shown.pitch), -math.cos(yaw) * cp) * d
	shown.camera.CFrame = CFrame.lookAt(eye, shown.centre)
end

--- Empty a viewport (the clone and its world go).
function Viewports.clear(frame: ViewportFrame)
	clear(frame)
	frame:SetAttribute("Showing", "")
end

-- ---------------------------------------- an animated hero (v4.2) --

export type Stage = {
	frame: ViewportFrame,
	model: Model,
	camera: Camera,
	track: AnimationTrack?,
	stop: () -> (),
}

--- Hero `id` full length in `frame`, playing its own idle (config `Idle`)
--- inside a WorldModel, the camera breathing slowly in and out. Call the
--- returned stop() when the screen closes: it stops the loop and the clip and
--- empties the viewport. `idle` names the clip (Animations.luau).
function Viewports.heroStage(frame: ViewportFrame, id: string?, idle: string?): Stage?
	clear(frame)
	frame:SetAttribute("Showing", "")
	local source = if id then template("Characters", "Char_" .. id) else nil
	if not source then
		return nil
	end
	local model = source:Clone()
	frame.ImageColor3 = WHITE
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	local _, size = model:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local focus = Vector3.new(0, height * 0.52, 0)
	local tanHalf = math.tan(math.rad(FOV / 2))
	local base = height * 0.56 / tanHalf
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local track: AnimationTrack? = nil
	if humanoid and idle then
		track = Motion.play(humanoid, idle, { fade = 0.2, looped = true })
	end
	local t0 = os.clock()
	local connection: RBXScriptConnection? = RunService.RenderStepped:Connect(function()
		if not frame.Parent then
			return
		end
		local t = os.clock() - t0
		-- a slow breathe: in and out, a little sway round the hero
		local d = base * (1 + 0.035 * math.sin(t * 0.9))
		local yaw = math.rad(10) + math.rad(8) * math.sin(t * 0.35)
		local eye = focus + Vector3.new(-math.sin(yaw), 0.12, -math.cos(yaw)) * d
		camera.CFrame = CFrame.lookAt(eye, focus + Vector3.new(0, 0.05 * math.sin(t * 0.9), 0))
	end)
	frame:SetAttribute("Showing", "stage:" .. (id or ""))
	local made: Stage
	made = {
		frame = frame,
		model = model,
		camera = camera,
		track = track,
		stop = function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			Motion.stop(made.track, 0)
			clear(frame)
			frame:SetAttribute("Showing", "")
		end,
	}
	return made
end

-- ------------------------------------- a showcase hero (UI v5 store) --

export type Showcase = {
	frame: ViewportFrame,
	model: Model,
	camera: Camera,
	track: AnimationTrack?,
	step: (t: number) -> (),
	stop: () -> (),
}

--- Hero `id` full length in `frame`, playing its idle (config `Idle`) in a
--- WorldModel, like heroStage, but with NO loop of its own: the caller's one
--- shared loop calls step(t) (seconds since open) while the frame is on
--- screen. The camera makes a slow push in and out (a cinematic dolly) with
--- a gentle sway. `fill` = how much of the frame's height the hero takes
--- (default 0.9); `push` = how far the dolly travels (default 0.1).
function Viewports.heroShowcase(
	frame: ViewportFrame,
	id: string?,
	idle: string?,
	fill: number?,
	push: number?
): Showcase?
	clear(frame)
	frame:SetAttribute("Showing", "")
	local source = if id then template("Characters", "Char_" .. id) else nil
	if not source then
		return nil
	end
	local model = source:Clone()
	frame.ImageColor3 = WHITE
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	local _, size = model:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local wide = if frame.AbsoluteSize.X > 0 then frame.AbsoluteSize.X else frame.Size.X.Offset
	local high = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.Y else frame.Size.Y.Offset
	local aspect = if wide > 0 and high > 0 then wide / high else 1
	local tanHalf = math.tan(math.rad(FOV / 2))
	-- the hero's half height must fit the frame's half height (and its half
	-- width the half width on a narrow frame)
	local half = height / 2 / (fill or 0.9)
	local base = math.max(half / tanHalf, size.X / 2 / (tanHalf * aspect))
	local focus = Vector3.new(0, height * 0.5, 0)
	local travel = push or 0.1
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local track: AnimationTrack? = nil
	if humanoid and idle then
		track = Motion.play(humanoid, idle, { fade = 0.2, looped = true })
	end
	local made: Showcase
	made = {
		frame = frame,
		model = model,
		camera = camera,
		track = track,
		step = function(t: number)
			-- 0 -> 1 -> 0 over 14 s: the dolly pushes in, then eases back out
			local s = 0.5 - 0.5 * math.cos(t * math.pi * 2 / 14)
			local d = base * (1 + travel * 0.5 - travel * s)
			local yaw = math.rad(8) + math.rad(7) * math.sin(t * 0.3)
			local lift = 0.06 + 0.04 * math.sin(t * 0.21)
			local eye = focus + Vector3.new(-math.sin(yaw), lift, -math.cos(yaw)) * d
			camera.CFrame = CFrame.lookAt(eye, focus + Vector3.new(0, 0.04 * math.sin(t * 0.9), 0))
		end,
		stop = function()
			Motion.stop(made.track, 0)
			clear(frame)
			frame:SetAttribute("Showing", "")
		end,
	}
	made.step(0)
	frame:SetAttribute("Showing", "showcase:" .. (id or ""))
	return made
end

--- One beat of a store hero's showcase: a looped base clip held `hold`
--- seconds (randomised +-15%), or a one-shot flourish (`once`) played over
--- the current base for its own length. `push` > 1 moves the camera in
--- during the beat.
export type Beat = { clip: string, hold: number?, once: boolean?, push: number? }

--- STORE ONLY (UI v5.2, owner's review 6): like heroShowcase, but the hero
--- performs a sequence instead of one idle on repeat. `beats` cycle in order
--- (clips this session cannot play are skipped); base clips cross-fade over
--- 0.6 s, flourishes fade in 0.3 s and out 0.4 s before they end, so the
--- hero never snaps. The camera orbits slowly (+-16 deg over ~28 s), lifts,
--- and eases in and out with each beat's `push`. No loop of its own: the
--- caller's one loop (StoreFx) calls step(t) only while it is on screen.
function Viewports.heroSequence(
	frame: ViewportFrame,
	id: string?,
	beats: { Beat },
	fill: number?
): Showcase?
	clear(frame)
	frame:SetAttribute("Showing", "")
	local source = if id then template("Characters", "Char_" .. id) else nil
	if not source then
		return nil
	end
	local model = source:Clone()
	frame.ImageColor3 = WHITE
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	local _, size = model:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local wide = if frame.AbsoluteSize.X > 0 then frame.AbsoluteSize.X else frame.Size.X.Offset
	local high = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.Y else frame.Size.Y.Offset
	local aspect = if wide > 0 and high > 0 then wide / high else 1
	local tanHalf = math.tan(math.rad(FOV / 2))
	-- room for a flourish's arms and a lean: a little wider than heroShowcase
	local half = height / 2 / (fill or 0.86)
	local base = math.max(half / tanHalf, size.X * 0.62 / (tanHalf * aspect))
	local focus = Vector3.new(0, height * 0.5, 0)
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local baseTrack: AnimationTrack? = nil
	local action: AnimationTrack? = nil
	local index = 0
	local beatStart = 0
	local beatEnd = -1
	local actionOut = false
	local zoom, zoomTarget = 1, 1
	local lastT: number? = nil

	local made: Showcase
	local function nextBeat(t: number)
		for _ = 1, #beats do
			index = index % #beats + 1
			local beat = beats[index]
			if humanoid and Motion.has(beat.clip) then
				if beat.once then
					Motion.stop(action, 0.3)
					action = Motion.play(humanoid, beat.clip, {
						fade = 0.3,
						looped = false,
						priority = "Action",
					})
					if action then
						actionOut = false
						beatStart = t
						local length = action.Length
						beatEnd = t + (beat.hold or (if length > 0 then length else 2.6))
						zoomTarget = beat.push or 1.08
						made.track = action
						return
					end
				else
					local track = Motion.play(humanoid, beat.clip, {
						fade = 0.6,
						looped = true,
						priority = "Core",
					})
					if track then
						-- the same clip again is the same cached track: keep it
						if baseTrack and baseTrack ~= track then
							Motion.stop(baseTrack, 0.6)
						end
						baseTrack = track
						beatStart = t
						beatEnd = t + (beat.hold or 5) * (0.85 + 0.3 * math.random())
						zoomTarget = beat.push or 1
						made.track = track
						return
					end
				end
			end
		end
		beatEnd = math.huge -- nothing playable: hold the rest pose
	end

	made = {
		frame = frame,
		model = model,
		camera = camera,
		track = nil,
		step = function(t: number)
			local dt = if lastT then math.clamp(t - lastT, 0, 0.1) else 0
			lastT = t
			if t >= beatEnd then
				nextBeat(t)
			elseif action and not actionOut then
				-- a flourish whose length arrived late (asset still loading)
				local length = action.Length
				local beat = beats[index]
				if beat and beat.once and not beat.hold and length > 0 then
					beatEnd = math.min(beatEnd, beatStart + length)
				end
				-- fade the flourish out just before it ends, back to the base
				if t >= beatEnd - 0.4 and beat and beat.once then
					Motion.stop(action, 0.4)
					actionOut = true
					zoomTarget = 1
				end
			end
			zoom += (zoomTarget - zoom) * (1 - math.exp(-dt * 1.4))
			local yaw = math.rad(6) + math.rad(16) * math.sin(t * 0.225)
			local lift = 0.05 + 0.05 * math.sin(t * 0.17)
			local d = base * (1.04 + 0.04 * math.sin(t * 0.31)) / zoom
			local eye = focus + Vector3.new(-math.sin(yaw), lift, -math.cos(yaw)) * d
			camera.CFrame = CFrame.lookAt(eye, focus + Vector3.new(0, 0.05 * math.sin(t * 0.7), 0))
		end,
		stop = function()
			Motion.stop(action, 0)
			Motion.stop(baseTrack, 0)
			clear(frame)
			frame:SetAttribute("Showing", "")
		end,
	}
	made.step(0)
	frame:SetAttribute("Showing", "sequence:" .. (id or ""))
	return made
end

return Viewports
