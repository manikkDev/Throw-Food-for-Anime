--!strict
-- Progress - training, costs, offline earnings and rebirth. Pure.
--
-- Everything here is "a number in, a number out" over the config tables, kept
-- in one module because each rule is two or three lines and they are always
-- read together when tuning the economy.

local Progress = {}

-- ---------------------------------------------------------------- training --

--- Power gained by one rep on gear `tier`.
function Progress.powerPerRep(cfg: any, tier: number, doubleTraining: boolean): number
	local gear = cfg.Training.Equipment[math.clamp(tier, 1, #cfg.Training.Equipment)]
	return gear.PowerPerRep * (if doubleTraining then 2 else 1)
end

--- Whole reps completed in `seconds` of training.
function Progress.repsIn(cfg: any, seconds: number): number
	return math.max(0, math.floor(seconds / cfg.Training.RepSeconds))
end

export type Rank = { index: number, name: string, progress: number, nextPower: number? }

--- The rank for `power`: thresholds are inclusive (exactly 200 IS Trainee).
function Progress.rank(cfg: any, power: number): Rank
	local ranks = cfg.Training.Ranks
	local index = 1
	for i, rank in ranks do
		if power >= rank.Power then
			index = i
		end
	end
	local nextRank = ranks[index + 1]
	if not nextRank then
		return { index = index, name = ranks[index].Name, progress = 1, nextPower = nil }
	end
	local from = ranks[index].Power
	return {
		index = index,
		name = ranks[index].Name,
		progress = math.clamp((power - from) / (nextRank.Power - from), 0, 1),
		nextPower = nextRank.Power,
	}
end

-- ------------------------------------------------------------------- costs --

--- Cost of the gear after `tier`, or nil at the top tier.
function Progress.nextGearCost(cfg: any, tier: number): number?
	local gear = cfg.Training.Equipment[tier + 1]
	return if gear then gear.Cost else nil
end

--- Cost of the next plot slot when the player has `slots`, or nil at MaxSlots.
--- Matches tools/balance_sim.py: base x growth ^ (slots - StartSlots).
function Progress.nextSlotCost(cfg: any, slots: number): number?
	local plot = cfg.Plot
	if slots >= plot.MaxSlots then
		return nil
	end
	return math.floor(plot.SlotBaseCost * plot.SlotCostGrowth ^ (slots - plot.StartSlots))
end

-- ----------------------------------------------------------------- offline --

--- Yen earned while away, and the seconds that counted. Nothing below
--- MinSecondsAway; capped at CapHours.
function Progress.offline(cfg: any, secondsAway: number, incomePerSecond: number): (number, number)
	local o = cfg.Offline
	if secondsAway < o.MinSecondsAway or incomePerSecond <= 0 then
		return 0, 0
	end
	local counted = math.min(secondsAway, o.CapHours * 3600)
	return math.floor(counted * incomePerSecond * o.Rate), counted
end

-- ----------------------------------------------------------------- rebirth --

--- The tier the player would reach next, or nil at the cap.
function Progress.nextRebirth(cfg: any, tier: number): any?
	return cfg.Rebirth.Tiers[tier + 1]
end

function Progress.canRebirth(cfg: any, tier: number, power: number, yen: number): boolean
	local nextTier = cfg.Rebirth.Tiers[tier + 1]
	if not nextTier then
		return false
	end
	return power >= nextTier.PowerReq and yen >= nextTier.YenCost
end

--- Apply a rebirth to a profile table IN PLACE. Resets what Rebirth.Resets
--- names, keeps the rest. Premium heroes survive and are re-seated from slot 1;
--- lane heroes are gone. `maps` is Lookup.of(cfg).
function Progress.applyRebirth(cfg: any, maps: any, profile: any)
	profile.rebirth += 1
	profile.yen = 0
	-- unclaimed offline pay is Yen too: it must not be carried across the reset
	profile.away = { yen = 0, seconds = 0 }
	profile.power = cfg.Training.StartPower
	local starter = cfg.Foods[1].Id
	profile.foods = { [starter] = true }
	profile.food = starter
	profile.gear = 1
	profile.slots = cfg.Plot.StartSlots + (profile.bonusSlots or 0)
	local kept = {}
	local uids = {}
	for uid, hero in profile.heroes do
		if maps.premium[hero.id] then
			table.insert(uids, uid)
		end
	end
	table.sort(uids)
	local slot = 0
	for _, uid in uids do
		local hero = profile.heroes[uid]
		slot += 1
		hero.slot = if slot <= profile.slots then slot else 0
		kept[uid] = hero
	end
	profile.heroes = kept
end

return Progress
