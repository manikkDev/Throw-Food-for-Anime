--!strict
-- ShopService - everything bought with Yen: foods, dojo gear, plot slots.
--
-- Every price is read from Config on the server at the moment of purchase. The
-- client sends WHAT it wants, never what it costs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)

local ShopService = Knit.CreateService({
	Name = "ShopService",
})

function ShopService:KnitInit()
	self._buy = Net.server("ShopBuy")
	self._equip = Net.server("FoodEquip")
end

function ShopService:_short(player: Player, cost: number)
	local profile = self._data:Get(player)
	local missing = if profile then cost - profile.yen else cost
	self._state:Toast(player, `Need {Format.short(missing)} more yen`, "bad")
end

--- Buy a food by id and equip it.
function ShopService:BuyFood(player: Player, id: string)
	local profile = self._data:Get(player)
	local food = MAPS.food[id]
	if not profile or not food or profile.foods[id] then
		return
	end
	if not self._economy:Spend(player, food.Cost, "food") then
		self:_short(player, food.Cost)
		return
	end
	profile.foods[id] = true
	profile.food = id
	self._state:MarkDirty(player)
	self._state:Toast(player, `Bought {food.Name}!`, "good")
end

--- Buy the cheapest food not owned yet (the food cart prompt).
function ShopService:BuyNextFood(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	for _, food in Config.Foods do
		if not profile.foods[food.Id] then
			self:BuyFood(player, food.Id)
			return
		end
	end
	self._state:Toast(player, "You own every food", "info")
end

--- Equip a food the player already owns.
function ShopService:EquipFood(player: Player, id: string)
	local profile = self._data:Get(player)
	if not profile or not profile.foods[id] or profile.food == id then
		return
	end
	profile.food = id
	self._state:MarkDirty(player)
end

--- Buy the next dojo gear tier.
function ShopService:BuyGear(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local cost = Progress.nextGearCost(Config, profile.gear)
	if not cost then
		self._state:Toast(player, "Your dojo gear is maxed", "info")
		return
	end
	if not self._economy:Spend(player, cost, "gear") then
		self:_short(player, cost)
		return
	end
	profile.gear += 1
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
	local gear = Config.Training.Equipment[profile.gear]
	self._state:Toast(player, `New gear: {gear.Name}!`, "good")
end

--- Buy the next plot slot.
function ShopService:BuySlot(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local cost = Progress.nextSlotCost(Config, profile.slots - profile.bonusSlots)
	if not cost then
		self._state:Toast(player, "Your plot is at its maximum", "info")
		return
	end
	if not self._economy:Spend(player, cost, "slot") then
		self:_short(player, cost)
		return
	end
	profile.slots += 1
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
	self._state:Toast(player, `Plot slot {profile.slots} unlocked!`, "good")
end

function ShopService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._economy = Knit.GetService("EconomyService")
	self._plots = Knit.GetService("PlotService")

	self._buy.OnServerEvent:Connect(function(player: Player, kind: unknown, id: unknown)
		if not Guard.allow(player, "ShopBuy", 4, 8) then
			return
		end
		if kind == "food" then
			if Guard.text(id, 40) then
				self:BuyFood(player, id :: string)
			end
		elseif kind == "gear" then
			self:BuyGear(player)
		elseif kind == "slot" then
			self:BuySlot(player)
		end
	end)

	self._equip.OnServerEvent:Connect(function(player: Player, id: unknown)
		if Guard.allow(player, "FoodEquip", 4, 8) and Guard.text(id, 40) then
			self:EquipFood(player, id :: string)
		end
	end)
end

return ShopService
