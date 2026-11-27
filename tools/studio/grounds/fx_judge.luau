-- fx_judge.luau: look at a training effect IN THE GAME, frozen at a moment. (Plan 13 phase D.)
-- Run on the CLIENT datamodel of a Studio play session:
--
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Client --file tools/studio/grounds/fx_judge.luau
--   then, in further Client calls:
--     _G.GroundJudge.play("Post_Burst", "Strike", 0.12)        plays it at the Fx spot `Strike` of the ground the
--                                                              local player trains on (or stands nearest), and
--                                                              FREEZES every particle 0.12 s later
--     _G.GroundJudge.play("Train_Aura", "root", 1.0, "FFB13B") on the character's root, tinted
--     _G.GroundJudge.clear()                                   lets time run again and takes the effects away
--
-- It uses a second copy of the game's VfxKit (nothing in the running game is touched), so what it
-- shows is what the game shows. Judge at QualityLevel 21 (settings().Rendering.QualityLevel).
local Players = game:GetService("Players")

local client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local VfxKit = require(client.Fx.VfxKit)

local J = _G.GroundJudge
if J and J.clear then
	J.clear()
end
J = {}
_G.GroundJudge = J
local live: { any } = {}

local function setTimeScale(scale: number)
	for _, folder in workspace:GetChildren() do
		if folder.Name == "VfxKitLive" then
			for _, d in folder:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.TimeScale = scale
				end
			end
		end
	end
end

-- the set piece nearest the local player
local function piece(): Instance?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best, bestGap = nil, math.huge
	for _, plot in workspace.Map.Plots:GetChildren() do
		for court = 1, 2 do
			local anchor = plot:FindFirstChild("Ground" .. court)
			local model = anchor and anchor:FindFirstChild("GroundModel")
			if model and root then
				local gap = (anchor.Position - root.Position).Magnitude
				if gap < bestGap then
					best, bestGap = model, gap
				end
			end
		end
	end
	return best
end

function J.clear()
	for _, h in live do
		pcall(function()
			h.stop()
		end)
		pcall(function()
			h.destroy()
		end)
	end
	table.clear(live)
	setTimeScale(1)
end

function J.play(name: string, where: string, freezeAt: number?, tintHex: string?)
	local at: any
	if where == "root" then
		at = Players.LocalPlayer.Character.HumanoidRootPart
	else
		local model = piece()
		local fx = model and model:FindFirstChild("Fx")
		at = fx and fx:FindFirstChild(where)
		-- a one-shot is played at a point, a loop on the part
		if at and not string.find(name, "Flurry") and not string.find(name, "Ascend") then
			at = at.Position
		end
	end
	if not at then
		return "no such spot: " .. where
	end
	local handle = VfxKit.play(name, at, { tint = if tintHex then Color3.fromHex(tintHex) else nil, duration = 30 })
	table.insert(live, handle)
	if freezeAt then
		task.delay(freezeAt, setTimeScale, 0)
	end
	return "playing " .. name
end

return "GroundJudge ready"
