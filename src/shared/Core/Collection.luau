--!strict
-- Collection - the Hero Index, daily and playtime rewards, codes, receipts.
-- Pure: every clock is passed in as a number, so day rollover is testable.

local Collection = {}

-- ------------------------------------------------------------------- index --
-- index = { [heroId] = { muts = { [name] = true }, sizes = { [name] = true } } }

--- Record a catch. Returns true the FIRST time this hero id is seen.
function Collection.discover(index: any, heroId: string, mut: string?, size: string?): boolean
	local entry = index[heroId]
	local isNew = entry == nil
	if not entry then
		entry = { muts = {}, sizes = {} }
		index[heroId] = entry
	end
	if mut then
		entry.muts[mut] = true
	end
	if size then
		entry.sizes[size] = true
	end
	return isNew
end

--- Discovered and total heroes for a zone. `zoneCharacters` comes from Lookup.
function Collection.zoneProgress(index: any, zoneCharacters: { any }): (number, number)
	local have = 0
	for _, character in zoneCharacters do
		if index[character.Id] then
			have += 1
		end
	end
	return have, #zoneCharacters
end

--- Zones whose every hero has been discovered. Variants do not count.
function Collection.completedZones(cfg: any, maps: any, index: any): number
	local done = 0
	for _, zone in cfg.Zones do
		local have, total = Collection.zoneProgress(index, maps.zoneCharacters[zone.Id])
		if total > 0 and have == total then
			done += 1
		end
	end
	return done
end

--- Discovered and total lane heroes overall.
function Collection.total(cfg: any, index: any): (number, number)
	local have = 0
	for _, character in cfg.Characters do
		if index[character.Id] then
			have += 1
		end
	end
	return have, #cfg.Characters
end

-- ------------------------------------------------------------------- daily --
-- daily = { day = <UTC day number of the last claim>, streak = n }

--- UTC day number for a unix timestamp.
function Collection.dayOf(unix: number): number
	return unix // 86400
end

export type DailyState = { canClaim: boolean, streak: number, dayIndex: number }

--- What claiming now would do: the streak it would become and which of the
--- seven reward tiles that is. A missed day restarts the streak at 1.
function Collection.dailyState(daily: any, today: number): DailyState
	if daily.day == today then
		local index = ((math.max(daily.streak, 1) - 1) % 7) + 1
		return { canClaim = false, streak = daily.streak, dayIndex = index }
	end
	local streak = if daily.day == today - 1 then daily.streak + 1 else 1
	return { canClaim = true, streak = streak, dayIndex = ((streak - 1) % 7) + 1 }
end

export type Reward = { yenMinutes: number, luckyThrows: number }

--- The reward on tile `dayIndex` (1..7).
function Collection.dailyReward(cfg: any, dayIndex: number): Reward
	local r = cfg.Rewards
	return {
		yenMinutes = r.DailyYenMinutes[dayIndex] or 0,
		luckyThrows = r.DailyLuckyThrowsOnDay[tostring(dayIndex)] or 0,
	}
end

-- ---------------------------------------------------------- playtime gifts --
-- gifts = { day = <UTC day>, claimed = { [index as string] = true } }

--- Gift `i` is claimable when the session has run long enough and it has not
--- been claimed today. Gifts reset when the UTC day changes.
function Collection.giftClaimable(
	cfg: any,
	gifts: any,
	today: number,
	sessionSeconds: number,
	i: number
): boolean
	local minutes = cfg.Rewards.PlaytimeMinutes[i]
	if not minutes then
		return false
	end
	if gifts.day == today and gifts.claimed[tostring(i)] then
		return false
	end
	return sessionSeconds >= minutes * 60
end

--- Mark gift `i` claimed, clearing yesterday's claims first.
function Collection.claimGift(gifts: any, today: number, i: number)
	if gifts.day ~= today then
		gifts.day = today
		gifts.claimed = {}
	end
	gifts.claimed[tostring(i)] = true
end

-- ------------------------------------------------------------------- codes --

--- A code is redeemable once, and only if it exists. Codes are case-blind.
function Collection.codeKey(text: string): string
	return (text:upper():gsub("%s+", ""))
end

function Collection.canRedeem(codes: { [string]: any }, redeemed: any, text: string): boolean
	local key = Collection.codeKey(text)
	return codes[key] ~= nil and not redeemed[key]
end

-- ---------------------------------------------------------------- receipts --
-- receipts = array of purchase ids already granted, newest last, bounded.

function Collection.receiptSeen(receipts: { string }, id: string): boolean
	return table.find(receipts, id) ~= nil
end

--- Remember a granted purchase, keeping only the newest `max`.
function Collection.recordReceipt(receipts: { string }, id: string, max: number)
	table.insert(receipts, id)
	while #receipts > max do
		table.remove(receipts, 1)
	end
end

return Collection
