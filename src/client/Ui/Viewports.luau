--!strict
-- Viewports - the 3D slots in the UI: hero thumbs and portraits, food cards.
--
-- A ViewportFrame keeps the ONE clone it was last given: asking for the same
-- thing again is free, so a list can call this on every snapshot. A template
-- that is not in the place leaves the slot empty and is asked for again next
-- time (no error, no stand-in).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

--- Show hero `id` in `frame`, head and shoulders. `silhouette` draws it as a
--- black shape (the index, before the hero is discovered). nil clears.
function Viewports.hero(frame: ViewportFrame, id: string?, silhouette: boolean?)
	local key = if id then id .. (if silhouette then "|hidden" else "") else ""
	if frame:GetAttribute("Showing") == key then
		return
	end
	clear(frame)
	frame:SetAttribute("Showing", "")
	local source = if id then template("Characters", "Char_" .. id) else nil
	if not source then
		return
	end
	local model = source:Clone()
	if silhouette then
		Viewports.blacken(model)
	end
	frame.ImageColor3 = if silhouette then BLACK else WHITE
	-- a baked rig: pivot at the feet, about 5.5 studs tall, facing -Z
	model:PivotTo(CFrame.new())
	local world, camera = stage(frame)
	model.Parent = world
	camera.CFrame = CFrame.lookAt(Vector3.new(-1.2, 4.95, -5.1), Vector3.new(0, 4.55, 0))
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

return Viewports
