--!strict
-- Schema - the saved profile: its default shape and how old saves reach it.
-- Pure. DataService is the only code that loads or stores one.
--
-- Rules for anything added here:
--   * string keys only (a DataStore turns mixed tables into garbage)
--   * no Instances, no functions, no NaN or infinity
--   * a new field gets a default below and old saves pick it up in `reconcile`
--   * a changed MEANING gets a version bump and a migration step

local Schema = {}

Schema.VERSION = 2

export type Profile = {
	v: number,
	yen: number,
	yenLifetime: number,
	power: number,
	powerRecord: number,
	bestZone: number,
	dry: number,
	aim: number,
	rebirth: number,
	foods: { [string]: boolean },
	food: string,
	gear: number,
	slots: number,
	bonusSlots: number,
	heroes: { [string]: any },
	nextUid: number,
	index: { [string]: any },
	zonesClaimed: { [string]: boolean },
	luckyThrows: number,
	grantedPasses: { [string]: boolean },
	receipts: { string },
	daily: { day: number, streak: number },
	gifts: { day: number, claimed: { [string]: boolean } },
	codes: { [string]: boolean },
	tutorial: number,
	settings: { [string]: any },
	stats: { [string]: any },
	lastSeen: number,
	away: { yen: number, seconds: number },
	starterPack: boolean,
	groupReward: boolean,
	doubleYenUntil: number,
}

--- A brand-new profile.
function Schema.default(cfg: any): Profile
	local starter = cfg.Foods[1].Id
	return {
		v = Schema.VERSION,
		yen = 0,
		yenLifetime = 0,
		power = cfg.Training.StartPower,
		-- the highest Power ever held: training is faster below it (muscle memory)
		powerRecord = cfg.Training.StartPower,
		-- the furthest zone ever reached: gear, foods and plot slots unlock by it
		bestZone = 1,
		-- throws in a row without an Epic or better (the dry-streak luck)
		dry = 0,
		-- the zone the player aims at; 0 = as far as their Power reaches
		aim = 0,
		rebirth = 0,
		foods = { [starter] = true },
		food = starter,
		gear = 1,
		slots = cfg.Plot.StartSlots,
		bonusSlots = 0,
		heroes = {},
		nextUid = 1,
		index = {},
		zonesClaimed = {},
		luckyThrows = 0,
		grantedPasses = {},
		receipts = {},
		daily = { day = 0, streak = 0 },
		gifts = { day = 0, claimed = {} },
		codes = {},
		tutorial = 0,
		settings = {
			music = 0.6,
			sfx = 0.8,
			fastReveal = false,
			lowDetail = false,
			hideOthers = false,
			autoSellCommon = false,
			autoSellUncommon = false,
			autoSellRare = false,
		},
		stats = { caught = 0, rarestOneIn = 0, rarestId = "" },
		lastSeen = 0,
		-- offline earnings banked but not claimed yet (saved, so leaving
		-- without tapping Claim does not throw them away)
		away = { yen = 0, seconds = 0 },
		starterPack = false,
		groupReward = false,
		doubleYenUntil = 0,
	}
end

-- Keys whose VALUE is a player-built map: never filled from the default,
-- because their keys are data (hero uids, hero ids, codes), not fields.
local OPAQUE = {
	foods = true,
	heroes = true,
	index = true,
	zonesClaimed = true,
	grantedPasses = true,
	receipts = true,
	codes = true,
}

local function fill(target: any, template: any, depth: number)
	for key, value in template do
		local current = target[key]
		if type(value) == "table" and type(current) == "table" then
			local opaque = (depth == 0 and OPAQUE[key]) or key == "claimed"
			if not opaque then
				fill(current, value, depth + 1)
			end
		elseif current == nil or type(current) ~= type(value) then
			-- missing, or a field whose type is wrong in a bad save: take the default
			target[key] = if type(value) == "table" then table.clone(value) else value
		end
	end
end

-- migrations[v] upgrades a save FROM version v to v + 1.
local migrations: { [number]: (any) -> () } = {}

-- v1 -> v2 (economy v2, plan 12): a rebirth no longer wipes anything but Power
-- and Yen, so the new fields only need sane starts. `powerRecord` and
-- `bestZone` are raised to what the save already shows in `upgrade` below
-- (they need the config).
migrations[1] = function(data: any)
	data.dry = 0
	data.aim = 0
end

--- Bring any stored table up to the current shape, in place, and return it.
--- Unknown keys are kept (a newer server may have written them).
function Schema.upgrade(data: any, cfg: any): Profile
	if type(data) ~= "table" then
		return Schema.default(cfg)
	end
	local version = if type(data.v) == "number" then data.v else 0
	while version < Schema.VERSION do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	-- never stamp a NEWER save down (after a code rollback): that would run its
	-- migrations a second time when the newer code comes back
	data.v = math.max(version, Schema.VERSION)
	fill(data, Schema.default(cfg), 0)
	-- values the rest of the game may assume
	if data.slots < cfg.Plot.StartSlots then
		data.slots = cfg.Plot.StartSlots
	end
	if data.gear < 1 then
		data.gear = 1
	end
	if data.gear > #cfg.Training.Equipment then
		data.gear = #cfg.Training.Equipment
	end
	if data.powerRecord < data.power then
		data.powerRecord = data.power
	end
	-- the furthest zone the save can show it reached: by its record Power and
	-- the zones its rebirth tier has opened
	for i, zone in cfg.Zones do
		if
			i > data.bestZone
			and data.powerRecord >= zone.PowerReq
			and (zone.RebirthReq or 0) <= data.rebirth
		then
			data.bestZone = i
		end
	end
	data.bestZone = math.clamp(data.bestZone, 1, #cfg.Zones)
	if data.aim < 0 or data.aim > #cfg.Zones then
		data.aim = 0
	end
	if not data.foods[data.food] then
		data.food = cfg.Foods[1].Id
		data.foods[data.food] = true
	end
	for _, hero in data.heroes do
		if type(hero.stars) ~= "number" then
			hero.stars = 0
		end
		if type(hero.slot) ~= "number" or hero.slot > data.slots then
			hero.slot = 0
		end
	end
	return data
end

--- A new hero record and its uid. Advances `nextUid`.
function Schema.newHero(profile: any, id: string, mut: string?, size: string?): (string, any)
	local uid = "h" .. tostring(profile.nextUid)
	profile.nextUid += 1
	local hero = { id = id, mut = mut, size = size, stars = 0, slot = 0 }
	profile.heroes[uid] = hero
	return uid, hero
end

return Schema
