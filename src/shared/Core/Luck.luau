--!strict
-- Luck - one multiplier from every source, and the list that explains it.
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
}

export type Line = { label: string, mult: number }

--- Every source as a {label, mult} line, in display order. Lines at x1 are
--- kept out so the list only shows what is actually helping.
function Luck.breakdown(cfg: any, s: Sources): { Line }
	local L, T, R = cfg.Luck, cfg.Throw, cfg.Rebirth
	local lines: { Line } = {}
	local function add(label: string, mult: number)
		if math.abs(mult - 1) > 1e-9 then
			table.insert(lines, { label = label, mult = mult })
		end
	end
	add("Food", s.foodLuck)
	add("Depth", 1 + math.clamp(s.depth, 0, 1) * T.DepthLuckBonus)
	add("Perfect throw", if s.perfect then 1 + T.PerfectLuckBonus else 1)
	add("Server luck", math.max(1, s.serverMult))
	add("Friends", 1 + math.min(L.FriendBonusMax, math.max(0, s.friends) * L.FriendBonusEach))
	add("VIP", if s.vip then 1 + L.VipBonus else 1)
	local auraMult = 1
	for _, pass in cfg.Monetization.Passes do
		if pass.Key == "LuckyAura" then
			auraMult = pass.Luck
		end
	end
	add("Lucky Aura", if s.luckyAura then auraMult else 1)
	add("Index", 1 + math.max(0, s.zonesCompleted) * L.IndexZoneBonus)
	local bonusPerTier = if R.Tiers[1] then R.Tiers[1].LuckBonus else 0
	add("Rebirth", 1 + math.max(0, s.rebirthTier) * bonusPerTier)
	add("Daily streak", 1 + math.clamp(s.streakBonus, 0, L.DailyStreakBonusMax))
	add("Lucky Throw", if s.luckyThrow then T.LuckyThrowLuck else 1)
	return lines
end

--- The product of every source. Never below 1.
function Luck.total(cfg: any, s: Sources): number
	local total = 1
	for _, line in Luck.breakdown(cfg, s) do
		total *= line.mult
	end
	return math.max(1, total)
end

--- Streak day 1..7 -> bonus fraction, linear up to DailyStreakBonusMax on day 7.
function Luck.streakBonus(cfg: any, streak: number): number
	local days = math.clamp(streak, 0, 7)
	return cfg.Luck.DailyStreakBonusMax * days / 7
end

return Luck
