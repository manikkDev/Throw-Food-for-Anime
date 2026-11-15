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
		-- The hub stations (food cart, daily chest, gift box, index board,
		-- summon shrine, sell booth) carry the actions food / daily / gift /
		-- index / summon / squad. They are NOT here on purpose: each one opens
		-- its screen on the client (MenuController), and the screen's buttons
		-- fire the usual remotes. Walking up to a cart must never spend Yen.
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
