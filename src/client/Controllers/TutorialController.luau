--!strict
-- TutorialController - the objective line for the first five minutes.
-- (Every line fits the slim hint pill: about 48 characters or fewer.)
--
-- No modal, no forced camera: one line at the top says what to do next, and it
-- advances the moment the player does it. A returning player resumes where
-- they left off (the step is saved), and every step reached is logged to the
-- onboarding funnel by the server so the worst drop-off can be found and fixed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)

type Step = { text: string, done: (any) -> boolean }

local TutorialController = Knit.CreateController({
	Name = "TutorialController",
	_sent = 0,
})

function TutorialController:KnitStart()
	local state = Knit.GetController("StateController")
	local hud = Knit.GetController("HudController")
	local throw = Knit.GetController("ThrowController")
	local setting = Net.client("SettingSet")
	local zone2 = Config.Zones[2]
	local food2 = Config.Foods[2]

	local steps: { Step } = {
		{
			text = "Step onto the glowing THROW PAD",
			done = function(): boolean
				return throw:OnPad()
			end,
		},
		{
			text = "TAP when the marker is near the top!",
			done = function(s: any): boolean
				return s.stats.caught >= 1
			end,
		},
		{
			text = "Throw again! Catch 3 heroes",
			done = function(s: any): boolean
				return s.stats.caught >= 3
			end,
		},
		{
			text = `Buy {food2.Name} in the SHOP`,
			done = function(s: any): boolean
				return s.foods[food2.Id] == true
			end,
		},
		{
			text = "Train on the DOJO PAD to throw further",
			done = function(s: any): boolean
				return s.power >= Config.Training.StartPower + 10
			end,
		},
		{
			text = `Reach {zone2.Name}: train to {Format.short(zone2.PowerReq)} power`,
			done = function(): boolean
				return (throw:LastZone() or 1) >= 2
			end,
		},
	}

	task.spawn(function()
		while true do
			task.wait(0.3)
			local s = state.State
			if s then
				-- steps already passed in an earlier session stay passed
				local current = math.max(s.tutorial, self._sent)
				while current < #steps and steps[current + 1].done(s) do
					current += 1
				end
				if current > self._sent and current > s.tutorial then
					self._sent = current
					if setting then
						setting:FireServer("tutorial", current)
					end
				end
				hud:SetObjective(if current < #steps then steps[current + 1].text else "")
			end
		end
	end)
end

return TutorialController
