-- build_from_items.luau - Studio EDIT mode. Builds heroes from marketplace item ids alone (no
-- username, no Load Character plugin). Run through tools/studio/build_from_items.py, which embeds
-- _G.ITEMS = { { name = "Yuno", ids = { ... } }, ... } and reads the report back.
--
-- Each id is looked up (MarketplaceService:GetProductInfo) for its asset type and put on a fresh
-- HumanoidDescription: classic clothes, face, head, body parts, rigid accessories and layered
-- clothing (jackets, sweaters, ...). The rig is built with the game's standard body (every scale 1,
-- BodyTypeScale 0, ProportionScale 0; see design/characters/README.md), stood on y = 0 in
-- Workspace.Characters_R15_New as "<Name> (R15)". The yielding work runs in a task; the report goes
-- to the workspace attribute TFAItems.
local Players = game:GetService("Players")
local Market = game:GetService("MarketplaceService")
local list = _G.ITEMS
assert(list, "_G.ITEMS missing: run tools/studio/build_from_items.py")

local SKIN = Color3.fromRGB(255, 220, 185) -- anime light skin, used unless a row gives `skin`

-- asset type id -> how it goes on a HumanoidDescription
local RIGID = { [8] = "Hat", [41] = "Hair", [42] = "Face", [43] = "Neck", [44] = "Shoulder", [45] = "Front", [46] = "Back", [47] = "Waist" }
local LAYERED = {
	[64] = "TShirt",
	[65] = "Shirt",
	[66] = "Pants",
	[67] = "Jacket",
	[68] = "Sweater",
	[69] = "Shorts",
	[70] = "LeftShoe",
	[71] = "RightShoe",
	[72] = "DressSkirt",
	[76] = "Eyebrow",
	[77] = "Eyelash",
}
local PROPERTY = {
	[2] = "GraphicTShirt",
	[11] = "Shirt",
	[12] = "Pants",
	[17] = "Head",
	[18] = "Face",
	[79] = "Head",
	[27] = "Torso",
	[28] = "RightArm",
	[29] = "LeftArm",
	[30] = "LeftLeg",
	[31] = "RightLeg",
}
-- layered pieces stack inner to outer by this order
local LAYER_ORDER = { TShirt = 1, Shirt = 2, Sweater = 3, Jacket = 5, Pants = 2, Shorts = 3, DressSkirt = 4, LeftShoe = 6, RightShoe = 6, Eyebrow = 1, Eyelash = 1 }

local folder = workspace:FindFirstChild("Characters_R15_New")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Characters_R15_New"
	folder.Parent = workspace
end

workspace:SetAttribute("TFAItems", "running")
task.spawn(function()
	local report = {}
	for i, row in list do
		local desc = Instance.new("HumanoidDescription")
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		local skin = if row.skin then Color3.fromHex(row.skin) else SKIN
		desc.HeadColor, desc.TorsoColor = skin, skin
		desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin
		local accessories, notes = {}, {}
		for _, id in row.ids do
			local ok, info = pcall(Market.GetProductInfo, Market, id, Enum.InfoType.Asset)
			if not ok or not info then
				table.insert(notes, `{id}: NOT FOUND`)
				continue
			end
			local t = info.AssetTypeId
			if RIGID[t] then
				table.insert(accessories, { AssetId = id, AccessoryType = Enum.AccessoryType[RIGID[t]], IsLayered = false })
				table.insert(notes, `{RIGID[t]} "{info.Name}"`)
			elseif LAYERED[t] then
				local kind = LAYERED[t]
				table.insert(accessories, {
					AssetId = id,
					AccessoryType = Enum.AccessoryType[kind],
					IsLayered = true,
					Order = LAYER_ORDER[kind] or 3,
				})
				table.insert(notes, `layered {kind} "{info.Name}"`)
			elseif PROPERTY[t] then
				(desc :: any)[PROPERTY[t]] = id
				table.insert(notes, `{PROPERTY[t]} "{info.Name}"`)
			else
				table.insert(notes, `{id}: UNUSED asset type {t} "{info.Name}"`)
			end
		end
		local okSet, setErr = pcall(function()
			desc:SetAccessories(accessories, true)
		end)
		if not okSet then
			table.insert(notes, "SetAccessories FAILED " .. tostring(setErr))
		end
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok then
			table.insert(report, row.name .. ": BUILD FAILED " .. tostring(rig))
			continue
		end
		rig.Name = row.name .. " (R15)"
		rig:SetAttribute("ItemIds", table.concat(row.ids, ","))
		local old = folder:FindFirstChild(rig.Name)
		if old then
			old:Destroy()
		end
		rig.Parent = folder
		rig:PivotTo(CFrame.new((i - (#list + 1) / 2) * 7, 10, 40))
		local foot = rig:FindFirstChild("LeftFoot") :: BasePart
		rig:PivotTo(rig:GetPivot() * CFrame.new(0, -(foot.Position.Y - foot.Size.Y / 2), 0))
		local count, layered = 0, 0
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Accessory") then
				count += 1
				local handle = d:FindFirstChild("Handle")
				if handle and handle:FindFirstChildOfClass("WrapLayer") then
					layered += 1
				end
			end
		end
		local torso = rig:FindFirstChild("UpperTorso") :: BasePart
		table.insert(
			report,
			string.format(
				"%s: shoulder=%.2f acc=%d (layered %d) shirt=%s pants=%s | %s",
				row.name,
				torso.Position.Y + torso.Size.Y / 2,
				count,
				layered,
				tostring(rig:FindFirstChildOfClass("Shirt") ~= nil),
				tostring(rig:FindFirstChildOfClass("Pants") ~= nil),
				table.concat(notes, "; ")
			)
		)
		workspace:SetAttribute("TFAItems", `running {i}/{#list}`)
	end
	workspace:SetAttribute("TFAItems", table.concat(report, "\n"))
end)
return "started"
