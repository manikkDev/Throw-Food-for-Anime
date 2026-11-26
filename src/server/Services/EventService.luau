--!strict
-- EventService - the things everyone in the server shares: server luck,
-- Festival Hour and the rare-catch banner.
--
-- Server luck is bought by one player and helps all six, which is the social
-- reason to stay in a server. Festival Hour runs on the wall clock, so every
-- server starts it at the same moment and a creator can announce it.

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local STEPS = Config.Luck.ServerSteps
local E = Config.Events
-- a catch this unlikely gets a banner even if its rarity alone would not
local ANNOUNCE_ONE_IN = Config.Roll.AnnounceOneIn
-- a catch this unlikely (or any Secret) is told to EVERY server
local GLOBAL_ONE_IN = Config.Roll.GlobalAnnounceOneIn
local GLOBAL_TOPIC = "TFA_Catch_v1"

local EventService = Knit.CreateService({
	Name = "EventService",
	_step = 1,
	_luckUntil = 0,
	_festivalForcedUntil = 0,
	_lastEnv = "",
})

function EventService:KnitInit()
	self._env = Net.server("EnvUpdate")
	self._announce = Net.server("Announce")
	self._clientReady = Net.server("ClientReady")
end

--- Current server luck multiplier (1, 2, 4, 8).
function EventService:ServerLuck(): number
	return STEPS[self._step]
end

--- Raise server luck one step and extend it. Returns the new multiplier.
function EventService:AddLuckStep(byName: string): number
	local now = os.time()
	self._step = math.min(self._step + 1, #STEPS)
	self._luckUntil = math.max(self._luckUntil, now) + Config.Luck.ServerStepMinutes * 60
	self:_broadcast()
	self:Announce("luck", {
		text = `{byName} boosted SERVER LUCK to {Format.mult(self:ServerLuck())} for everyone!`,
	})
	return self:ServerLuck()
end

function EventService:FestivalActive(): boolean
	local now = os.time()
	if now < self._festivalForcedUntil then
		return true
	end
	return now % (E.FestivalHourEveryMinutes * 60) < E.FestivalHourMinutes * 60
end

--- Force a Festival Hour for `minutes` (owner command).
function EventService:ForceFestival(minutes: number)
	self._festivalForcedUntil = os.time() + minutes * 60
	self:_broadcast()
	self:Announce("festival", { text = "FESTIVAL HOUR! Mutations are twice as likely!" })
end

--- What multiplies mutation chances right now.
function EventService:MutationMult(): number
	return if self:FestivalActive() then E.FestivalMutationMult else 1
end

function EventService:_state(): any
	local now = os.time()
	local period = E.FestivalHourEveryMinutes * 60
	local intoPeriod = now % period
	local active = self:FestivalActive()
	local ends = if now < self._festivalForcedUntil
		then self._festivalForcedUntil
		else now - intoPeriod + E.FestivalHourMinutes * 60
	return {
		luck = self:ServerLuck(),
		luckUntil = self._luckUntil,
		festival = active,
		festivalEnds = if active then ends else 0,
		festivalNext = now - intoPeriod + period,
		unixNow = now,
	}
end

function EventService:_broadcast()
	self._env:FireAllClients(self:_state())
end

--- A banner for everyone. kind: "catch" | "luck" | "festival" | "rebirth" | "say".
function EventService:Announce(kind: string, payload: any)
	payload.kind = kind
	self._announce:FireAllClients(payload)
end

--- Banner a catch if it is rare enough. `delay` waits for the thrower's own
--- reveal, so the banner never spoils it.
function EventService:CatchAnnounce(player: Player, roll: any, delay: number)
	local rarity = Config.Rarities[roll.rarity]
	if not rarity.Announce and roll.oneInN < ANNOUNCE_ONE_IN then
		return
	end
	local character = MAPS.character[roll.id]
	local name = player.DisplayName
	task.delay(math.max(0, delay), function()
		local tags = {}
		if roll.size then
			table.insert(tags, roll.size:upper())
		end
		if roll.mutation then
			table.insert(tags, roll.mutation:upper())
		end
		table.insert(tags, character.Name)
		local text = `{name} caught {table.concat(tags, " ")}  ({Format.oneIn(roll.oneInN)})`
		self:Announce("catch", { text = text, rarity = roll.rarity })
		if roll.rarity == "Secret" or roll.oneInN >= GLOBAL_ONE_IN then
			-- best effort: a failed publish only loses a banner
			task.spawn(function()
				pcall(function()
					MessagingService:PublishAsync(
						GLOBAL_TOPIC,
						{ text = text, rarity = roll.rarity, job = game.JobId }
					)
				end)
			end)
		end
	end)
end

function EventService:KnitStart()
	self._clientReady.OnServerEvent:Connect(function(player: Player)
		if Guard.allow(player, "EnvSnapshot", 0.2, 2) then
			self._env:FireClient(player, self:_state())
		end
	end)

	-- catches told to every server (a Secret, or a score past GlobalAnnounceOneIn)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(message: any)
				local data = message.Data
				if
					typeof(data) ~= "table"
					or typeof(data.text) ~= "string"
					or #data.text > 200
					or data.job == game.JobId
				then
					return
				end
				self:Announce("catch", {
					text = data.text,
					rarity = if typeof(data.rarity) == "string" then data.rarity else nil,
					global = true,
				})
			end)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if self._step > 1 and os.time() >= self._luckUntil then
				self._step = 1
				self._luckUntil = 0
			end
			-- broadcast only when something a client shows has changed
			local key = `{self._step}|{self._luckUntil}|{self:FestivalActive()}`
			if key ~= self._lastEnv then
				self._lastEnv = key
				self:_broadcast()
			end
		end
	end)
end

return EventService
