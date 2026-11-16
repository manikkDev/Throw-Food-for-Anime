--!strict
-- SquadService - every hero a player owns: granting, placing, benching,
-- selling, equip best and fusing. The decisions are Core/Squad; this service
-- applies them to the profile and tells PlotService and StateService.
--
-- :Grant is the ONLY way a hero enters a profile (throws, store, gifts all
-- come through it), so the index, the auto-place rule and the bench limit are
-- enforced in one place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Schema = require(ReplicatedStorage.Shared.Core.Schema)
local Squad = require(ReplicatedStorage.Shared.Core.Squad)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)

export type Grant = {
	uid: string?,
	id: string,
	mut: string?,
	size: string?,
	action: string,
	slot: number,
	isNew: boolean,
	isBest: boolean,
	income: number,
	soldYen: number,
}

local SquadService = Knit.CreateService({
	Name = "SquadService",
})

function SquadService:KnitInit()
	self._action = Net.server("SquadAction")
	self._granted = Net.server("HeroGranted")
end

--- Bench capacity for this player.
function SquadService:BenchSlots(player: Player): number
	if self._store:Has(player, "BigBench") then
		return MAPS.pass.BigBench.BenchSlots
	end
	return Config.Plot.BenchSlots
end

-- income used for VALUES
local function valuer(profile: any, extraBest: number): (any) -> number
	local best = math.max(Income.best(Config, MAPS, profile.heroes), extraBest)
	return function(hero: any): number
		return Income.hero(Config, MAPS, hero, best)
	end
end

-- income used for "who is weakest": a premium hero is never the one displaced
-- or auto-sold, because the player paid for it
local function protect(incomeOf: (any) -> number): (any) -> number
	return function(hero: any): number
		if MAPS.premium[hero.id] then
			return math.huge
		end
		return incomeOf(hero)
	end
end

function SquadService:_changed(player: Player)
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
end

--- Give `player` a hero. `arriveIn` delays its appearance on the plot (the
--- time the throw takes to land and reveal). Returns what happened, or nil if
--- the player has no profile.
function SquadService:Grant(
	player: Player,
	id: string,
	mut: string?,
	size: string?,
	arriveIn: number?
): Grant?
	local profile = self._data:Get(player)
	if not profile then
		return nil
	end
	local candidate = { id = id, mut = mut, size = size, stars = 0, slot = 0 }
	local bestBefore = Income.best(Config, MAPS, profile.heroes)
	local laneIncome = Income.lane(Config, MAPS, candidate)
	local incomeOf = valuer(profile, laneIncome)
	local income = incomeOf(candidate)
	local isNew = Collection.discover(profile.index, id, mut, size)
	local isBest = laneIncome > bestBefore and bestBefore > 0

	local character = MAPS.character[id]
	local settings = profile.settings
	local plain = character ~= nil and not isNew and mut == nil and size == nil
	local autoSell = plain
		and (
			(character.Rarity == "Common" and settings.autoSellCommon)
			or (character.Rarity == "Uncommon" and settings.autoSellUncommon)
		)

	local placement: Squad.Placement
	if autoSell and Squad.freeSlot(profile.heroes, profile.slots) == nil then
		placement = { action = "sold", slot = 0, sold = "new" }
	else
		placement = Squad.placement(
			profile.heroes,
			profile.slots,
			self:BenchSlots(player),
			if MAPS.premium[id] then math.huge else income,
			protect(incomeOf)
		)
	end

	local soldYen = 0
	local uid: string? = nil
	if placement.action == "sold" then
		soldYen += Income.sellValue(Config, income)
	else
		if placement.sold and placement.sold ~= "new" then
			local gone = profile.heroes[placement.sold]
			if gone then
				soldYen += Income.sellValue(Config, incomeOf(gone))
				profile.heroes[placement.sold] = nil
			end
		end
		if placement.benched and profile.heroes[placement.benched] then
			profile.heroes[placement.benched].slot = 0
		end
		local newUid, hero = Schema.newHero(profile, id, mut, size)
		hero.slot = placement.slot
		uid = newUid
		if placement.slot > 0 and arriveIn and arriveIn > 0 then
			self._plots:SetArrival(player, newUid, arriveIn)
		end
	end
	if soldYen > 0 then
		self._economy:Add(player, soldYen, "sell")
	end
	self:_changed(player)
	return {
		uid = uid,
		id = id,
		mut = mut,
		size = size,
		action = placement.action,
		slot = placement.slot,
		isNew = isNew,
		isBest = isBest,
		income = income,
		soldYen = soldYen,
	}
end

--- Grant a hero that did not come from a throw (store, gift) and tell the
--- client so it can play a reveal for it.
function SquadService:GrantAndShow(
	player: Player,
	id: string,
	mut: string?,
	size: string?,
	reason: string
): Grant?
	local grant = self:Grant(player, id, mut, size, nil)
	if grant then
		local character = MAPS.character[id]
		self._granted:FireClient(player, {
			id = id,
			mut = mut,
			size = size,
			rarity = if character then character.Rarity else "Premium",
			isNew = grant.isNew,
			income = grant.income,
			action = grant.action,
			slot = grant.slot,
			uid = grant.uid,
			reason = reason,
		})
	end
	return grant
end

--- Seat the best earners. Also offered as a prompt on the plot's name board.
function SquadService:EquipBest(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local seats = Squad.equipBest(profile.heroes, profile.slots, valuer(profile, 0))
	local moved = false
	for uid, slot in seats do
		if profile.heroes[uid].slot ~= slot then
			profile.heroes[uid].slot = slot
			moved = true
		end
	end
	if moved then
		-- every seat change is sent to the whole server: only when one happened
		self:_changed(player)
	end
	self._state:Toast(player, "Best heroes are on your plot", "good")
end

function SquadService:_place(player: Player, profile: any, uid: string, slot: number)
	local hero = profile.heroes[uid]
	if not hero then
		return
	end
	if hero.slot == slot then
		self:_changed(player) -- a carried hero set down on its own pedestal still has to appear
		return
	end
	for otherUid, other in profile.heroes do
		if other.slot == slot and otherUid ~= uid then
			other.slot = hero.slot -- swap seats (or send the occupant to the bench)
		end
	end
	hero.slot = slot
	self:_changed(player)
end

function SquadService:_bench(player: Player, profile: any, uid: string)
	local hero = profile.heroes[uid]
	if not hero or hero.slot == 0 then
		return
	end
	local _, onBench = Squad.counts(profile.heroes)
	if onBench >= self:BenchSlots(player) then
		self._state:Toast(player, "Your bench is full", "bad")
		return
	end
	hero.slot = 0
	self:_changed(player)
end

function SquadService:_sell(player: Player, profile: any, uid: string)
	local hero = profile.heroes[uid]
	if not hero then
		return
	end
	local value = Income.sellValue(Config, valuer(profile, 0)(hero))
	profile.heroes[uid] = nil
	self._economy:Add(player, value, "sell")
	self:_changed(player)
	self._state:Toast(player, `Sold for {Format.short(value)} yen`, "good")
end

function SquadService:_fuse(player: Player, profile: any, uid: string)
	local plot = Config.Plot
	local partners = Squad.fusePartners(profile.heroes, uid, plot.FuseCount, plot.MaxStars)
	if not partners then
		self._state:Toast(player, `Fusing needs {plot.FuseCount} identical heroes`, "bad")
		return
	end
	for _, partner in partners do
		profile.heroes[partner] = nil
	end
	profile.heroes[uid].stars += 1
	self:_changed(player)
	self._state:Toast(player, `Fused! Now {profile.heroes[uid].stars} star`, "good")
end

function SquadService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._plots = Knit.GetService("PlotService")
	self._economy = Knit.GetService("EconomyService")
	self._store = Knit.GetService("StoreService")

	self._action.OnServerEvent:Connect(
		function(player: Player, action: unknown, uid: unknown, slot: unknown)
			-- each action re-sends this plot to every client, who rebuild its
			-- rigs: a menu tap needs a few a second, never a stream
			if not Guard.allow(player, "SquadAction", 3, 8) then
				return
			end
			local profile = self._data:Get(player)
			if not profile or typeof(action) ~= "string" then
				return
			end
			if action == "equipBest" then
				self:EquipBest(player)
				return
			end
			if not Guard.text(uid, 16) or profile.heroes[uid :: string] == nil then
				return
			end
			local id = uid :: string
			-- whatever is done with the carried hero, it is no longer in the hands
			if self._plots:Carrying(player) == id then
				self._plots:ClearCarry(player, true)
			end
			if action == "drop" then
				-- set down on the slot it already holds (or the bench)
				self:_changed(player)
				return
			end
			if action == "place" then
				if Guard.integer(slot, 1, profile.slots) then
					self:_place(player, profile, id, slot :: number)
				end
			elseif action == "bench" then
				self:_bench(player, profile, id)
			elseif action == "sell" then
				self:_sell(player, profile, id)
			elseif action == "fuse" then
				self:_fuse(player, profile, id)
			end
		end
	)
end

return SquadService
