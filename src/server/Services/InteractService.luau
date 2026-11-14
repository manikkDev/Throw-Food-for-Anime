--!strict
-- InteractService - every ProximityPrompt in the world, in one place.
--
-- Map anchors carry a prompt with an "Action" attribute (and "Plot" for plot
-- anchors). The server listens to the prompt itself, so there is no remote
-- for a client to forge: the engine says who triggered what, and this service
-- checks it was THEIR plot before doing anything.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Guard = require(script.Parent.Parent.Logic.Guard)

local InteractService = Knit.CreateService({
	Name = "InteractService",
})

function InteractService:KnitStart()
	local state = Knit.GetService("StateService")
	local plots = Knit.GetService("PlotService")
	local shop = Knit.GetService("ShopService")
	local squad = Knit.GetService("SquadService")
	local training = Knit.GetService("TrainingService")
	local rewards = Knit.GetService("RewardsService")
	local progress = Knit.GetService("ProgressService")

	local actions: { [string]: (Player) -> () } = {
		train = function(player: Player)
			training:Toggle(player)
		end,
		gear = function(player: Player)
			shop:BuyGear(player)
		end,
		slot = function(player: Player)
			shop:BuySlot(player)
		end,
		equipBest = function(player: Player)
			squad:EquipBest(player)
		end,
		food = function(player: Player)
			shop:BuyNextFood(player)
		end,
		daily = function(player: Player)
			rewards:ClaimDaily(player)
		end,
		gift = function(player: Player)
			rewards:ClaimNextGift(player)
		end,
		index = function(player: Player)
			progress:ClaimAllZones(player)
		end,
		rebirth = function(player: Player)
			progress:Rebirth(player)
		end,
	}

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local action = prompt:GetAttribute("Action")
		if typeof(action) ~= "string" or not actions[action] then
			return
		end
		if not Guard.allow(player, "Prompt", 4, 8) then
			return
		end
		local plot = prompt:GetAttribute("Plot")
		if plot ~= nil and plot ~= plots:IndexOf(player) then
			state:Toast(player, "That is not your plot", "info")
			return
		end
		actions[action](player)
	end)
end

return InteractService
