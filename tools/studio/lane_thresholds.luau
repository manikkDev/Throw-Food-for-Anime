-- lane_thresholds.luau - Studio EDIT mode, ONE-OFF (2026-11-22), safe to run again.
-- Every zone's floor kit stops 6 studs short of the next zone's (strips end at 520, the next begin at
-- 526, and so on). Rock used to lie close under that slot; lane_deeper.luau cut the trench deeper and
-- the slot became a strip of void across the lane (owner: "there's this gap"). This lays a stone
-- threshold in each slot, level with the paving, under the next zone's gate.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local lanes = workspace.Map.Lanes
local spans = {}
for _, f in lanes:GetChildren() do
	if f.Name:sub(1, 5) == "Zone_" then
		local lo, hi, top = math.huge, -math.huge, 0
		for _, c in f:GetChildren() do
			if c:IsA("BasePart") and (c.Name:sub(1, 6) == "Paving" or c.Name:sub(1, 5) == "Strip") then
				lo = math.min(lo, c.Position.Z - c.Size.Z / 2)
				hi = math.max(hi, c.Position.Z + c.Size.Z / 2)
				if c.Name:sub(1, 6) == "Paving" then
					top = c.Position.Y + c.Size.Y / 2
				end
			end
		end
		table.insert(spans, { folder = f, lo = lo, hi = hi, top = top })
	end
end
table.sort(spans, function(a, b)
	return a.lo < b.lo
end)
local made = 0
for i = 1, #spans - 1 do
	local a, b = spans[i], spans[i + 1]
	local gap = b.lo - a.hi
	local old = b.folder:FindFirstChild("Threshold")
	if old then
		old:Destroy()
	end
	if gap > 0.05 then
		local p = Instance.new("Part")
		p.Name = "Threshold"
		p.Size = Vector3.new(320, 4, gap)
		p.CFrame = CFrame.new(0, b.top - 2, (a.hi + b.lo) / 2)
		p.Anchored = true
		p.Color = Color3.fromRGB(96, 98, 108)
		p.Material = Enum.Material.Slate
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = b.folder
		made += 1
	end
end
return string.format("%d thresholds laid between %d zones", made, #spans)
