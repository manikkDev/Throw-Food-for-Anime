-- fx_judge.luau: look at a food's flight and landing effects IN THE GAME, at leisure.
-- Run on the CLIENT datamodel of a Studio play session (plan 13 phase C):
--
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Client --file tools/studio/foods/fx_judge.luau
--   then, in further Client calls:
--     _G.FxJudge.fly("legend_ramen")           the food flies down zone 1 in a loop with the game's own
--                                              chase camera (15 behind, 7 above); take captures at leisure
--     _G.FxJudge.land("legend_ramen", 0.12)    lands it, FREEZES every particle 0.12 s later and parks the
--                                              game's low landing camera (far = true: the first, far camera)
--     _G.FxJudge.rest("legend_ramen")          the dish resting with its aroma loop
--     _G.FxJudge.stop()                        gives the camera back
--
-- It uses the game's own modules (a second copy: nothing in the running game is touched), so what it
-- shows is what a throw shows. The flight speed does not matter: every flight layer rides with the food.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local VfxKit = require(client.Fx.VfxKit)
local FoodFx = require(client.Fx.FoodFx)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local J = _G.FxJudge
if J and J.stop then
	J.stop()
end
J = {}
_G.FxJudge = J

local STEP = "TFAFxJudge"
local X = -40 -- plot 1's landing track
local Y = Config.World.LaneY
local live: { any } = {}
local model: Model? = nil
local carrier: Part? = nil

-- every copy of VfxKit (the game's and this tool's) keeps its own "VfxKitLive" folder
local function setTimeScale(scale: number)
	for _, folder in workspace:GetChildren() do
		if folder.Name == "VfxKitLive" then
			for _, d in folder:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.TimeScale = scale
				end
			end
		end
	end
end

local function clear()
	pcall(function()
		RunService:UnbindFromRenderStep(STEP)
	end)
	for _, h in live do
		pcall(function()
			h.stop()
		end)
		pcall(function()
			h.destroy()
		end)
	end
	table.clear(live)
	if carrier then
		carrier:Destroy()
		carrier = nil
	end
	model = nil
	setTimeScale(1)
end

local function food(foodId: string, flight: boolean): Part
	local part = Instance.new("Part")
	part.Name = "FxJudgeFood"
	part.Size = Vector3.new(2, 2, 2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace
	local template = ReplicatedStorage.Assets.Foods:FindFirstChild("Food_" .. foodId)
	if template then
		local clone = template:Clone()
		if flight then
			clone:ScaleTo(clone:GetScale() * 1.7)
		else
			clone:ScaleTo(clone:GetScale() * 1.7)
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		clone.Parent = part
		model = clone
	end
	carrier = part
	return part
end

function J.stop()
	clear()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

function J.fly(foodId: string, speed: number?)
	clear()
	local part = food(foodId, true)
	local name, tint = FoodFx.trail(foodId)
	local z = 420
	part.CFrame = CFrame.new(X, Y + 30, z)
	local handle = VfxKit.play(name, part, { tint = tint })
	if handle then
		table.insert(live, handle)
	end
	local camera = workspace.CurrentCamera
	local v = speed or 160
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 5, function(dt: number)
		z += v * dt
		if z > 1100 then
			z = 420
		end
		local at = Vector3.new(X, Y + 30, z)
		local turn = CFrame.Angles(0, os.clock() * 0.6, 0) * CFrame.Angles(math.rad(22), 0, 0)
		part.CFrame = CFrame.new(at)
		if model then
			model:PivotTo(CFrame.new(at) * turn)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(at + Vector3.new(0, 7, -15), at + Vector3.new(0, -1, 12))
		camera.FieldOfView = 82
	end)
	return name .. (if handle then " playing" else " NOT FOUND")
end

local function park(at: Vector3, far: boolean?)
	local camera = workspace.CurrentCamera
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 5, function()
		camera.CameraType = Enum.CameraType.Scriptable
		if far then
			camera.CFrame = CFrame.lookAt(at + Vector3.new(-4, 6, -30), at)
		else
			camera.CFrame = CFrame.lookAt(at + Vector3.new(-2.6, 1.55, -9.5), at + Vector3.new(2.2, 1, 0))
		end
		camera.FieldOfView = 70
	end)
end

function J.land(foodId: string, freezeAt: number?, far: boolean?, z: number?)
	clear()
	local at = Vector3.new(X, Y + 1.2, z or 700)
	local part = food(foodId, false)
	part.CFrame = CFrame.new(at)
	if model then
		local _, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(at.X, Y + size.Y / 2 + 0.25, at.Z))
	end
	park(at, far)
	local name, tint = FoodFx.landing(foodId)
	local floor = Vector3.new(at.X, Y + 0.15, at.Z)
	-- duration 30: the frozen burst stays until the next call instead of being cleaned up
	local handle = VfxKit.play(name, floor, { tint = tint, duration = 30 })
	if handle then
		table.insert(live, handle)
	end
	task.delay(freezeAt or 0.1, function()
		setTimeScale(0)
	end)
	return name .. (if handle then " playing" else " NOT FOUND")
end

function J.rest(foodId: string, z: number?)
	clear()
	local at = Vector3.new(X, Y + 1.2, z or 700)
	local part = food(foodId, false)
	part.CFrame = CFrame.new(at)
	if model then
		local _, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(at.X, Y + size.Y / 2 + 0.25, at.Z))
	end
	park(at)
	local name, tint = FoodFx.aroma(foodId)
	if not name then
		return "no aroma (a Snack)"
	end
	local handle = VfxKit.play(name, at - Vector3.new(0, 0.6, 0), { tint = tint })
	if handle then
		table.insert(live, handle)
	end
	return name .. (if handle then " playing" else " NOT FOUND")
end

return "FxJudge ready"
