--!strict
-- DataService - owns every player's saved profile.
--
-- One DataStore record per player: { data = <profile>, lock = { job, t }? }.
-- The lock (Core/Session) makes sure only ONE server writes a profile at a
-- time. Rules that keep data safe:
--   * a player whose profile cannot be loaded is kicked, never handed a blank
--     profile (a blank profile saved over a real one is permanent data loss)
--   * a save that finds the lock gone or foreign does NOT write, and the
--     player is kicked: another server owns the profile now
--   * saves happen on a timer, on leave and in BindToClose, and shutdown waits
--     for EVERY final save still in flight, not only the ones it started
--   * the lifecycle is strictly ordered per player: loaded, ready, releasing.
--     A leave that arrives while the join handlers are still running waits for
--     them, so no handler ever runs for a player who has already been released
--
-- Other services never touch the DataStore. They ask for the live profile
-- table with :Get(player) and register for the lifecycle with :OnLoaded,
-- :OnReady and :OnReleasing.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Schema = require(ReplicatedStorage.Shared.Core.Schema)
local Session = require(ReplicatedStorage.Shared.Core.Session)

local JOB = if game.JobId ~= ""
	then game.JobId
	else Session.studioJob(HttpService:GenerateGUID(false))
local LOAD_FAILURES = 6
local SAVE_ATTEMPTS = 3
local SHUTDOWN_SECONDS = 25 -- Roblox allows 30

type Handler = (Player, any) -> ()

local DataService = Knit.CreateService({
	Name = "DataService",
	_profiles = {} :: { [Player]: any },
	_loading = {} :: { [Player]: boolean },
	-- join handlers still running / loaded handlers done / ready handlers done
	_joining = {} :: { [Player]: boolean },
	_live = {} :: { [Player]: boolean },
	_readied = {} :: { [Player]: boolean },
	_leaving = {} :: { [Player]: boolean },
	-- UserIds whose final save is in flight, and how many releases are running
	_releasingIds = {} :: { [number]: boolean },
	_busy = 0,
	_loaded = {} :: { Handler },
	_ready = {} :: { Handler },
	_releasing = {} :: { Handler },
	_store = nil :: any,
	_mock = false,
	_closing = false,
})

-- A stand-in with the one method this service uses, for Studio sessions where
-- "Enable Studio Access to API Services" is off. Nothing persists.
local function memoryStore(): any
	local rows: { [string]: any } = {}
	return {
		UpdateAsync = function(_self: any, key: string, transform: (any) -> any): any
			local value = transform(rows[key])
			if value ~= nil then
				rows[key] = value
			end
			return value
		end,
	}
end

local function keyFor(player: Player): string
	return "p_" .. tostring(player.UserId)
end

-- By index, re-reading the length: a handler registered while an earlier one
-- is yielding still runs, exactly once.
local function run(handlers: { Handler }, player: Player, profile: any)
	local i = 1
	while i <= #handlers do
		local ok, err = pcall(handlers[i], player, profile)
		if not ok then
			warn(`[DataService] lifecycle handler failed for {player.Name}: {err}`)
		end
		i += 1
	end
end

--- The live profile table for `player`, or nil until it has loaded.
function DataService:Get(player: Player): any?
	return self._profiles[player]
end

--- Every loaded profile, keyed by player. Read-only for callers.
function DataService:All(): { [Player]: any }
	return self._profiles
end

--- True when saves go nowhere (Studio without API access).
function DataService:IsMock(): boolean
	return self._mock
end

--- Run `handler(player, profile)` when a profile loads. A handler registered
--- late also runs for players whose load handlers have already finished, so
--- registration order does not matter and nobody is handled twice.
function DataService:OnLoaded(handler: Handler)
	table.insert(self._loaded, handler)
	for player in self._live do
		local profile = self._profiles[player]
		if profile then
			task.spawn(handler, player, profile)
		end
	end
end

--- Run `handler` after EVERY OnLoaded handler has run for that player: the
--- place to send the first snapshot.
function DataService:OnReady(handler: Handler)
	table.insert(self._ready, handler)
	for player in self._readied do
		local profile = self._profiles[player]
		if profile then
			task.spawn(handler, player, profile)
		end
	end
end

--- Run `handler(player, profile)` just before the profile is saved and let go.
function DataService:OnReleasing(handler: Handler)
	table.insert(self._releasing, handler)
end

function DataService:_load(player: Player): any?
	local key = keyFor(player)
	local failures = 0
	local busySince: number? = nil
	while failures < LOAD_FAILURES do
		local profile: any = nil
		local busy = false
		local tookOver = false
		local waited = if busySince then os.clock() - busySince else 0
		local ok, err = pcall(function()
			self._store:UpdateAsync(key, function(record: any): any
				-- the transform can run more than once: reset every time
				profile, busy, tookOver = nil, false, false
				local row = if type(record) == "table" then record else {}
				if not Session.canAcquire(row.lock, JOB, os.time(), waited) then
					busy = true
					return nil
				end
				tookOver = row.lock ~= nil and row.lock.job ~= JOB
				row.lock = { job = JOB, t = os.time() }
				row.data = Schema.upgrade(row.data, Config)
				profile = row.data
				return row
			end)
		end)
		if ok and profile then
			if tookOver then
				warn(`[DataService] took over a save lock left behind for {player.Name}`)
			end
			return profile
		end
		if not player:IsDescendantOf(Players) or self._closing then
			return nil
		end
		if ok and busy then
			-- another server is still saving this player: wait for it to let go
			busySince = busySince or os.clock()
			task.wait(Session.POLL)
		else
			failures += 1
			warn(`[DataService] load attempt {failures} failed for {player.Name}: {err}`)
			task.wait(Session.backoff(failures))
		end
	end
	return nil
end

-- Returns "ok", "lost" (another server owns the profile) or "failed".
function DataService:_save(player: Player, profile: any, release: boolean): string
	local key = keyFor(player)
	for attempt = 1, SAVE_ATTEMPTS do
		local lost = false
		local ok, err = pcall(function()
			self._store:UpdateAsync(key, function(record: any): any
				lost = false
				local row = if type(record) == "table" then record else {}
				if not Session.owns(row.lock, JOB) then
					lost = true
					return nil
				end
				row.data = profile
				row.lock = if release then nil else { job = JOB, t = os.time() }
				return row
			end)
		end)
		if lost then
			return "lost"
		end
		if ok then
			return "ok"
		end
		warn(`[DataService] save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(Session.backoff(attempt))
	end
	return "failed"
end

-- The final save: write the profile and give the lock back. Counted in _busy
-- so shutdown waits for it whoever started it.
function DataService:_release(player: Player, profile: any)
	local userId = player.UserId
	self._releasingIds[userId] = true
	self._busy += 1
	local result = self:_save(player, profile, true)
	self._busy -= 1
	self._releasingIds[userId] = nil
	if result ~= "ok" then
		warn(`[DataService] final save for {player.Name} ended as "{result}"`)
	end
end

-- Tell every service the profile is going away and forget it.
function DataService:_drop(player: Player, profile: any)
	run(self._releasing, player, profile)
	self._profiles[player] = nil
	self._joining[player] = nil
	self._live[player] = nil
	self._readied[player] = nil
end

function DataService:_join(player: Player)
	if self._profiles[player] or self._loading[player] or self._closing then
		return
	end
	-- one load per player at a time: a second one would run every lifecycle
	-- handler twice (two plots, two snapshots)
	self._loading[player] = true
	-- a rejoin to this same server while the last visit's final save is still
	-- in flight would load the data from before that save
	local patience = os.clock() + Session.STEAL_AFTER
	while self._releasingIds[player.UserId] and os.clock() < patience do
		task.wait(0.2)
	end
	local profile = self:_load(player)
	self._loading[player] = nil
	if not player:IsDescendantOf(Players) or self._closing then
		-- left (or the server is closing) while loading: give the lock back so
		-- the next server is not blocked
		if profile then
			self:_release(player, profile)
		end
		return
	end
	if not profile then
		player:Kick("Could not load your data. Nothing was lost - please rejoin in a minute.")
		return
	end
	self._profiles[player] = profile
	self._joining[player] = true
	-- let every service finish KnitStart before the first handler runs
	task.wait()
	run(self._loaded, player, profile)
	self._live[player] = true
	run(self._ready, player, profile)
	self._readied[player] = true
	self._joining[player] = nil
end

function DataService:_leave(player: Player)
	local profile = self._profiles[player]
	if not profile or self._leaving[player] then
		return
	end
	self._leaving[player] = true
	self._busy += 1
	-- strict order: the join handlers finish before the release handlers start
	-- (a pass-ownership check can still be running for a player who just left)
	local patience = os.clock() + 10
	while self._joining[player] and os.clock() < patience do
		task.wait()
	end
	self:_drop(player, profile)
	self:_release(player, profile)
	self._busy -= 1
	self._leaving[player] = nil
end

--- Save now without releasing (used after a purchase so a grant is on disk
--- before Roblox is told the purchase was handled). Returns true on success.
function DataService:SaveNow(player: Player): boolean
	local profile = self._profiles[player]
	if not profile then
		return false
	end
	local result = self:_save(player, profile, false)
	if result == "lost" then
		-- another server owns the profile now: let every service clean up (the
		-- plot, the per-player tables) and send the player away without saving
		if self._profiles[player] == profile and not self._leaving[player] then
			self:_drop(player, profile)
		end
		player:Kick("Your data was opened on another server. Please rejoin.")
	end
	return result == "ok"
end

function DataService:KnitStart()
	local name = if RunService:IsStudio()
		then Config.Server.ProfileStoreStudio
		else Config.Server.ProfileStore
	local ok, err = pcall(function()
		local store = DataStoreService:GetDataStore(name)
		store:GetAsync("__probe")
		self._store = store
	end)
	if not ok then
		if RunService:IsStudio() then
			self._mock = true
			self._store = memoryStore()
			warn(
				"[DataService] DataStore unavailable in Studio, using MEMORY ONLY. Turn on "
					.. "Game Settings > Security > Enable Studio Access to API Services to test saving. ("
					.. tostring(err)
					.. ")"
			)
		else
			-- a live server with a DataStore hiccup: keep the real store and let
			-- the per-player retries deal with it
			warn(`[DataService] DataStore probe failed: {err}`)
			self._store = DataStoreService:GetDataStore(name)
		end
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_join(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_leave(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_join(player)
		end)
	end

	-- autosave, one player at a time so a full server is not six writes at once
	task.spawn(function()
		while not self._closing do
			task.wait(Config.Server.AutosaveSeconds)
			for player in table.clone(self._profiles) do
				if self._profiles[player] and not self._leaving[player] and not self._closing then
					self:SaveNow(player)
					task.wait(1)
				end
			end
		end
	end)

	game:BindToClose(function()
		self._closing = true
		for player in table.clone(self._profiles) do
			task.spawn(function()
				self:_leave(player)
			end)
		end
		-- wait for every final save, including the ones PlayerRemoving started
		-- a moment ago: returning early here is how a save lock gets left behind
		local deadline = os.clock() + SHUTDOWN_SECONDS
		while (self._busy > 0 or next(self._profiles) ~= nil) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
