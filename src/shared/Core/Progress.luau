--!strict
-- Progress - training, unlocks, costs, offline earnings and rebirth. Pure.
--
-- Everything here is "a number in, a number out" over the config tables, kept
-- in one module because each rule is two or three lines and they are always
-- read together when tuning the economy.
--
-- THE CLOCK (plan 12, section 4). Training is what paces the game: each
-- zone's gear is sized for its target minutes. So gear, foods and plot slots
-- UNLOCK by the furthest zone a player has ever reached (`bestZone`): Yen can
-- never buy a way round the training.
local Progress = {}

-- ---------------------------------------------------------------- training --

--- 1 + tier x the per-tier bonus named `key` (IncomeBonus, TrainBonus, LuckBonus).
function Progress.rebirthMult(cfg: any, tier: number, key: string): number
	local first = cfg.Rebirth.Tiers[1]
	return 1 + math.max(0, tier) * (if first then first[key] or 0 else 0)
end

--- Muscle memory: training is faster while Power is below the player's own
--- record, so the way back after a rebirth takes minutes.
function Progress.catchingUp(power: number, powerRecord: number): boolean
	return power < powerRecord
end

--- Power gained by one rep on gear `tier`.
function Progress.powerPerRep(
	cfg: any,
	tier: number,
	doubleTraining: boolean,
	rebirthTier: number?,
	catchingUp: boolean?
): number
	local gear = cfg.Training.Equipment[math.clamp(tier, 1, #cfg.Training.Equipment)]
	return gear.PowerPerRep
		* (if doubleTraining then 2 else 1)
		* Progress.rebirthMult(cfg, rebirthTier or 0, "TrainBonus")
		* (if catchingUp then cfg.Training.MuscleMemory else 1)
end

--- Power after `gain` more, when part of it may be muscle memory: the bonus
--- stops at the record, the rest of the rep counts at the normal rate.
--- `gain` is the BOOSTED gain (powerPerRep with catchingUp = true).
function Progress.addPower(cfg: any, power: number, powerRecord: number, gain: number): number
	if power >= powerRecord then
		return power + gain
	end
	local boosted = power + gain
	if boosted <= powerRecord then
		return boosted
	end
	-- the part of the rep spent below the record was boosted; the rest is not
	local over = boosted - powerRecord
	return powerRecord + over / cfg.Training.MuscleMemory
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

--- Call after Power changes: raises the record and, when the throw now
--- reaches a new zone (`reach` = Throw.reach of the player), `bestZone`.
--- Returns true when a new zone was reached.
function Progress.touch(profile: any, reach: number): boolean
	if profile.power > profile.powerRecord then
		profile.powerRecord = profile.power
	end
	if reach > profile.bestZone then
		profile.bestZone = reach
		return true
	end
	return false
end

-- ----------------------------------------------------------------- unlocks --

export type Lock = { zone: number?, rebirth: number? }

--- Why a row with `Zone` / `RebirthReq` is still locked, or nil when it is
--- open. `zone` = the zone index to reach first, `rebirth` = the tier needed.
function Progress.lock(row: any, bestZone: number, rebirthTier: number): Lock?
	local needZone = row.Zone or 1
	local needTier = row.RebirthReq or 0
	if rebirthTier < needTier then
		return { rebirth = needTier }
	end
	if bestZone < needZone then
		return { zone = needZone }
	end
	return nil
end

--- The gear after `tier`, or nil at the top tier.
function Progress.nextGear(cfg: any, tier: number): any?
	return cfg.Training.Equipment[tier + 1]
end

--- Cost of the gear after `tier`, or nil at the top tier.
function Progress.nextGearCost(cfg: any, tier: number): number?
	local gear = cfg.Training.Equipment[tier + 1]
	return if gear then gear.Cost else nil
end

--- How many plot slots the player has BOUGHT (bonus slots from a pass are
--- not purchases and do not move the price).
function Progress.slotsBought(cfg: any, slots: number, bonusSlots: number?): number
	return math.max(0, slots - cfg.Plot.StartSlots - (bonusSlots or 0))
end

--- Cost of the next plot slot, or nil when every slot is bought.
function Progress.nextSlotCost(cfg: any, slots: number, bonusSlots: number?): number?
	return cfg.Plot.SlotCosts[Progress.slotsBought(cfg, slots, bonusSlots) + 1]
end

--- The zone that unlocks the next plot slot, or nil when every slot is bought.
function Progress.nextSlotZone(cfg: any, slots: number, bonusSlots: number?): number?
	return cfg.Plot.SlotZones[Progress.slotsBought(cfg, slots, bonusSlots) + 1]
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

--- A rebirth needs the throw to reach the sealed gate (Power x the food's
--- PowerMult >= PowerReq) and the Yen fee.
function Progress.canRebirth(
	cfg: any,
	tier: number,
	power: number,
	yen: number,
	foodPowerMult: number?
): boolean
	local nextTier = cfg.Rebirth.Tiers[tier + 1]
	if not nextTier then
		return false
	end
	return power * (foodPowerMult or 1) >= nextTier.PowerReq and yen >= nextTier.YenCost
end

--- Apply a rebirth to a profile table IN PLACE. Resets Power and Yen ONLY
--- (plan 12, section 5): heroes, slots, gear, foods and the Index are kept,
--- and `powerRecord` stays so muscle memory brings the Power back fast.
function Progress.applyRebirth(cfg: any, profile: any)
	local reward = cfg.Rebirth.Tiers[profile.rebirth + 1]
	profile.rebirth += 1
	profile.yen = 0
	-- unclaimed offline pay is Yen too: it must not be carried across the reset
	profile.away = { yen = 0, seconds = 0 }
	profile.power = cfg.Training.StartPower
	if reward and reward.LuckyThrows then
		profile.luckyThrows += reward.LuckyThrows
	end
end

return Progress
