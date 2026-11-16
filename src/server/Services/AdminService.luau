--!strict
-- AdminService - owner event controls, and Studio-only test grants.
--
-- Two tiers, both checked on the server:
--   OWNER (Config.Server.AdminUserIds): festival, luck, say, throws
--     - the live-event levers: start a Festival Hour, raise server luck,
--       broadcast a message, hand everyone Lucky Throws.
--   DEV (Studio sessions only): yen, power, hero, product, pass, wipe, away, nextrarity,
--     nextmut, nextsize, rebirthready, gear, slots, allfoods, rarityhero, fuseset, luckythrows,
--     resetdaily, clearcarry, announce (the TEST panel, Ui/DevPanel, drives all of them)
--     - shortcuts so every system can be tested without playing fifteen hours.
--       These refuse outright in a live server, owner or not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Schema = require(ReplicatedStorage.Shared.Core.Schema)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local STUDIO = RunService:IsStudio()

local AdminService = Knit.CreateService({
	Name = "AdminService",
})

function AdminService:KnitInit()
	self._command = Net.server("AdminCommand")
end

local function isOwner(player: Player): boolean
	return table.find(Config.Server.AdminUserIds, player.UserId) ~= nil
end

function AdminService:_owner(player: Player, command: string, arg: any): boolean
	if command == "festival" then
		self._events:ForceFestival(if Guard.integer(arg, 1, 120) then arg else 5)
	elseif command == "luck" then
		self._events:AddLuckStep(player.DisplayName)
	elseif command == "throws" then
		local amount = if Guard.integer(arg, 1, 100) then arg else 3
		for other, profile in self._data:All() do
			profile.luckyThrows += amount
			self._state:MarkDirty(other)
			self._state:Toast(other, `Everyone got {amount} Lucky Throws!`, "good")
		end
	elseif command == "say" then
		if not Guard.text(arg, 120) or #arg == 0 then
			return true
		end
		-- text shown to other players must go through the filter
		local ok, filtered = pcall(function()
			local result = TextService:FilterStringAsync(arg, player.UserId)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if ok then
			self._events:Announce("say", { text = filtered })
		end
	else
		return false
	end
	return true
end

function AdminService:_dev(player: Player, command: string, arg: any): boolean
	local profile = self._data:Get(player)
	if not profile then
		return true
	end
	if command == "nextrarity" and typeof(arg) == "string" and Config.Rarities[arg] then
		-- the next throw lands this rarity (tests the reveal's suspense per rarity)
		self._throw:ForceNext(player, { rarity = arg })
		self._state:Toast(player, `Next throw: {arg}`, "info")
	elseif
		command == "nextmut"
		and typeof(arg) == "string"
		and (arg == "none" or MAPS.mutation[arg])
	then
		self._throw:ForceNext(player, { mutation = arg })
		self._state:Toast(player, `Next throw mutation: {arg}`, "info")
	elseif
		command == "nextsize"
		and typeof(arg) == "string"
		and (arg == "none" or MAPS.size[arg])
	then
		self._throw:ForceNext(player, { size = arg })
		self._state:Toast(player, `Next throw size: {arg}`, "info")
	elseif command == "rebirthready" then
		-- enough power and yen for the next rebirth
		local tier = Config.Rebirth.Tiers[profile.rebirth + 1]
		if tier then
			profile.power = math.max(profile.power, tier.PowerReq)
			self._economy:Add(player, tier.YenCost, "dev")
		end
	elseif command == "gear" and Guard.integer(arg, 1, #Config.Training.Equipment) then
		profile.gear = arg
		self._plots:Refresh(player)
	elseif
		command == "slots" and Guard.integer(arg, Config.Plot.StartSlots, Config.Plot.MaxSlots)
	then
		profile.slots = arg
		self._plots:Refresh(player)
	elseif command == "allfoods" then
		for _, food in Config.Foods do
			profile.foods[food.Id] = true
		end
	elseif command == "rarityhero" and typeof(arg) == "string" and Config.Rarities[arg] then
		-- a random hero of that rarity (any zone)
		local pool = {}
		for _, row in Config.Characters do
			if row.Rarity == arg then
				table.insert(pool, row.Id)
			end
		end
		if #pool > 0 then
			self._squad:GrantAndShow(player, pool[math.random(1, #pool)], nil, nil, "dev")
		end
	elseif command == "fuseset" then
		-- three identical heroes, ready to fuse (the fuse animation test)
		local id = if typeof(arg) == "string" and MAPS.character[arg]
			then arg
			else Config.Characters[1].Id
		for _ = 1, Config.Plot.FuseCount do
			self._squad:GrantAndShow(player, id, nil, nil, "dev")
		end
	elseif command == "luckythrows" and Guard.integer(arg, 1, 999) then
		profile.luckyThrows += arg
	elseif command == "resetdaily" then
		-- the daily reward and today's playtime gifts are ready again
		profile.daily.day = 0
		profile.gifts = { day = 0, claimed = {} }
	elseif command == "clearcarry" then
		self._plots:ClearCarry(player)
	elseif command == "announce" and typeof(arg) == "string" and Config.Rarities[arg] then
		-- a server announcement as if this player just caught a hero of that rarity
		local pool = {}
		for _, row in Config.Characters do
			if row.Rarity == arg then
				table.insert(pool, row.Id)
			end
		end
		if #pool > 0 then
			self._events:CatchAnnounce(player, {
				id = pool[math.random(1, #pool)],
				rarity = arg,
				oneInN = 250000,
				mutation = "Flame",
			}, 0)
		end
	elseif command == "yen" and Guard.number(arg) then
		self._economy:Add(player, math.max(0, arg), "dev")
	elseif command == "power" and Guard.number(arg) then
		self._training:AddPower(player, math.max(0, arg))
	elseif command == "hero" and typeof(arg) == "table" then
		local id = arg.id
		if typeof(id) == "string" and (MAPS.character[id] or MAPS.premium[id]) then
			local mut = if MAPS.mutation[arg.mut] then arg.mut else nil
			local size = if MAPS.size[arg.size] then arg.size else nil
			self._squad:GrantAndShow(player, id, mut, size, "dev")
		end
	elseif command == "product" and typeof(arg) == "string" and MAPS.product[arg] then
		local ok, err = pcall(function()
			self._store:GrantProduct(player, MAPS.product[arg])
		end)
		if not ok then
			self._state:Toast(player, `grant failed: {err}`, "bad")
		end
	elseif command == "pass" and typeof(arg) == "string" and MAPS.pass[arg] then
		profile.grantedPasses[arg] = if profile.grantedPasses[arg] then nil else true
		if profile.grantedPasses[arg] then
			self._store:ApplyPass(player, arg)
			self._store:ShowPurchase(player, { kind = "pass", key = arg })
		end
		self._plots:Refresh(player)
	elseif command == "wipe" then
		local fresh = Schema.default(Config)
		for key in profile do
			profile[key] = nil
		end
		for key, value in fresh do
			profile[key] = value
		end
		self._plots:Refresh(player)
	elseif command == "away" and Guard.number(arg) then
		-- pretend the player was away for `arg` seconds (offline-pay test)
		self._economy:BankAway(player, math.max(0, arg))
	else
		return false
	end
	self._state:MarkDirty(player)
	return true
end

function AdminService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._events = Knit.GetService("EventService")
	self._economy = Knit.GetService("EconomyService")
	self._training = Knit.GetService("TrainingService")
	self._throw = Knit.GetService("ThrowService")
	self._squad = Knit.GetService("SquadService")
	self._store = Knit.GetService("StoreService")
	self._plots = Knit.GetService("PlotService")

	self._command.OnServerEvent:Connect(function(player: Player, command: unknown, arg: unknown)
		if not Guard.allow(player, "AdminCommand", 3, 6) then
			return
		end
		if typeof(command) ~= "string" or not player:IsDescendantOf(Players) then
			return
		end
		-- in Studio every tester gets the owner's event levers too (festival, luck, say, throws)
		if (isOwner(player) or STUDIO) and self:_owner(player, command, arg) then
			return
		end
		if STUDIO then
			self:_dev(player, command, arg)
		end
	end)
end

return AdminService
