--!strict
-- Luck - one multiplier from every source, and the list that explains it.
--
--   luck = Food x Depth x Perfect x (1 + bonuses) x VIP x Lucky Aura
--          x Server Luck x Lucky Throw,   capped at Luck.Max
--
-- THE STACKING RULE (plan 12, section 3.2). The free, permanent bonuses
-- (rebirth, index, friends, daily streak, dry streak) are ADDED together in
-- one group, so ten small bonuses cannot multiply into a runaway number.
-- What a player throws with (food, depth, a perfect) and what is paid for
-- (the two passes, server luck, a lucky throw) each multiply, and each says
-- its number on the store page.
--
-- The reference game is criticised for opaque luck, so the breakdown is a
-- first-class output: the same table that computes the number is what the HUD
-- shows when the player taps the luck chip.
local Luck = {}

export type Sources = {
	foodLuck: number,
	depth: number, -- 0..1 into the zone
	perfect: boolean,
	serverMult: number, -- 1, 2, 4, 8
	friends: number, -- friends of this player in the server
	vip: boolean,
	luckyAura: boolean,
	zonesCompleted: number,
	rebirthTier: number,
	streakBonus: number, -- 0..DailyStreakBonusMax
	luckyThrow: boolean,
	dry: number?, -- throws in a row without the reset rarity or better
}

-- `add` is set on the lines of the added group (show "+30%"); the others
-- multiply (show "x1.5"). `mult` is always what the line alone is worth.
export type Line = { label: string, mult: number, add: number? }

local function auraMult(cfg: any): number
	for _, pass in cfg.Monetization.Passes do
		if pass.Key == "LuckyAura" then
			return pass.Luck
		end
	end
	return 1
end

--- The dry-streak bonus (0..DryStreakMax) after `dry` throws without luck.
function Luck.dryBonus(cfg: any, dry: number): number
	local T = cfg.Throw
	return math.clamp(math.max(0, dry) * T.DryStreakPerThrow, 0, T.DryStreakMax)
end

--- Every source as a line, in display order. Lines worth nothing are left
--- out, so the list only shows what is actually helping.
function Luck.breakdown(cfg: any, s: Sources): { Line }
	local L, T, R = cfg.Luck, cfg.Throw, cfg.Rebirth
	local lines: { Line } = {}
	local function times(label: string, mult: number)
		if math.abs(mult - 1) > 1e-9 then
			table.insert(lines, { label = label, mult = mult })
		end
	end
	local function plus(label: string, add: number)
		if add > 1e-9 then
			table.insert(lines, { label = label, mult = 1 + add, add = add })
		end
	end
	times("Food", s.foodLuck)
	times("Depth", 1 + math.clamp(s.depth, 0, 1) * T.DepthLuckBonus)
	times("Perfect throw", if s.perfect then 1 + T.PerfectLuckBonus else 1)
	local bonusPerTier = if R.Tiers[1] then R.Tiers[1].LuckBonus else 0
	plus("Rebirth", math.max(0, s.rebirthTier) * bonusPerTier)
	plus("Index", math.max(0, s.zonesCompleted) * L.IndexZoneBonus)
	plus("Friends", math.min(L.FriendBonusMax, math.max(0, s.friends) * L.FriendBonusEach))
	plus("Daily streak", math.clamp(s.streakBonus, 0, L.DailyStreakBonusMax))
	plus("Dry streak", Luck.dryBonus(cfg, s.dry or 0))
	times("VIP", if s.vip then 1 + L.VipBonus else 1)
	times("Lucky Aura", if s.luckyAura then auraMult(cfg) else 1)
	times("Server luck", math.max(1, s.serverMult))
	times("Lucky Throw", if s.luckyThrow then T.LuckyThrowLuck else 1)
	return lines
end

--- Every source combined. Never below 1, never above Luck.Max.
function Luck.total(cfg: any, s: Sources): number
	local total = 1
	local added = 0
	for _, line in Luck.breakdown(cfg, s) do
		if line.add then
			added += line.add
		else
			total *= line.mult
		end
	end
	return math.clamp(total * (1 + added), 1, cfg.Luck.Max)
end

--- Streak day 1..7 -> bonus fraction, linear up to DailyStreakBonusMax on day 7.
function Luck.streakBonus(cfg: any, streak: number): number
	local days = math.clamp(streak, 0, 7)
	return cfg.Luck.DailyStreakBonusMax * days / 7
end

return Luck
