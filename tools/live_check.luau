--!nocheck
-- Section 6 live-server check (run by tools/live_check.py through Open Cloud Luau Execution, in a
-- real Roblox server of the published place): does every animation and every sound the game uses
-- load THERE, with the server's real asset permissions, and did the game itself boot?
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local SoundService = game:GetService("SoundService")

local out = { animations = {}, sounds = {}, boot = {} }

-- the game's own server boot (Knit services) runs in this server too: its build stamp is in the
-- task's logs (tools/live_check.py reads them)
task.wait(8)
out.boot.plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots") ~= nil
out.boot.heroTemplates = #ReplicatedStorage.Assets.Characters:GetChildren()

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local SoundBank = require(ReplicatedStorage.Shared.Config.SoundBank)

-- animations: the asset must be readable by this experience's server
local pending = 0
for name, clip in Animations.Clips do
	if clip.id ~= "" then
		pending += 1
		task.spawn(function()
			local ok, seq = pcall(function()
				return KeyframeSequenceProvider:GetKeyframeSequenceAsync(clip.id)
			end)
			local frames = 0
			if ok and seq then
				frames = #seq:GetKeyframes()
			end
			out.animations[name] = if ok and frames > 0 then "ok " .. frames .. " keyframes" else "FAIL " .. tostring(seq)
			pending -= 1
		end)
	else
		out.animations[name] = "FAIL no id"
	end
end

-- sounds: loaded here with a real length
for role, entry in SoundBank do
	pending += 1
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. tostring(entry.id)
		sound.Parent = SoundService
		local start = os.clock()
		while not sound.IsLoaded and os.clock() - start < 20 do
			task.wait(0.2)
		end
		out.sounds[role] = if sound.IsLoaded and sound.TimeLength > 0
			then string.format("ok %.2fs", sound.TimeLength)
			else "FAIL not loaded"
		sound:Destroy()
		pending -= 1
	end)
end

local waited = os.clock()
while pending > 0 and os.clock() - waited < 90 do
	task.wait(0.5)
end
out.boot.unfinished = pending
return game:GetService("HttpService"):JSONEncode(out)
