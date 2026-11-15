-- build_r15.luau - run in Studio EDIT mode:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/build_r15.luau
-- then read the result (the build yields, so the call itself returns at once):
--   ... luau --code "return workspace:GetAttribute('TFABuild')"
--
-- Rebuilds imported avatars (Workspace.<source name>) as the game's standard
-- R15 rig: every hero the same height, classic blocky proportions, every
-- accessory welded where its attachment says, standing on y = 0. The results go
-- to Workspace.Characters_R15_New as "<Source> (R15)", in a row, for review.
-- The originals are not touched.
--
-- WHY A REBUILD AND NOT A RESCALE (measured 2026-11-14, second batch of 12):
--   the Load Character plugin copies the wearer's own body scales, so the same
--   import gave shoulder heights from 3.68 (Joseph) to 5.01 (Lelouch) studs and
--   BodyTypeScale anywhere from 0 to 1. Classic accessories only fit the classic
--   body (BodyTypeScale 0, ProportionScale 0), and a lane where one hero is a
--   third taller than the next reads as a bug. Building from the saved
--   HumanoidDescription with the six scales reset gives one body for everyone and
--   lets Roblox place the accessories itself.
--
-- Rules carried over from the first batch (design/characters/README.md):
--   * BodyTypeScale = 0 and ProportionScale = 0, or the rig is 0.19 studs taller
--   * move rigs with PivotTo only: a per-part CFrame loop scrambles a welded rig
--   * afterwards every Accessory must have a weld with both parts set
--   * anything on the original that the description did not bring (clothes, an
--     accessory) is cloned across and attached by attachment name
--
-- The head rule (hide the default head under a full face cover) is NOT applied
-- here: it is decided from close-up pictures. See design/characters/README.md.

-- { source model name in Workspace, name to give the result }
local LIST = {
	{ "Tengen Uzui", "Tengen Uzui" },
	{ "Aizen Sosuke", "Aizen Sosuke" },
	{ "Ken Kaneki", "Ken Kaneki" },
	{ "Frieren", "Frieren" },
	{ "Lawliet", "Lawliet" },
	{ "Denji", "Denji" },
	{ "Power", "Power" },
	{ "Naoya Zenin", "Naoya Zenin" },
	{ "Makima", "Makima" },
	{ "Megumi Fushiguro", "Megumi Fushiguro" },
	{ "Marin Kitagawa", "Marin Kitagawa" },
	{ "Ayanokoji", "Ayanokoji" },
	{ "Subaru Natsuki", "Subaru Natsuki" },
	{ "Mahoraga", "Mahoraga" },
	{ "Zenitsu Agatsuma", "Zenitsu Agatsuma" },
	{ "Yoriichi Tsugikuni", "Yoriichi Tsugikuni" },
}
local ROW_Z = 40 -- where the review row stands
local SPACING = 7

local Players = game:GetService("Players")

local folder = workspace:FindFirstChild("Characters_R15_New")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Characters_R15_New"
	folder.Parent = workspace
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

-- Weld an accessory where its attachment says (never from an old weld).
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

workspace:SetAttribute("TFABuild", "running")
task.spawn(function()
	local report = {}
	for i, row in LIST do
		local source = workspace:FindFirstChild(row[1])
		local humanoid = source and source:FindFirstChildOfClass("Humanoid")
		local saved = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
		if not source or not saved then
			table.insert(report, row[2] .. ": MISSING source or description")
			continue
		end
		local desc = saved:Clone()
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok then
			table.insert(report, row[2] .. ": BUILD FAILED " .. tostring(rig))
			continue
		end
		rig.Name = row[2] .. " (R15)"
		local old = folder:FindFirstChild(rig.Name)
		if old then
			old:Destroy()
		end
		rig.Parent = folder

		-- anything the original wears that the description did not bring
		local notes = {}
		for _, class in { "Shirt", "Pants", "ShirtGraphic" } do
			local theirs = source:FindFirstChildOfClass(class)
			if theirs and not rig:FindFirstChildOfClass(class) then
				theirs:Clone().Parent = rig
				table.insert(notes, "+" .. class)
			end
		end
		local have = {}
		for _, accessory in rig:GetChildren() do
			if accessory:IsA("Accessory") then
				have[accessoryKey(accessory)] = true
			end
		end
		for _, accessory in source:GetChildren() do
			if accessory:IsA("Accessory") and not have[accessoryKey(accessory)] then
				local copy = accessory:Clone()
				copy.Parent = rig
				table.insert(notes, (if attach(rig, copy) then "+acc " else "UNATTACHED ") .. accessory.Name)
			end
		end

		-- stand it in the review row, feet on y = 0, facing the camera side (-Z)
		rig:PivotTo(CFrame.new((i - (#LIST + 1) / 2) * SPACING, 10, ROW_Z))
		local foot = rig:FindFirstChild("LeftFoot")
		local bottom = foot.Position.Y - foot.Size.Y / 2
		rig:PivotTo(rig:GetPivot() * CFrame.new(0, -bottom, 0))
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end

		-- every accessory welded, and sitting where its attachment says
		local count, loose, layered = 0, 0, 0
		for _, accessory in rig:GetChildren() do
			if accessory:IsA("Accessory") then
				count += 1
				local handle = accessory:FindFirstChild("Handle")
				if handle and handle:FindFirstChildOfClass("WrapLayer") then
					layered += 1
				else
					local att = handle and handle:FindFirstChildOfClass("Attachment")
					local body = att and bodyAttachment(rig, att.Name)
					local weld = handle and handle:FindFirstChild("AccessoryWeld")
					local gap = if att and body then (att.WorldPosition - body.WorldPosition).Magnitude else 99
					if not weld or not weld.Part1 or gap > 0.05 then
						if not attach(rig, accessory) then
							loose += 1
							table.insert(notes, "LOOSE " .. accessory.Name)
						else
							table.insert(notes, "re-welded " .. accessory.Name)
						end
					end
				end
			end
		end
		local sourceCount = 0
		for _, accessory in source:GetChildren() do
			if accessory:IsA("Accessory") then
				sourceCount += 1
			end
		end
		local torso = rig.UpperTorso
		local head = rig.Head
		table.insert(
			report,
			string.format(
				"%s: shoulder=%.2f root=%.2f head=(%.2f,%.2f,%.2f) acc=%d (source %d, layered %d, loose %d) shirt=%s pants=%s %s",
				row[2],
				torso.Position.Y + torso.Size.Y / 2,
				rig.HumanoidRootPart.Position.Y,
				head.Size.X,
				head.Size.Y,
				head.Size.Z,
				count,
				sourceCount,
				layered,
				loose,
				tostring(rig:FindFirstChildOfClass("Shirt") ~= nil),
				tostring(rig:FindFirstChildOfClass("Pants") ~= nil),
				table.concat(notes, ", ")
			)
		)
		workspace:SetAttribute("TFABuild", "running " .. i .. "/" .. #LIST)
	end
	workspace:SetAttribute("TFABuild", table.concat(report, "\n"))
end)
return "started"
