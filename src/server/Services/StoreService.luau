--!strict
-- StoreService - everything bought with Robux.
--
-- The rules that protect players' money:
--   * a grant happens ONLY inside ProcessReceipt (or the pass-ownership check),
--     never because a client said it bought something. The "pass purchase
--     finished" signal is raised by the client, so it is a hint: nothing is
--     written to the save until Roblox confirms the player owns the pass
--   * every grant is idempotent: the PurchaseId is recorded in the profile and
--     a receipt seen before is acknowledged without granting again
--   * Roblox is told "granted" only after EVERY profile holding the grant has
--     been SAVED (the buyer's, and the receiver's for a gift); anything else
--     returns NotProcessedYet and Roblox retries
--   * summon scrolls are paid random items: PolicyService decides who may see
--     them, and the odds on screen are the same table the roll uses

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)

local SUMMON_ODDS = {}
for _, hero in Config.PremiumCharacters do
	if hero.Source == "Summon" then
		table.insert(SUMMON_ODDS, hero)
	end
end

local StoreService = Knit.CreateService({
	Name = "StoreService",
	_owned = {} :: { [Player]: { [string]: boolean } },
	_restricted = {} :: { [Player]: boolean },
	_giftTarget = {} :: { [Player]: { userId: number, key: string } },
	-- receipts granted in memory whose save has not been confirmed yet
	_unsaved = {} :: { [Player]: { [string]: { also: Player? } } },
	_random = Random.new(),
})

function StoreService:KnitInit()
	self._giftRemote = Net.server("StoreGiftTarget")
end

--- Does the player have pass `key`, bought or gifted?
function StoreService:Has(player: Player, key: string): boolean
	local owned = self._owned[player]
	if owned and owned[key] then
		return true
	end
	local profile = self._data:Get(player)
	return profile ~= nil and profile.grantedPasses[key] == true
end

--- Every pass key the player has, as a set.
function StoreService:Passes(player: Player): { [string]: boolean }
	local set = {}
	for _, pass in Config.Monetization.Passes do
		if self:Has(player, pass.Key) then
			set[pass.Key] = true
		end
	end
	return set
end

--- True when this player must not be shown or sold paid random items. Unknown
--- counts as restricted: that is what Roblox asks for when the check fails.
function StoreService:RandomItemsRestricted(player: Player): boolean
	return self._restricted[player] ~= false
end

-- Ask Roblox whether the player owns a pass. true / false, or nil when the
-- check itself failed (which must never be remembered as "not owned").
local function ownsPass(player: Player, passId: number): boolean?
	local ok, has = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then
		return nil
	end
	return has == true
end

--- Things a pass gives once, when it is first seen on the profile. Call this
--- only for a pass Roblox has CONFIRMED (or a gift bought through a receipt).
function StoreService:ApplyPass(player: Player, key: string)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	if key == "Vip" and profile.bonusSlots == 0 then
		profile.bonusSlots = Config.Plot.VipBonusSlots
		profile.slots += Config.Plot.VipBonusSlots
	end
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
end

--- Apply a product's effect. Errors are the caller's signal NOT to tell Roblox
--- the purchase was handled. Returns a second player whose profile also
--- changed (the receiver of a gift) and must be saved too.
function StoreService:GrantProduct(player: Player, product: any): Player?
	local profile = self._data:Get(player)
	assert(profile, "no profile")
	local also: Player? = nil
	local kind = product.Kind
	if kind == "lucky" then
		profile.luckyThrows += product.Amount
	elseif kind == "serverluck" then
		self._events:AddLuckStep(player.DisplayName)
	elseif kind == "yen" then
		local amount = self._economy:MinutesOfIncome(player, product.Minutes)
		self._economy:Add(player, amount, "yenpack")
	elseif kind == "train" then
		self._training:GrantMinutes(player, product.Minutes)
	elseif kind == "offline2x" then
		local claimed = self._economy:ClaimOffline(player, 2)
		if claimed == 0 then
			-- bought with nothing pending: still worth something
			claimed = self._economy:MinutesOfIncome(player, 30)
			self._economy:Add(player, claimed, "yenpack")
		end
		self._state:Toast(player, `Doubled! +{Format.short(claimed)} yen`, "good")
	elseif kind == "summon" then
		for _ = 1, product.Amount do
			local hero = Roll.byPercent(SUMMON_ODDS, self._random:NextNumber())
			self._squad:GrantAndShow(player, hero.Id, nil, nil, "summon")
		end
	elseif kind == "starter" then
		if not profile.starterPack then
			profile.starterPack = true
			self._squad:GrantAndShow(player, product.Hero, nil, nil, "starter")
		end
		profile.luckyThrows += Config.Rewards.StarterPackLuckyThrows
		local seconds = Config.Rewards.StarterPackDoubleYenMinutes * 60
		profile.doubleYenUntil = math.max(profile.doubleYenUntil, os.time()) + seconds
	elseif kind == "character" then
		self._squad:GrantAndShow(player, product.Hero, nil, nil, "store")
	elseif kind == "gift" then
		local target = self._giftTarget[player]
		assert(target and target.key == product.Key, "no gift target chosen")
		local receiver = Players:GetPlayerByUserId(target.userId)
		local theirs = receiver and self._data:Get(receiver)
		assert(receiver and theirs, "gift receiver left the server")
		local passKey = product.Pass
		theirs.grantedPasses[passKey] = true
		self._giftTarget[player] = nil
		self:ApplyPass(receiver, passKey)
		also = receiver
		self._state:Toast(receiver, `{player.DisplayName} gifted you a pass!`, "good")
		self._state:Toast(player, `Gift sent to {receiver.DisplayName}`, "good")
	else
		error(`unknown product kind {kind}`)
	end
	self._state:MarkDirty(player)
	self._plots:Refresh(player)
	self._telemetry:Custom(player, "Purchase", product.Robux, product.Key)
	return also
end

-- Save what a receipt changed. True once it is on disk (or there is nothing
-- left to save for it).
function StoreService:_settle(player: Player, receiptId: string): boolean
	local pending = self._unsaved[player]
	local entry = pending and pending[receiptId]
	if not pending or not entry then
		return true
	end
	if not self._data:SaveNow(player) then
		return false
	end
	local also = entry.also
	if also and self._data:Get(also) and not self._data:SaveNow(also) then
		return false
	end
	pending[receiptId] = nil
	return true
end

function StoreService:_processReceipt(info: any): Enum.ProductPurchaseDecision
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and self._data:Get(player)
	if not player or not profile then
		return NOT_YET
	end
	local receiptId = tostring(info.PurchaseId)
	local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
	if Collection.receiptSeen(profile.receipts, receiptId) then
		-- seen before: never grant twice, but if its save failed last time it
		-- is still only in memory, so it must be saved before saying "granted"
		return if self:_settle(player, receiptId) then GRANTED else NOT_YET
	end
	local product = MAPS.productById[info.ProductId]
	if not product then
		warn(`[StoreService] receipt for unknown product {info.ProductId}`)
		return NOT_YET
	end
	local ok, result = pcall(function()
		return self:GrantProduct(player, product)
	end)
	if not ok then
		warn(`[StoreService] grant of {product.Key} failed for {player.Name}: {result}`)
		return NOT_YET
	end
	Collection.recordReceipt(profile.receipts, receiptId, Config.Server.ReceiptHistory)
	local pending = self._unsaved[player] or {}
	self._unsaved[player] = pending
	pending[receiptId] = { also = result }
	-- the grant is in memory and marked, so a retry in this session will not
	-- double it; if the server dies before the save, Roblox retries and it is
	-- granted then
	return if self:_settle(player, receiptId) then GRANTED else NOT_YET
end

-- A pass Roblox confirmed: remember it and give what it gives once.
function StoreService:_confirmPass(player: Player, pass: any)
	local owned = self._owned[player]
	if not owned then
		return
	end
	owned[pass.Key] = true
	self:ApplyPass(player, pass.Key)
end

-- Keep asking about passes whose ownership check failed at join. Without this
-- one hiccup would leave a paying player without their pass until they rejoin.
function StoreService:_recheck(player: Player, failed: { any })
	for attempt = 1, 4 do
		task.wait(5 * attempt)
		if not self._owned[player] then
			return -- left
		end
		for i = #failed, 1, -1 do
			local has = ownsPass(player, failed[i].ProductId)
			if has ~= nil then
				if has then
					self:_confirmPass(player, failed[i])
				end
				table.remove(failed, i)
			end
		end
		if #failed == 0 then
			return
		end
	end
end

-- The purchase prompt closed saying "bought". The client raises that signal,
-- so confirm with Roblox before anything is saved. Roblox may keep answering
-- "not owned" for the rest of this server's life after a real purchase (it
-- remembers the answer it gave at join), so an unconfirmed purchase still
-- turns the pass on for THIS session only; nothing is written to the save,
-- and the next join's check is what makes it permanent.
function StoreService:_passBought(player: Player, pass: any)
	for attempt = 1, 3 do
		if ownsPass(player, pass.ProductId) == true then
			self:_confirmPass(player, pass)
			self._telemetry:Custom(player, "Purchase", pass.Robux, pass.Key)
			return
		end
		task.wait(attempt * 2)
	end
	local owned = self._owned[player]
	if not owned then
		return
	end
	owned[pass.Key] = true
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
	if pass.Key == "Vip" then
		self._state:Toast(player, "VIP is on! Your bonus slots unlock when you rejoin.", "good")
	end
	self._telemetry:Custom(player, "PurchaseUnconfirmed", pass.Robux, pass.Key)
end

function StoreService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._plots = Knit.GetService("PlotService")
	self._economy = Knit.GetService("EconomyService")
	self._squad = Knit.GetService("SquadService")
	self._training = Knit.GetService("TrainingService")
	self._events = Knit.GetService("EventService")
	self._telemetry = Knit.GetService("TelemetryService")

	-- This handler YIELDS on purpose: later lifecycle handlers (offline pay,
	-- the first snapshot) must see pass ownership.
	self._data:OnLoaded(function(player: Player, profile: any)
		local owned = {}
		local failed = {}
		self._owned[player] = owned
		for _, pass in Config.Monetization.Passes do
			if pass.ProductId ~= 0 then
				local has = ownsPass(player, pass.ProductId)
				owned[pass.Key] = has == true
				if has == nil then
					table.insert(failed, pass)
				end
			end
		end
		if #failed > 0 then
			task.spawn(function()
				self:_recheck(player, failed)
			end)
		end
		local ok, policy = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		self._restricted[player] = not ok or policy.ArePaidRandomItemsRestricted == true
		if self:Has(player, "Vip") and profile.bonusSlots == 0 then
			profile.bonusSlots = Config.Plot.VipBonusSlots
			profile.slots += Config.Plot.VipBonusSlots
		end
	end)
	self._data:OnReleasing(function(player: Player)
		self._owned[player] = nil
		self._restricted[player] = nil
		self._giftTarget[player] = nil
		self._unsaved[player] = nil
	end)
	-- a gift target can be chosen before the profile loads; a player who never
	-- gets one is never "released"
	Players.PlayerRemoving:Connect(function(player: Player)
		self._giftTarget[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local pass = MAPS.passById[passId]
			if purchased and pass and self._owned[player] and not self:Has(player, pass.Key) then
				task.spawn(function()
					self:_passBought(player, pass)
				end)
			end
		end
	)

	MarketplaceService.ProcessReceipt = function(info: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(function()
			return self:_processReceipt(info)
		end)
		if not ok then
			warn(`[StoreService] ProcessReceipt errored: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end

	self._giftRemote.OnServerEvent:Connect(function(player: Player, userId: unknown, key: unknown)
		if not Guard.allow(player, "StoreGiftTarget", 2, 4) then
			return
		end
		if not Guard.integer(userId, 1, 2 ^ 53) or not Guard.text(key, 40) then
			return
		end
		local product = MAPS.product[key :: string]
		local receiver = Players:GetPlayerByUserId(userId :: number)
		if not product or product.Kind ~= "gift" or not receiver or receiver == player then
			return
		end
		if self:Has(receiver, product.Pass) then
			self._state:Toast(player, `{receiver.DisplayName} already has that pass`, "info")
			return
		end
		self._giftTarget[player] = { userId = userId :: number, key = key :: string }
	end)
end

return StoreService
