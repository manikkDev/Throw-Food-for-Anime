-- normalize_heroes.luau - run in Studio EDIT mode (through tools/studio/normalize_heroes.py).
--
-- Turns every hero the owner imported or built into the game's STANDARD R15 rig, in one pass, and
-- applies the head rule, so no hero is left "lego" (odd body scales) or with the default face's
-- dots showing on the forehead. This is the same recipe as design/characters/README.md, but it
-- works on ANY rig: `Humanoid:GetAppliedDescription()` gives the avatar's own description (the
-- Insert Avatar plugin does not leave a HumanoidDescription behind, which is why build_r15.luau
-- reported MISSING for them).
--
--   rebuild  a loose avatar (Insert Avatar plugin): description -> scales reset -> fresh rig, then
--            everything the description did not bring (hand-added accessories, layered clothing)
--            is carried across.
--   inplace  a rig already built to the standard (tools/studio/build_from_items.py): only the
--            head rule and the clean-up are applied.
--
-- Input:  _G.NORM = { {src = "<Workspace child>", name = "<Hero>", mode = "rebuild"|"inplace",
--                      parent = "<path of the model that holds src>" (optional)} ... }
-- Output: Workspace.Characters_R15_New/<name> (R15); report in workspace attribute TFANorm.
local NORM = _G.NORM
assert(NORM, "_G.NORM missing: run tools/studio/normalize_heroes.py")

local Players = game:GetService("Players")
local DEFAULT_HEAD = "123480233606534"

local folder = workspace:FindFirstChild("Characters_R15_New")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Characters_R15_New"
	folder.Parent = workspace
end

local function resolve(path: string): Instance?
	local node: Instance = game
	for part in string.gmatch(path, "[^/]+") do
		local nxt = node:FindFirstChild(part)
		if not nxt then
			return nil
		end
		node = nxt
	end
	return node
end

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

local function isLayered(accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	return handle ~= nil and handle:FindFirstChildWhichIsA("WrapLayer") ~= nil
end

-- weld a normal accessory where its attachment says (never from an old weld)
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

local function accessoryKey(accessory: Accessory): string
	local handle = accessory:FindFirstChild("Handle")
	local mesh = handle and (if handle:IsA("MeshPart") then handle.MeshId else "")
	local special = handle and handle:FindFirstChildOfClass("SpecialMesh")
	return (mesh ~= "" and mesh) or (special and special.MeshId) or accessory.Name
end

-- the head rule (design/characters/README.md): hide the default head when something covers it
local function headRule(rig: Model): string
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
	return "default head shown (no cover)"
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

local function ground(rig: Model, at: Vector3)
	rig:PivotTo(CFrame.new(at.X, 10, at.Z))
	local foot = rig:FindFirstChild("LeftFoot")
	local bottom = foot.Position.Y - foot.Size.Y / 2
	rig:PivotTo(rig:GetPivot() * CFrame.new(0, -bottom, 0))
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

local function stats(name: string, rig: Model, source: Model, notes: { string }): string
	local torso, head = rig.UpperTorso, rig.Head
	local count, layered, loose = 0, 0, 0
	for _, accessory in rig:GetChildren() do
		if accessory:IsA("Accessory") then
			count += 1
			if isLayered(accessory) then
				layered += 1
			else
				local handle = accessory:FindFirstChild("Handle")
				local weld = handle and handle:FindFirstChild("AccessoryWeld")
				local rigid = handle and handle:FindFirstChildOfClass("RigidConstraint")
				if not (weld and weld.Part1) and not (rigid and rigid.Attachment1) then
					loose += 1
					table.insert(notes, "LOOSE " .. accessory.Name)
				end
			end
		end
	end
	return string.format(
		"%s: shoulder=%.2f root=%.2f head=%.2f acc=%d (layered %d, loose %d) shirt=%s pants=%s | %s",
		name,
		torso.Position.Y + torso.Size.Y / 2,
		rig.HumanoidRootPart.Position.Y,
		head.Size.Y,
		count,
		layered,
		loose,
		tostring(rig:FindFirstChildOfClass("Shirt") ~= nil),
		tostring(rig:FindFirstChildOfClass("Pants") ~= nil),
		table.concat(notes, "; ")
	)
end

workspace:SetAttribute("TFANorm", "running")
task.spawn(function()
	local report = {}
	for i, row in NORM do
		local holder = if row.parent then resolve(row.parent) else workspace
		local source = holder and holder:FindFirstChild(row.src)
		local humanoid = source and source:FindFirstChildOfClass("Humanoid")
		if not source or not humanoid then
			table.insert(report, row.name .. ": MISSING source " .. tostring(row.src))
			continue
		end
		local notes = {}
		local rig: Model
		if row.mode == "inplace" then
			rig = source
			rig.Name = row.name .. " (R15)"
			rig.Parent = folder
			clean(rig)
			table.insert(notes, "in place")
		else
			local desc = humanoid:GetAppliedDescription()
			desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
			desc.BodyTypeScale, desc.ProportionScale = 0, 0
			local ok, built = pcall(function()
				return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			end)
			if not ok then
				table.insert(report, row.name .. ": BUILD FAILED " .. tostring(built))
				continue
			end
			rig = built
			rig.Name = row.name .. " (R15)"
			local old = folder:FindFirstChild(rig.Name)
			if old then
				old:Destroy()
			end
			rig.Parent = folder
			local newHum = rig:FindFirstChildOfClass("Humanoid")

			for _, class in { "Shirt", "Pants", "ShirtGraphic" } do
				local theirs = source:FindFirstChildOfClass(class)
				local mine = rig:FindFirstChildOfClass(class)
				if theirs and not mine then
					theirs:Clone().Parent = rig
					table.insert(notes, "+" .. class)
				end
			end
			local bc = source:FindFirstChildOfClass("BodyColors")
			local nbc = rig:FindFirstChildOfClass("BodyColors")
			if bc and nbc then
				for _, prop in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
					(nbc :: any)[prop] = (bc :: any)[prop]
				end
			end
			-- what the description did not bring: hand-added accessories and layered clothing
			local have = {}
			for _, accessory in rig:GetChildren() do
				if accessory:IsA("Accessory") then
					have[accessoryKey(accessory)] = true
				end
			end
			for _, accessory in source:GetChildren() do
				if accessory:IsA("Accessory") and not have[accessoryKey(accessory)] then
					local copy = accessory:Clone()
					for _, k in copy:GetDescendants() do
						if k:IsA("Weld") or k:IsA("RigidConstraint") or k:IsA("WeldConstraint") then
							k:Destroy()
						end
					end
					if isLayered(copy) then
						newHum:AddAccessory(copy)
						table.insert(notes, "+layered " .. accessory.Name)
					else
						copy.Parent = rig
						table.insert(notes, (if attach(rig, copy) then "+acc " else "UNATTACHED ") .. accessory.Name)
					end
				end
			end
			-- keep the hand-set head state of the original when it hid the head
			clean(rig)
		end
		ground(rig, Vector3.new((i - (#NORM + 1) / 2) * 7, 10, 40))
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
		table.insert(notes, headRule(rig))
		rig:SetAttribute("Hero", row.name)
		table.insert(report, stats(row.name, rig, source, notes))
		workspace:SetAttribute("TFANorm", "running " .. i .. "/" .. #NORM)
	end
	workspace:SetAttribute("TFANorm", table.concat(report, "\n"))
end)
return "started"
