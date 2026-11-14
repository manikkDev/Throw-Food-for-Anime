--!strict
-- LeaderboardService - three global boards: most Yen earned, most heroes
-- caught, rarest catch.
--
-- OrderedDataStores only hold whole numbers up to 2^63, and Yen goes far past
-- that, so Yen and "1 in N" are stored as log10 x 1e6. Order is preserved and
-- the real number is recovered for display.
--
-- A board that cannot be read (Studio without API access, a DataStore
-- hiccup) keeps its last text. It never errors into gameplay.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Guard = require(script.Parent.Parent.Logic.Guard)

local TOP = 10
-- Studio sessions write to their own boards. Measured 2026-11-14: a test grant
-- of a trillion Yen in Studio went straight onto the live-named board.
local SUFFIX = if RunService:IsStudio() then "_Dev" else ""

local function encode(n: number): number
	return math.floor(math.log10(math.max(n, 0) + 1) * 1e6)
end

local function decode(v: number): number
	return 10 ^ (v / 1e6) - 1
end

type Board = {
	key: string,
	anchor: string,
	title: string,
	store: string,
	value: (any) -> number,
	show: (number) -> string,
}

local BOARDS: { Board } = {
	{
		key = "yen",
		anchor = "BoardYen",
		title = "TOP YEN EARNED",
		store = "LB_Yen_v1",
		value = function(profile: any): number
			return encode(profile.yenLifetime)
		end,
		show = function(v: number): string
			return Format.short(decode(v)) .. " yen"
		end,
	},
	{
		key = "caught",
		anchor = "BoardCaught",
		title = "MOST HEROES CAUGHT",
		store = "LB_Caught_v1",
		value = function(profile: any): number
			return profile.stats.caught
		end,
		show = function(v: number): string
			return Format.comma(v)
		end,
	},
	{
		key = "rarest",
		anchor = "BoardRarest",
		title = "RAREST CATCH",
		store = "LB_Rarest_v1",
		value = function(profile: any): number
			return encode(profile.stats.rarestOneIn)
		end,
		show = function(v: number): string
			return Format.oneIn(decode(v))
		end,
	},
}

local LeaderboardService = Knit.CreateService({
	Name = "LeaderboardService",
	_names = {} :: { [number]: string },
	_cache = {} :: { [string]: any },
})

function LeaderboardService:KnitInit()
	self._remote = Net.server("Leaderboards")
	self._clientReady = Net.server("ClientReady")
end

function LeaderboardService:_name(userId: number): string
	local known = self._names[userId]
	if known then
		return known
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok then name else "Player"
	self._names[userId] = result
	return result
end

function LeaderboardService:_write()
	for player, profile in self._data:All() do
		for _, board in BOARDS do
			local value = board.value(profile)
			if value > 0 then
				pcall(function()
					local store = DataStoreService:GetOrderedDataStore(board.store .. SUFFIX)
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

function LeaderboardService:_read()
	for _, board in BOARDS do
		local ok, rows = pcall(function()
			local store = DataStoreService:GetOrderedDataStore(board.store .. SUFFIX)
			local page = store:GetSortedAsync(false, TOP):GetCurrentPage()
			local list = {}
			for rank, entry in page do
				local userId = tonumber(entry.key) or 0
				table.insert(list, {
					rank = rank,
					userId = userId,
					name = self:_name(userId),
					text = board.show(entry.value),
				})
			end
			return list
		end)
		if ok then
			self._cache[board.key] = { title = board.title, rows = rows }
			self:_paint(board, rows)
		end
	end
	self._remote:FireAllClients(self._cache)
end

function LeaderboardService:_paint(board: Board, rows: { any })
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local anchor = hub and hub:FindFirstChild(board.anchor)
	local gui = anchor and anchor:FindFirstChild("Board")
	local label = gui and gui:FindFirstChild("Text")
	if not label or not label:IsA("TextLabel") then
		return
	end
	local lines = { board.title, "" }
	for _, row in rows do
		table.insert(lines, `{row.rank}. {row.name}   {row.text}`)
	end
	if #rows == 0 then
		table.insert(lines, "Be the first!")
	end
	label.Text = table.concat(lines, "\n")
end

function LeaderboardService:KnitStart()
	self._data = Knit.GetService("DataService")
	for _, board in BOARDS do
		self:_paint(board, {})
	end
	self._clientReady.OnServerEvent:Connect(function(player: Player)
		if not Guard.allow(player, "Boards", 0.2, 2) then
			return
		end
		if next(self._cache) ~= nil then
			self._remote:FireClient(player, self._cache)
		end
	end)

	task.spawn(function()
		task.wait(5)
		-- asked here, not in KnitStart: DataService decides whether this is a
		-- memory-only session during its own start
		if self._data:IsMock() then
			return -- no DataStore in this session
		end
		while true do
			self:_write()
			self:_read()
			task.wait(Config.Server.LeaderboardSeconds)
		end
	end)
end

return LeaderboardService
