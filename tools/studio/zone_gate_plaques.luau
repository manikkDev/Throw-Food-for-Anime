-- zone_gate_plaques.luau (rerunnable, Studio edit mode): the plaque on every zone gate, from the config.
--
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file tools/studio/zone_gate_plaques.luau
--
-- Since economy v2 (plan 12) all 17 zones are in play, so the "COMING SOON" of zones 7-17 goes: every gate
-- names its zone and the Power a throw needs to reach it. Each gate model also gets the attributes ZoneIndex
-- and RebirthReq. The SEAL of a zone the player has not opened yet is NOT here: the lane is one for
-- everybody and far gates are outside the streaming radius, so the client builds its own seal
-- (Controllers/SealController from ReplicatedStorage.Assets.World.ZoneSeal, tools/studio/zone_seal.luau).
--
-- Run it again after `tools/economy/econ_v2.py apply` moves a gate's Power, and after zone_gates.luau.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig:Clone())
local Format = require(game:GetService("ReplicatedStorage").Shared.Core.Format:Clone())

local lanes = workspace.Map.Lanes
local done, missing = 0, {}
for index, zone in Config.Zones do
	local holder = lanes:FindFirstChild("Zone_" .. zone.Id)
	local gate: Instance? = nil
	if holder then
		for _, child in holder:GetDescendants() do
			if child:IsA("Model") and child.Name:sub(1, 5) == "Gate_" then
				gate = child
				break
			end
		end
	end
	if not gate then
		table.insert(missing, zone.Id)
		continue
	end
	gate:SetAttribute("ZoneIndex", index)
	gate:SetAttribute("RebirthReq", zone.RebirthReq or 0)
	local second = if index == 1 then "START HERE" else `NEEDS {Format.short(zone.PowerReq)} POWER`
	local text = `{zone.Name:upper()}\n{second}`
	local plaques = 0
	for _, label in gate:GetDescendants() do
		if label:IsA("TextLabel") and label.Name == "Title" then
			label.Text = text
			plaques += 1
		end
	end
	if plaques == 0 then
		table.insert(missing, zone.Id .. " (no plaque label)")
	end
	done += 1
end
return `plaques written on {done} gates`
	.. (if #missing > 0 then `; MISSING: {table.concat(missing, ", ")}` else "")
