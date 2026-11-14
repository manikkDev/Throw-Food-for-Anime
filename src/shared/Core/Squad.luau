--!strict
-- Squad - where heroes stand. Pure decisions over the `heroes` table of a
-- profile: { [uid]: { id, mut, size, stars, slot } }, slot 1..slots on the
-- plot, 0 on the bench.
--
-- The rule that shapes this module: A CATCH NEVER BLOCKS THE NEXT THROW. Every
-- catch resolves by itself (place, swap, bench or auto-sell) with no prompt.

local Squad = {}

export type Hero = { id: string, mut: string?, size: string?, stars: number, slot: number }
export type Heroes = { [string]: Hero }

export type Placement = {
	action: "place" | "swap" | "bench" | "sold",
	slot: number, -- slot the new hero takes (0 = bench or sold)
	benched: string?, -- uid moved from the plot to the bench by a swap
	sold: string?, -- uid auto-sold to make room ("new" if the catch itself)
}

--- Heroes on the plot and on the bench.
function Squad.counts(heroes: Heroes): (number, number)
	local onPlot, onBench = 0, 0
	for _, hero in heroes do
		if hero.slot > 0 then
			onPlot += 1
		else
			onBench += 1
		end
	end
	return onPlot, onBench
end

--- Lowest free slot index, or nil when the plot is full.
function Squad.freeSlot(heroes: Heroes, slots: number): number?
	local taken = {}
	for _, hero in heroes do
		if hero.slot > 0 then
			taken[hero.slot] = true
		end
	end
	for slot = 1, slots do
		if not taken[slot] then
			return slot
		end
	end
	return nil
end

--- uid and income of the weakest hero matching `onPlot`. Ties break on uid so
--- the answer is stable. `incomeOf(hero)` is supplied by the caller.
function Squad.weakest(
	heroes: Heroes,
	onPlot: boolean,
	incomeOf: (Hero) -> number
): (string?, number)
	local worstUid: string? = nil
	local worst = math.huge
	for uid, hero in heroes do
		if (hero.slot > 0) == onPlot then
			local value = incomeOf(hero)
			if value < worst or (value == worst and worstUid ~= nil and uid < worstUid) then
				worst = value
				worstUid = uid
			end
		end
	end
	return worstUid, if worstUid then worst else 0
end

--- Decide what happens to a new catch worth `newIncome`. Does not mutate.
---   free slot                      -> place
---   plot full, beats the weakest   -> swap (the weakest goes to the bench)
---   otherwise                      -> bench
---   and whenever the bench would overflow, the lowest-income bench hero (or
---   the catch itself, if it is the lowest) is sold.
function Squad.placement(
	heroes: Heroes,
	slots: number,
	benchSlots: number,
	newIncome: number,
	incomeOf: (Hero) -> number
): Placement
	local free = Squad.freeSlot(heroes, slots)
	if free then
		return { action = "place", slot = free }
	end
	local _, onBench = Squad.counts(heroes)
	local weakestUid, weakestIncome = Squad.weakest(heroes, true, incomeOf)
	local benchWorstUid, benchWorst = Squad.weakest(heroes, false, incomeOf)
	if weakestUid and newIncome > weakestIncome then
		local placement: Placement =
			{ action = "swap", slot = heroes[weakestUid].slot, benched = weakestUid }
		if onBench + 1 > benchSlots then
			-- the bench is full: sell whichever is worth least, the displaced
			-- hero or the worst hero already benched
			if benchWorstUid and benchWorst < weakestIncome then
				placement.sold = benchWorstUid
			else
				placement.sold = weakestUid
				placement.benched = nil
			end
		end
		return placement
	end
	if onBench + 1 > benchSlots then
		if benchWorstUid and benchWorst < newIncome then
			return { action = "bench", slot = 0, sold = benchWorstUid }
		end
		return { action = "sold", slot = 0, sold = "new" }
	end
	return { action = "bench", slot = 0 }
end

--- Seat the highest-income heroes on the plot. Returns uid -> slot for EVERY
--- hero (0 = bench). Ties break on uid.
function Squad.equipBest(
	heroes: Heroes,
	slots: number,
	incomeOf: (Hero) -> number
): { [string]: number }
	local order = {}
	for uid, hero in heroes do
		table.insert(order, { uid = uid, income = incomeOf(hero) })
	end
	table.sort(order, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	local seats = {}
	for i, row in order do
		seats[row.uid] = if i <= slots then i else 0
	end
	return seats
end

--- The heroes that would be consumed by fusing `uid`: the same id, mutation,
--- size and stars. Returns `count - 1` other uids, or nil when there are not
--- enough or the hero is already at MaxStars.
function Squad.fusePartners(
	heroes: Heroes,
	uid: string,
	count: number,
	maxStars: number
): { string }?
	local target = heroes[uid]
	if not target or target.stars >= maxStars then
		return nil
	end
	local partners = {}
	local uids = {}
	for other in heroes do
		table.insert(uids, other)
	end
	table.sort(uids)
	for _, other in uids do
		local hero = heroes[other]
		if
			other ~= uid
			and hero.id == target.id
			and hero.mut == target.mut
			and hero.size == target.size
			and hero.stars == target.stars
		then
			table.insert(partners, other)
			if #partners == count - 1 then
				return partners
			end
		end
	end
	return nil
end

return Squad
