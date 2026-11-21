-- square_templates.luau - Studio EDIT mode. Run after storing generated meshes for a zone.
-- Studio's mesh generator inserts its model TURNED TO FACE THE CAMERA, so a stored template carries
-- whatever yaw the camera had (zone 2's were all 15 degrees off: the mansion sat skewed and every
-- carriage pointed off the rails; zone 1's gate keeps were 3.6 off). This squares every single-mesh
-- template in ServerStorage.StoreAssets.Zone* to the world axes and puts its pivot at the middle of
-- its base. After it, a generated mesh fronts to -Z, like the harvested buildings.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local store = game:GetService("ServerStorage").StoreAssets
local out = {}
for _, folder in store:GetChildren() do
	if folder.Name:sub(1, 4) == "Zone" then
		for _, template in folder:GetChildren() do
			local mesh = template:FindFirstChildWhichIsA("MeshPart")
			if template:IsA("Model") and mesh and #template:GetChildren() == 1 then
				local _, yaw = mesh.CFrame:ToOrientation()
				mesh.CFrame = CFrame.new(mesh.Position)
				template.WorldPivot = CFrame.new(mesh.Position.X, mesh.Position.Y - mesh.Size.Y / 2, mesh.Position.Z)
				template:PivotTo(CFrame.new(0, 0, 0))
				template:SetAttribute("TrueSize", mesh.Size)
				if math.abs(math.deg(yaw)) > 0.05 then
					table.insert(out, string.format("%s/%s was turned %.1f", folder.Name, template.Name, math.deg(yaw)))
				end
			end
		end
	end
end
return if #out > 0 then "squared: " .. table.concat(out, ", ") else "every template was already square"
