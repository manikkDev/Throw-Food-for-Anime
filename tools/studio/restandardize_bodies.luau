-- restandardize_bodies.luau - run in Studio EDIT mode (through tools/studio/restandardize_bodies.py).
--
-- Some heroes kept the body PARTS of their avatar (Rthro / slim / bulky body bundles): their torso, arms and
-- legs are other meshes than the game's standard R15, which reads as "lego". This rebuilds such a rig in
-- ServerStorage.CharacterSources.R15_Final with the STANDARD R15 body parts (torso, arms, legs = 0 in the
-- description, every scale 1), keeping EVERYTHING ELSE of the old rig as it is: its head and face (from the
-- description), clothes, body colours and every accessory (cloned from the old rig, re-welded to the new
-- body, layered ones through AddAccessory). Hand edits therefore survive. The old rig is archived in
-- ServerStorage.CharacterSources.R15_Prev (never delete).
--
-- Input:  _G.FIX = { "<rig name in R15_Final>", ... }
-- Output: R15_Final/<name> replaced; report in workspace attribute TFAFix.
local FIX = _G.FIX
assert(FIX, "_G.FIX missing: run tools/studio/restandardize_bodies.py")

local Players = game:GetService("Players")
local DEFAULT_HEAD = "123480233606534"
local SOURCES = game.ServerStorage.CharacterSources
local final = SOURCES.R15_Final
local prev = SOURCES:FindFirstChild("R15_Prev")
if not prev then
	prev = Instance.new("Folder")
	prev.Name = "R15_Prev"
	prev.Parent = SOURCES
end
local temp = workspace:FindFirstChild("Characters_R15_New")
if not temp then
	temp = Instance.new("Folder")
	temp.Name = "Characters_R15_New"
	temp.Parent = workspace
end

local STANDARD = {
	UpperTorso = Vector3.new(2, 1.6, 1),
	LowerTorso = Vector3.new(2, 0.4, 1),
	LeftUpperArm = Vector3.new(1, 1.17, 1),
	LeftLowerArm = Vector3.new(1, 1.05, 1),
	LeftHand = Vector3.new(1, 0.3, 1),
	LeftUpperLeg = Vector3.new(1, 1.22, 1),
	LeftLowerLeg = Vector3.new(1, 1.19, 1),
	LeftFoot = Vector3.new(1, 0.3, 1),
}

local function bodyAttachment(rig: Model, name: string): Attachment?
	for _, part in rig:GetChildren() do
		if part:IsA("BasePart") then
			local found = part:FindFirstChild(name)
			if found and found:IsA("Attachment") then
				return found
			end
		end
	end
	return nil
end

local function isLayered(accessory: Instance): boolean
	local handle = accessory:FindFirstChild("Handle")
	return handle ~= nil and handle:FindFirstChildWhichIsA("WrapLayer") ~= nil
end

local function attach(rig: Model, accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	local handleAtt = handle and handle:FindFirstChildOfClass("Attachment")
	local bodyAtt = handleAtt and bodyAttachment(rig, handleAtt.Name)
	if not handle or not handleAtt or not bodyAtt then
		return false
	end
	for _, old in handle:GetChildren() do
		if old:IsA("Weld") or old:IsA("WeldConstraint") or old:IsA("RigidConstraint") then
			old:Destroy()
		end
	end
	handle.Anchored = false
	handle.CFrame = bodyAtt.WorldCFrame * handleAtt.CFrame:Inverse()
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = bodyAtt.Parent
	weld.C0 = handleAtt.CFrame
	weld.C1 = bodyAtt.CFrame
	weld.Parent = handle
	return true
end

local function headRule(rig: Model, oldHeadHidden: boolean): string
	local head = rig:FindFirstChild("Head")
	if not head or not head:IsA("MeshPart") then
		return "nohead"
	end
	local isDefault = string.find(head.MeshId, DEFAULT_HEAD, 1, true) ~= nil
	if not isDefault then
		head.Transparency = 0
		head:SetAttribute("HeadHidden", nil)
		return "custom head kept"
	end
	for _, accessory in rig:GetChildren() do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		local att = handle and handle:FindFirstChildOfClass("Attachment")
		if att and (att.Name == "FaceCenterAttachment" or att.Name == "FaceFrontAttachment") then
			local s = handle.Size
			if s.X >= 1.1 and s.Y >= 1.1 and s.Z >= 1.0 then
				head.Transparency = 1
				head:SetAttribute("HeadHidden", true)
				return "head hidden (face cover " .. accessory.Name .. ")"
			end
		end
	end
	head.Transparency = 0
	head:SetAttribute("HeadHidden", nil)
	return "default head shown" .. (if oldHeadHidden then " (WAS hidden: check)" else "")
end

local function clean(rig: Model)
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
			or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
end

local function ground(rig: Model)
	rig:PivotTo(CFrame.new(0, 10, 60))
	local foot = rig:FindFirstChild("LeftFoot")
	rig:PivotTo(rig:GetPivot() * CFrame.new(0, -(foot.Position.Y - foot.Size.Y / 2), 0))
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

local function standardOffBy(rig: Model): number
	local worst = 0
	for name, size in STANDARD do
		local p = rig:FindFirstChild(name)
		if not p then
			return 99
		end
		worst = math.max(worst, (p.Size - size).Magnitude)
	end
	return worst
end

workspace:SetAttribute("TFAFix", "running")
task.spawn(function()
	local report = {}
	for i, name in FIX do
		local old = final:FindFirstChild(name)
		local oldHum = old and old:FindFirstChildOfClass("Humanoid")
		if not old or not oldHum then
			table.insert(report, name .. ": MISSING")
			continue
		end
		local notes = {}
		local desc = oldHum:GetAppliedDescription()
		desc.Torso, desc.LeftArm, desc.RightArm, desc.LeftLeg, desc.RightLeg = 0, 0, 0, 0, 0
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		desc:SetAccessories({}, true) -- accessories come from the OLD rig, hand edits and all
		desc.HatAccessory, desc.HairAccessory, desc.FaceAccessory, desc.NeckAccessory = "", "", "", ""
		desc.ShouldersAccessory, desc.FrontAccessory, desc.BackAccessory, desc.WaistAccessory = "", "", "", ""
		desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
		local ok, built = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok then
			table.insert(report, name .. ": BUILD FAILED " .. tostring(built))
			continue
		end
		local rig: Model = built
		rig.Name = old.Name
		rig.Parent = temp
		local newHum = rig:FindFirstChildOfClass("Humanoid")
		-- the new rig starts with whatever the description left; the old rig's own are the truth
		for _, class in { "Shirt", "Pants", "ShirtGraphic" } do
			local mine = rig:FindFirstChildOfClass(class)
			if mine then
				mine:Destroy()
			end
			local theirs = old:FindFirstChildOfClass(class)
			if theirs then
				theirs:Clone().Parent = rig
			end
		end
		for _, a in rig:GetChildren() do
			if a:IsA("Accessory") then
				a:Destroy()
			end
		end
		local oldBC, newBC = old:FindFirstChildOfClass("BodyColors"), rig:FindFirstChildOfClass("BodyColors")
		if oldBC and newBC then
			for _, prop in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
				(newBC :: any)[prop] = (oldBC :: any)[prop]
			end
		end
		local nLayered, nPlain, nFailed = 0, 0, 0
		for _, accessory in old:GetChildren() do
			if accessory:IsA("Accessory") then
				local copy = accessory:Clone()
				for _, k in copy:GetDescendants() do
					if k:IsA("Weld") or k:IsA("RigidConstraint") or k:IsA("WeldConstraint") then
						k:Destroy()
					end
				end
				if isLayered(copy) then
					newHum:AddAccessory(copy)
					nLayered += 1
				else
					copy.Parent = rig
					if attach(rig, copy) then
						nPlain += 1
					else
						nFailed += 1
						table.insert(notes, "UNATTACHED " .. accessory.Name)
					end
				end
			end
		end
		clean(rig)
		ground(rig)
		-- any accessory not welded where its attachment says is re-welded
		for _, accessory in rig:GetChildren() do
			if accessory:IsA("Accessory") and not isLayered(accessory) then
				local handle = accessory:FindFirstChild("Handle")
				local att = handle and handle:FindFirstChildOfClass("Attachment")
				local body = att and bodyAttachment(rig, att.Name)
				local weld = handle and handle:FindFirstChild("AccessoryWeld")
				local gap = if att and body then (att.WorldPosition - body.WorldPosition).Magnitude else 99
				if not weld or not weld.Part1 or gap > 0.05 then
					if attach(rig, accessory) then
						table.insert(notes, "re-welded " .. accessory.Name)
					end
				end
			end
		end
		local oldHead, newHead = old:FindFirstChild("Head"), rig:FindFirstChild("Head")
		if oldHead and newHead and oldHead.MeshId ~= newHead.MeshId then
			table.insert(notes, "HEAD MESH DIFFERS old=" .. oldHead.MeshId .. " new=" .. newHead.MeshId)
		end
		table.insert(notes, headRule(rig, oldHead ~= nil and oldHead:GetAttribute("HeadHidden") == true))
		rig:SetAttribute("Hero", old:GetAttribute("Hero") or name)
		-- swap: archive the old, install the new
		old.Name = name .. " [prev " .. os.date("%H%M%S") .. "]"
		old.Parent = prev
		rig.Parent = final
		table.insert(report, string.format(
			"%s: offBy=%.3f acc=%d (layered %d plain %d failed %d) | %s",
			name, standardOffBy(rig), nLayered + nPlain + nFailed, nLayered, nPlain, nFailed, table.concat(notes, "; ")))
		workspace:SetAttribute("TFAFix", "running " .. i .. "/" .. #FIX)
	end
	workspace:SetAttribute("TFAFix", table.concat(report, "\n"))
end)
return "started"
