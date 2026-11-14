-- bake_characters.luau - run in Studio EDIT mode through execute_luau.
--
-- Turns the finished R15 rigs (Workspace.Characters_R15, or
-- ServerStorage.CharacterSources.R15_Final once they have been archived) into
-- the templates the client clones: ReplicatedStorage.Assets.Characters.Char_<id>.
--
-- WHY A BAKE AND NOT THE RAW RIG (each of these was measured, 2026-11-14):
--   * a rig from CreateHumanoidModelFromDescription has NO Motor6Ds: its joints
--     are 15 AnimationConstraints + 14 BallSocketConstraints, i.e. physics. A
--     plot of 26 of those is 400 simulated parts. Humanoid:BuildRigFromAttachments
--     does NOT help: in this Studio it rebuilds the same constraints (measured:
--     0 Motor6Ds after calling it). So the 15 Motor6Ds are built here, by hand,
--     from the RigAttachment pairs. They are free while the root is anchored.
--   * it carries ~300 instances, about 250 of them useless on a pedestal (the
--     Animate script and its 27 Animation objects, 71 Vector3Values...).
--   * the Humanoid must stay (classic Shirt/Pants only render beside one) but
--     its state machine must be off, or 150 humanoids each run physics states.
--
-- The roster line is generated from design/characters/roster.json:
--   python -c "import json;r=json.load(open('design/characters/roster.json'));print('local ROSTER = {'+', '.join('{id=%s, source=%s}'%(json.dumps(x['Id']),json.dumps(x['Source'])) for x in r)+'}')"
-- Paste it over the next line, then run the whole file.

local ROSTER = {} -- <<< generated line goes here

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local archive = SS:FindFirstChild("CharacterSources")
local sources = workspace:FindFirstChild("Characters_R15") or (archive and archive:FindFirstChild("R15_Final"))
assert(sources, "no Characters_R15 folder in Workspace or ServerStorage.CharacterSources")

local assets = RS:FindFirstChild("Assets")
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = RS
end
local old = assets:FindFirstChild("Characters")
if old then
	old:Destroy()
end
local out = Instance.new("Folder")
out.Name = "Characters"

local STRIP = {
	AnimationConstraint = true, BallSocketConstraint = true, NoCollisionConstraint = true,
	BillboardGui = true, Vector3Value = true, StringValue = true, NumberValue = true,
	HumanoidDescription = true, FaceControls = true, Status = true, BindableFunction = true,
	LocalScript = true, Script = true, ModuleScript = true, BodyPartDescription = true,
	AccessoryDescription = true, RigidConstraint = true, Configuration = true,
}

-- child part -> { joint name, parent part }: the standard R15 tree
local JOINTS = {
	LowerTorso = { "Root", "HumanoidRootPart" }, UpperTorso = { "Waist", "LowerTorso" },
	Head = { "Neck", "UpperTorso" },
	LeftUpperArm = { "LeftShoulder", "UpperTorso" }, LeftLowerArm = { "LeftElbow", "LeftUpperArm" },
	LeftHand = { "LeftWrist", "LeftLowerArm" },
	RightUpperArm = { "RightShoulder", "UpperTorso" }, RightLowerArm = { "RightElbow", "RightUpperArm" },
	RightHand = { "RightWrist", "RightLowerArm" },
	LeftUpperLeg = { "LeftHip", "LowerTorso" }, LeftLowerLeg = { "LeftKnee", "LeftUpperLeg" },
	LeftFoot = { "LeftAnkle", "LeftLowerLeg" },
	RightUpperLeg = { "RightHip", "LowerTorso" }, RightLowerLeg = { "RightKnee", "RightUpperLeg" },
	RightFoot = { "RightAnkle", "RightLowerLeg" },
}

local report = {}
for _, row in ROSTER do
	local src = sources:FindFirstChild(row.source .. " (R15)")
	if not src then
		table.insert(report, "MISSING " .. row.source)
		continue
	end
	local rig = src:Clone()
	rig.Name = "Char_" .. row.id
	local root = rig.HumanoidRootPart
	local foot = rig.LeftFoot
	local footOffset = root.Position.Y - (foot.Position.Y - foot.Size.Y / 2)
	local headHidden = rig.Head.Transparency >= 1

	local hasWrap = rig:FindFirstChildWhichIsA("WrapLayer", true) ~= nil
	for _, d in rig:GetDescendants() do
		if STRIP[d.ClassName] or (d:IsA("WrapTarget") and not hasWrap) then
			d:Destroy()
		end
	end

	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.EvaluateStateMachine = false
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.AutomaticScalingEnabled = false
	hum.DisplayName = ""
	for childName, joint in JOINTS do
		local child, parent = rig:FindFirstChild(childName), rig:FindFirstChild(joint[2])
		local a0 = parent and parent:FindFirstChild(joint[1] .. "RigAttachment")
		local a1 = child and child:FindFirstChild(joint[1] .. "RigAttachment")
		if a0 and a1 then
			local motor = Instance.new("Motor6D")
			motor.Name = joint[1]
			motor.Part0 = parent
			motor.Part1 = child
			motor.C0 = a0.CFrame
			motor.C1 = a1.CFrame
			motor.Parent = child
		end
	end
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end

	local parts, motors, welds = 0, 0, 0
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = (d == root)
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("Motor6D") then
			motors += 1
		elseif d:IsA("Weld") then
			welds += 1
		end
	end
	-- the model pivots at its FEET, so the client can PivotTo a pedestal top
	root.PivotOffset = CFrame.new(0, -footOffset, 0)
	rig.PrimaryPart = root
	rig:SetAttribute("HeroId", row.id)
	rig:SetAttribute("HeadHidden", headHidden)
	rig:SetAttribute("FootOffset", footOffset)
	rig:PivotTo(CFrame.new(0, 0, 0))
	rig.Parent = out
	table.insert(report, string.format("%s parts=%d motors=%d welds=%d total=%d foot=%.2f%s", row.id, parts, motors, welds,
		#rig:GetDescendants(), footOffset, motors ~= 15 and " <<< MOTORS" or ""))
end
out.Parent = assets

return #out:GetChildren() .. " templates\n" .. table.concat(report, "\n")
