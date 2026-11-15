--!strict
-- ThrowPose - a procedural overhand throw on an R15 character, driven on the
-- Motor6Ds (`Motor6D.Transform`, written every RenderStepped while it runs).
--
-- A STAND-IN until the authored throw clip arrives in section 4. Everything
-- about the motion is the POSE table below; `ThrowPose.start` only plays it.
-- A character without these joints (R6, a rig mid-respawn) simply does not
-- move: the caller's timing is unaffected.

local RunService = game:GetService("RunService")

-- Joint angles in degrees (X, Y, Z of the joint's Transform), at a fraction
-- of the throw. On an R15 joint: +X swings a limb FORWARD and up, +Y turns
-- the part to its LEFT, -X leans it forward at the root.
--   0.00 stand   0.55 wound up (arm up and back, chest turned away)
--   0.72 RELEASE (arm whipped forward, chest through, front foot planted)
--   1.00 follow through, back to standing
local RELEASE = 0.72
local POSE: { { at: number, joints: { [string]: Vector3 } } } = {
	{
		at = 0,
		joints = {
			Root = Vector3.new(0, 0, 0),
			Waist = Vector3.new(0, 0, 0),
			RightShoulder = Vector3.new(0, 0, 0),
			RightElbow = Vector3.new(0, 0, 0),
			LeftShoulder = Vector3.new(0, 0, 0),
			LeftHip = Vector3.new(0, 0, 0),
			RightHip = Vector3.new(0, 0, 0),
		},
	},
	{
		at = 0.55,
		joints = {
			Root = Vector3.new(6, -10, 0),
			Waist = Vector3.new(4, -38, 0),
			RightShoulder = Vector3.new(205, 0, 0),
			RightElbow = Vector3.new(70, 0, 0),
			LeftShoulder = Vector3.new(70, 0, 0),
			LeftHip = Vector3.new(28, 0, 0),
			RightHip = Vector3.new(-14, 0, 0),
		},
	},
	{
		at = RELEASE,
		joints = {
			Root = Vector3.new(-12, 8, 0),
			Waist = Vector3.new(-10, 30, 0),
			RightShoulder = Vector3.new(80, 0, 0),
			RightElbow = Vector3.new(8, 0, 0),
			LeftShoulder = Vector3.new(-25, 0, 0),
			LeftHip = Vector3.new(34, 0, 0),
			RightHip = Vector3.new(-22, 0, 0),
		},
	},
	{
		at = 1,
		joints = {
			Root = Vector3.new(0, 0, 0),
			Waist = Vector3.new(0, 0, 0),
			RightShoulder = Vector3.new(20, 0, 0),
			RightElbow = Vector3.new(0, 0, 0),
			LeftShoulder = Vector3.new(0, 0, 0),
			LeftHip = Vector3.new(0, 0, 0),
			RightHip = Vector3.new(0, 0, 0),
		},
	},
}

export type Handle = {
	--- os.clock() time of the release frame (the food leaves the hand).
	releaseAt: number,
	--- The hand that holds the food, if the character has one.
	hand: BasePart?,
	--- End the pose now and put every joint back.
	stop: () -> (),
}

local ThrowPose = {}

local function angles(v: Vector3): CFrame
	return CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

-- the pose at fraction `u`: the two keys around it, eased between
local function sample(joint: string, u: number): CFrame
	for index = 2, #POSE do
		local a, b = POSE[index - 1], POSE[index]
		if u <= b.at then
			local span = math.max(b.at - a.at, 1e-3)
			local alpha = math.clamp((u - a.at) / span, 0, 1)
			-- wind up eases in and out; the whip to the release accelerates
			local eased = if b.at == RELEASE then alpha * alpha else alpha * alpha * (3 - 2 * alpha)
			return angles(a.joints[joint]):Lerp(angles(b.joints[joint]), eased)
		end
	end
	return CFrame.identity
end

--- Play the throw on `character` over `seconds`. Returns at once; the pose
--- runs on RenderStepped and restores every joint when it ends or is stopped.
function ThrowPose.start(character: Model?, seconds: number): Handle
	local motors: { [string]: Motor6D } = {}
	local hand: BasePart? = nil
	if character then
		for joint in POSE[1].joints do
			local found = character:FindFirstChild(joint, true)
			if found and found:IsA("Motor6D") then
				motors[joint] = found
			end
		end
		local rightHand = character:FindFirstChild("RightHand")
		if rightHand and rightHand:IsA("BasePart") then
			hand = rightHand
		end
	end

	local t0 = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
			for _, motor in motors do
				motor.Transform = CFrame.identity
			end
		end
	end
	if next(motors) ~= nil then
		connection = RunService.RenderStepped:Connect(function()
			local u = (os.clock() - t0) / math.max(seconds, 1e-3)
			if u >= 1 then
				stop()
				return
			end
			for joint, motor in motors do
				motor.Transform = sample(joint, u)
			end
		end)
	end
	return { releaseAt = t0 + seconds * RELEASE, hand = hand, stop = stop }
end

return ThrowPose
