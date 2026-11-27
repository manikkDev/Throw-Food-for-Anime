-- preview.luau - Studio EDIT mode. (Plan 13 phase D.) A look at the set pieces where they stand.
-- Puts copies of two templates on the courts of Plot <PLOT> in Workspace.GroundPreview (dev only;
-- run with _G.GROUND_PREVIEW = false to take them away again, and always before a play test or a
-- save). _G.GROUND_PREVIEW = { plot = 1, post = 3, falls = 5, level = 3, lock = false }, or
-- { left = "Ground_boulder_T7", right = "Ground_peak_T9", level = 3 }.
local RS = game:GetService("ReplicatedStorage")
local want = (_G :: any).GROUND_PREVIEW
local old = workspace:FindFirstChild("GroundPreview")
if old then
	old:Destroy()
end
if want == false then
	return "preview removed"
end
want = want or {}
local plot = workspace.Map.Plots["Plot" .. (want.plot or 1)]
local folder = Instance.new("Folder")
folder.Name = "GroundPreview"
folder.Parent = workspace
local out = {}
-- (`left` / `right` name any template in full, e.g. left = "Ground_boulder_T7")
for court, name in { want.left or ("Ground_post_T" .. (want.post or 1)), want.right or ("Ground_falls_T" .. (want.falls or 4)) } do
	local template = RS.Assets.Grounds:FindFirstChild(name)
	local anchor = plot:FindFirstChild("Ground" .. court)
	if template and anchor then
		local copy = template:Clone()
		for level = (want.level or 3) + 1, 3 do
			local extra = copy:FindFirstChild("L" .. level)
			if extra then
				extra:Destroy()
			end
		end
		local lock = copy:FindFirstChild("Lock")
		if lock and not (want.lock and court == 2) then
			lock:Destroy()
		end
		copy:PivotTo(anchor.CFrame)
		copy.Parent = folder
		table.insert(out, name .. " at " .. tostring(anchor.Position))
	end
end
return table.concat(out, "\n")
