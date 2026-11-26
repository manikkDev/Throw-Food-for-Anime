--!strict
-- Foods - what a food is worth where. Pure. (Plan 13, section 4.)
--
-- A food gives LUCK and nothing else. Every world sells three dishes of its
-- own (Snack, Meal, Signature). A food has its full Luck in its own world and
-- in every earlier one; thrown into a LATER world it is stale: heroes want the
-- food of their own world.
local Foods = {}

--- Luck of `food` when it lands in zone `zoneIndex` (1-based).
function Foods.luckAt(cfg: any, food: any, zoneIndex: number): number
	if (food.Zone or 1) >= zoneIndex then
		return food.Luck
	end
	return food.Luck * cfg.Luck.StaleFood
end

--- True when `food` is past its own world in zone `zoneIndex`.
function Foods.isStale(food: any, zoneIndex: number): boolean
	return (food.Zone or 1) < zoneIndex
end

--- The owned food with the most Luck in zone `zoneIndex`. `owned` is the
--- profile's set { [foodId] = true }. A tie keeps the earlier (cheaper) food.
--- Never nil for a real profile: the starter food is always owned.
function Foods.best(cfg: any, owned: { [string]: boolean }, zoneIndex: number): any?
	local best: any? = nil
	local bestLuck = -1
	for _, food in cfg.Foods do
		if owned[food.Id] then
			local luck = Foods.luckAt(cfg, food, zoneIndex)
			if luck > bestLuck then
				best, bestLuck = food, luck
			end
		end
	end
	return best
end

--- The food a throw into `zoneIndex` uses: the best one when auto-pick is on,
--- else the equipped one (falling back to the best if it is not owned).
--- `byId` is Lookup.of(cfg).food.
function Foods.forThrow(cfg: any, byId: { [string]: any }, profile: any, zoneIndex: number): any?
	local equipped = byId[profile.food]
	if profile.autoFood == false and equipped and profile.foods[profile.food] then
		return equipped
	end
	return Foods.best(cfg, profile.foods, zoneIndex) or equipped
end

--- The foods of zone `zoneIndex`, in shop order (Snack, Meal, Signature).
function Foods.ofZone(cfg: any, zoneIndex: number): { any }
	local out = {}
	for _, food in cfg.Foods do
		if food.Zone == zoneIndex then
			table.insert(out, food)
		end
	end
	return out
end

--- Cookbook: true when every food of zone `zoneIndex` is owned.
function Foods.setComplete(cfg: any, owned: { [string]: boolean }, zoneIndex: number): boolean
	local found = false
	for _, food in cfg.Foods do
		if food.Zone == zoneIndex then
			found = true
			if not owned[food.Id] then
				return false
			end
		end
	end
	return found
end

--- How many cookbook sets are complete.
function Foods.setsComplete(cfg: any, owned: { [string]: boolean }): number
	local n = 0
	for i = 1, #cfg.Zones do
		if Foods.setComplete(cfg, owned, i) then
			n += 1
		end
	end
	return n
end

return Foods
