--!strict
-- ShopService - everything bought with Yen: foods, dojo gear, plot slots.
--
-- Every price is read from Config on the server at the moment of purchase. The
-- client sends WHAT it wants, never what it costs.
--
-- Gear, foods and slots UNLOCK by the furthest zone the player has reached
-- (plan 12): Yen alone never buys ahead of the training.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)

local ShopService = Knit.CreateService({
	Name = "ShopService",
})

function ShopService:KnitInit()
	self._buy = Net.server("ShopBuy")
	self._equip = Net.server("FoodEquip")
end

--- Toast why a row is locked. Returns true when it IS locked.
function ShopService:_locked(player: Player, profile: any, row: any, what: string): boolean
	local lock = Progress.lock(row, profile.bestZone, profile.rebirth)
	if not lock then
		return false
	end
	if lock.rebirth then
		self._state:Toast(player, `{what} unlocks at Rebirth {lock.rebirth}`, "bad")
	else
		local zone = Config.Zones[lock.zone :: number]
		self._state:Toast(player, `{what} unlocks when you reach {zone.Name}`, "bad")
	end
	return true
end

-- a stronger food carries the throw further: it may reach (and unlock) a new zone
function ShopService:_touchReach(profile: any)
	local food = MAPS.food[profile.food]
	local full = profile.power * (if food then food.PowerMult else 1)
	Progress.touch(profile, Throw.reach(Config.Zones, full, profile.rebirth))
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
	if self:_locked(player, profile, food, food.Name) then
		return
	end
	if not self._economy:Spend(player, food.Cost, "food") then
		self:_short(player, food.Cost)
		return
	end
	profile.foods[id] = true
	profile.food = id
	self:_touchReach(profile)
	self._state:MarkDirty(player)
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
	self:_touchReach(profile)
	self._state:MarkDirty(player)
end

--- Buy the next dojo gear tier.
function ShopService:BuyGear(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local gear = Progress.nextGear(Config, profile.gear)
	local cost = Progress.nextGearCost(Config, profile.gear)
	if not gear or not cost then
		self._state:Toast(player, "Your dojo gear is maxed", "info")
		return
	end
	if self:_locked(player, profile, gear, gear.Name) then
		return
	end
	if not self._economy:Spend(player, cost, "gear") then
		self:_short(player, cost)
		return
	end
	profile.gear += 1
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
end

--- Buy the next plot slot.
function ShopService:BuySlot(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local cost = Progress.nextSlotCost(Config, profile.slots, profile.bonusSlots)
	local zone = Progress.nextSlotZone(Config, profile.slots, profile.bonusSlots)
	if not cost then
		self._state:Toast(player, "Your plot is at its maximum", "info")
		return
	end
	if self:_locked(player, profile, { Zone = zone }, "The next slot") then
		return
	end
	if not self._economy:Spend(player, cost, "slot") then
		self:_short(player, cost)
		return
	end
	profile.slots += 1
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
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
